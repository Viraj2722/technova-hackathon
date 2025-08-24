from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import uuid
import os
from supabase import create_client, Client
from dotenv import load_dotenv
from ultralytics import YOLO
import subprocess
import glob
import shutil
import re
import tempfile
import json

# Load environment
load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
# print(SUPABASE_KEY," ", SUPABASE_URL)
if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError("Supabase credentials not loaded. Check your .env file and restart your server.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

app = FastAPI()

# Allow CORS for all origins (for development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create directories if they don't exist
backend_dir = os.path.dirname(__file__)
static_dir = os.path.join(backend_dir, "static")
croppedresult_dir = os.path.join(static_dir, "croppedresult")
temp_uploads_dir = os.path.join(backend_dir, "temp_uploads")

# Ensure all required directories exist
os.makedirs(static_dir, exist_ok=True)
os.makedirs(croppedresult_dir, exist_ok=True)
os.makedirs(temp_uploads_dir, exist_ok=True)

# Mount static directory (keep for local development/testing)
app.mount("/croppedresult", StaticFiles(directory=croppedresult_dir), name="croppedresult")

# Load YOLO model
MODEL_PATH = os.path.join(backend_dir, '..', 'best.pt')
model = YOLO(MODEL_PATH)

def get_next_billboard_number():
    """Get the next billboard number for sequential naming"""
    try:
        # Check Supabase storage for existing files
        result = supabase.storage.from_('images').list()
        if not result:
            return 1
        
        # Extract numbers from existing files
        numbers = []
        for file_info in result:
            filename = file_info['name']
            match = re.search(r'billboard.*?(\d+)', filename)
            if match:
                numbers.append(int(match.group(1)))
        
        return max(numbers) + 1 if numbers else 1
        
    except Exception as e:
        print(f"Error getting next billboard number from Supabase: {e}")
        # Fallback to local check
        try:
            existing_files = glob.glob(os.path.join(croppedresult_dir, "billboard*.png")) + \
                             glob.glob(os.path.join(croppedresult_dir, "billboard*.jpg"))
            
            if not existing_files:
                return 1
            
            numbers = []
            for file in existing_files:
                filename = os.path.basename(file)
                match = re.search(r'billboard.*?(\d+)', filename)
                if match:
                    numbers.append(int(match.group(1)))
            
            return max(numbers) + 1 if numbers else 1
        except:
            return 1

def upload_image_to_supabase(file_path: str, filename: str) -> str:
    """Upload image to Supabase Storage and return public URL"""
    try:
        print(f"Attempting to upload {filename} to Supabase Storage...")
        
        # Read the file
        with open(file_path, 'rb') as f:
            file_data = f.read()
        
        print(f"File size: {len(file_data)} bytes")
        
        # Upload to Supabase Storage
        try:
            result = supabase.storage.from_('images').upload(filename, file_data)
            print(f"Upload result: {result}")
            
            if result:
                # Get public URL
                public_url = supabase.storage.from_('images').get_public_url(filename)
                print(f"Image uploaded successfully. Public URL: {public_url}")
                return public_url
            else:
                raise Exception("Upload result was None or empty")
                
        except Exception as upload_error:
            print(f"Detailed upload error: {upload_error}")
            print(f"Error type: {type(upload_error)}")
            raise upload_error
            
    except Exception as e:
        print(f"Error uploading image to Supabase Storage: {e}")
        print(f"Error type: {type(e)}")
        import traceback
        traceback.print_exc()
        raise e

@app.post("/analyze-image/")
async def analyze_image(
    image: UploadFile = File(...),
    gps_latitude: str = Form(""),
    gps_longitude: str = Form(""),
    violation_reason: str = Form(...),
    report_type: str = Form(...),  # New field for category (Hazardous/Illegal/Inappropriate)
    action_taken: str = Form(...),  # New field for action description
    user_id: str = Form(...)  # This should be Supabase UUID
):
    try:
        print(f"Received request for user: {user_id}")
        print(f"Report type: {report_type}, Action: {action_taken}")

        # Validate user_id format and existence
        try:
            validated_uuid = str(uuid.UUID(user_id))
            # Check if user exists in database
            user_check = supabase.table("users").select("id").eq("id", validated_uuid).execute()
            if not user_check.data:
                raise HTTPException(status_code=400, detail="User not found")
            print(f"Valid user confirmed: {validated_uuid}")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid user ID format")

        # Validate report_type
        valid_report_types = ['Hazardous', 'Illegal', 'Inappropriate']
        if report_type not in valid_report_types:
            raise HTTPException(status_code=400, detail=f"Invalid report type. Must be one of: {valid_report_types}")

        # Save uploaded image temporarily
        temp_path = os.path.join(temp_uploads_dir, f"temp_{uuid.uuid4()}{os.path.splitext(image.filename)[1]}")
        with open(temp_path, "wb") as f:
            f.write(await image.read())

        # Process image with YOLO
        with tempfile.TemporaryDirectory() as temp_output_dir:
            vis_path = os.path.join(temp_output_dir, "billboard_vis.png")
            subprocess.run([
                "python", "-c",
                (
                    "from ultralytics import YOLO; "
                    "import sys; "
                    "from PIL import Image; "
                    "model=YOLO(r'{}'); "
                    "results=model(r'{}'); "
                    "im=results[0].plot(); "
                    "Image.fromarray(im).save(r'{}')"
                ).format(MODEL_PATH.replace('\\', '\\\\'), temp_path.replace('\\', '\\\\'), vis_path.replace('\\', '\\\\'))
            ], check=True)

            # Generate filename for storage
            next_billboard_num = get_next_billboard_number()
            filename = f"billboard{next_billboard_num}.png"

            # Upload to Supabase Storage images bucket
            try:
                public_url = upload_image_to_supabase(vis_path, filename)
                print(f"Image uploaded to Supabase Storage: {public_url}")
            except Exception as upload_error:
                print(f"Failed to upload to Supabase: {upload_error}")
                raise HTTPException(status_code=500, detail="Failed to upload image")

        # Process GPS coordinates
        try:
            lat = float(gps_latitude) if gps_latitude.strip() else None
            lng = float(gps_longitude) if gps_longitude.strip() else None
        except (ValueError, AttributeError):
            lat = None
            lng = None

        # Prepare report data - REMOVE report_id as it's auto-generated
        timestamp = datetime.utcnow().isoformat()
        report_data = {
            "image_url": public_url,
            "timestamp": timestamp,
            "status": "under review",
            "issue": violation_reason,
            "report_type": report_type,  # New field for category
            "action_taken": action_taken,  # New field for action description
            "user_id": validated_uuid
            # Don't include report_id - let it auto-increment
        }

        if lat is not None:
            report_data["gps_latitude"] = lat
        if lng is not None:
            report_data["gps_longitude"] = lng

        # Insert into Supabase - let report_id auto-increment
        insert_result = supabase.table("reports").insert(report_data).execute()

        # Fetch the latest report for this user (should be the one just inserted)
        fetch_result = supabase.table("reports") \
            .select("report_id") \
            .eq("user_id", validated_uuid) \
            .order("timestamp", desc=True) \
            .limit(1) \
            .execute()

        if fetch_result.data:
            report_id = fetch_result.data[0]["report_id"]
        else:
            raise HTTPException(status_code=500, detail="Failed to retrieve report ID after insert")

        # Clean up temporary file
        if os.path.exists(temp_path):
            os.remove(temp_path)
            print(f"Cleaned up temporary file: {temp_path}")

        response_data = {
            "report_id": report_id,
            "image_url": public_url,
            "billboard_number": next_billboard_num,
            "gps_latitude": lat,
            "gps_longitude": lng,
            "timestamp": timestamp,
            "status": "under review",
            "issue": violation_reason,
            "report_type": report_type,  # Include in response
            "action_taken": action_taken,  # Include in response
            "user_id": validated_uuid,
            "message": "Report submitted successfully"
        }

        print(f"Returning response: {response_data}")
        return JSONResponse(content=response_data)

    except HTTPException:
        raise
    except subprocess.CalledProcessError as e:
        error_msg = f"YOLO processing failed: {str(e)}"
        print(f"Subprocess error: {error_msg}")
        return JSONResponse(content={"error": error_msg}, status_code=500)
    except Exception as e:
        error_msg = f"Server error: {str(e)}"
        print(f"General error: {error_msg}")
        import traceback
        traceback.print_exc()
        return JSONResponse(content={"error": error_msg}, status_code=500)

# Test endpoint to create a dummy user (for testing)
@app.post("/create-test-user/")
async def create_test_user():
    try:
        test_user_data = {
            "firebase_uid": f"test_user_{uuid.uuid4()}",
            "email": f"test{uuid.uuid4()}@example.com",
            "username": f"testuser_{uuid.uuid4()}",
            "full_name": "Test User",
            "phone": "+1234567890"
        }
        
        result = supabase.table("users").insert(test_user_data).execute()
        return JSONResponse(content={
            "message": "Test user created successfully",
            "user_id": result.data[0]["id"] if result.data else None,
            "user_data": result.data[0] if result.data else None
        })
    except Exception as e:
        return JSONResponse(content={"error": f"Failed to create test user: {str(e)}"}, status_code=500)

# Verify user endpoint (optional but helpful for debugging)
@app.get("/users/{user_id}/verify")
async def verify_user(user_id: str):
    """Verify that a user exists in the database"""
    try:
        print(f"Verifying user: {user_id}")
        # Validate UUID format
        try:
            validated_uuid = str(uuid.UUID(user_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid user ID format")
        # Check if user exists
        result = supabase.table("users").select("id, username, full_name, email").eq("id", validated_uuid).execute()
        if result.data:
            user_data = result.data[0]
            return JSONResponse(content={
                "exists": True,
                "user_data": user_data,
                "message": f"User {validated_uuid} verified successfully"
            })
        else:
            return JSONResponse(content={
                "exists": False,
                "message": f"User {validated_uuid} not found"
            }, status_code=404)
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error verifying user {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to verify user: {str(e)}")

# Get user statistics with report type breakdown
@app.get("/users/{user_id}/stats")
async def get_user_stats(user_id: str):
    """Get report statistics for a specific user including report type breakdown"""
    try:
        print(f"Getting stats for user: {user_id}")
        # Validate UUID format
        try:
            validated_uuid = str(uuid.UUID(user_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid user ID format")
        # Get all reports for the user
        reports_result = supabase.table("reports").select("status, report_type").eq("user_id", validated_uuid).execute()
        if not reports_result.data:
            return JSONResponse(content={
                "user_id": validated_uuid,
                "total_reports": 0,
                "status_stats": {},
                "type_stats": {}
            })
        # Calculate status statistics
        status_stats = {
            "total": len(reports_result.data),
            "under review": 0,
            "resolved": 0,
            "rejected": 0,
            "in progress": 0
        }
        
        # Calculate report type statistics
        type_stats = {
            "Hazardous": 0,
            "Illegal": 0,
            "Inappropriate": 0
        }
        
        for report in reports_result.data:
            # Count by status
            status = report.get('status', '').lower()
            if status in status_stats:
                status_stats[status] += 1
            
            # Count by report type
            report_type = report.get('report_type', '')
            if report_type in type_stats:
                type_stats[report_type] += 1
        
        return JSONResponse(content={
            "user_id": validated_uuid,
            "total_reports": status_stats["total"],
            "status_stats": status_stats,
            "type_stats": type_stats
        })
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error getting user stats for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get user stats: {str(e)}")

# Updated get user reports endpoint with report type and action taken
@app.get("/reports/user/{user_id}")
async def get_user_reports(user_id: str):
    try:
        print(f"Fetching reports for user_id: {user_id}")
        # Validate UUID format
        try:
            validated_uuid = str(uuid.UUID(user_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid user ID format")
        # Verify user exists first
        user_check = supabase.table("users").select("id").eq("id", validated_uuid).execute()
        if not user_check.data:
            raise HTTPException(status_code=404, detail="User not found")
        # Get reports for the user
        result = supabase.table("reports").select("*").eq("user_id", validated_uuid).order("timestamp", desc=True).execute()
        print(f"Found {len(result.data)} reports for user {validated_uuid}")
        return JSONResponse(content={
            "user_id": validated_uuid,
            "total_reports": len(result.data),
            "reports": result.data
        })
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching user reports: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch user reports: {str(e)}")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Test database connection
        test_result = supabase.table("users").select("count").limit(1).execute()
        return JSONResponse(content={
            "status": "healthy",
            "database": "connected",
            "timestamp": datetime.utcnow().isoformat()
        })
    except Exception as e:
        return JSONResponse(content={
            "status": "unhealthy",
            "database": "disconnected",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }, status_code=503)

# Get all reports endpoint with report type filtering
@app.get("/reports/")
async def get_reports(report_type: str = None):
    try:
        query = supabase.table("reports").select("*")
        if report_type and report_type in ['Hazardous', 'Illegal', 'Inappropriate']:
            query = query.eq("report_type", report_type)
        result = query.order("timestamp", desc=True).execute()
        return JSONResponse(content={"reports": result.data})
    except Exception as e:
        return JSONResponse(content={"error": f"Failed to fetch reports: {str(e)}"}, status_code=500)

# Get report statistics by type
@app.get("/reports/stats/by-type")
async def get_report_stats_by_type():
    """Get report statistics broken down by report type"""
    try:
        result = supabase.table("reports").select("report_type, status").execute()
        
        stats = {
            "Hazardous": {"total": 0, "under review": 0, "resolved": 0, "rejected": 0, "in progress": 0},
            "Illegal": {"total": 0, "under review": 0, "resolved": 0, "rejected": 0, "in progress": 0},
            "Inappropriate": {"total": 0, "under review": 0, "resolved": 0, "rejected": 0, "in progress": 0}
        }
        
        for report in result.data:
            report_type = report.get('report_type', '')
            status = report.get('status', '').lower()
            
            if report_type in stats:
                stats[report_type]["total"] += 1
                if status in stats[report_type]:
                    stats[report_type][status] += 1
        
        return JSONResponse(content={"type_stats": stats})
    except Exception as e:
        return JSONResponse(content={"error": f"Failed to fetch report stats: {str(e)}"}, status_code=500)

# NEW: Delete report endpoint
@app.delete("/reports/{report_id}")
async def delete_report(report_id: str):
    try:
        print(f"Attempting to delete report: {report_id}")
        
        # First, check if the report exists and get its details
        check_result = supabase.table("reports").select("*").eq("report_id", report_id).execute()
        
        if not check_result.data:
            raise HTTPException(status_code=404, detail="Report not found")
        
        report = check_result.data[0]
        
        # Optional: Delete the image from Supabase Storage if needed
        # You might want to add user authorization here to ensure users can only delete their own reports
        image_url = report.get('image_url', '')
        if 'supabase' in image_url:
            try:
                # Extract filename from URL to delete from storage
                filename = image_url.split('/')[-1]
                supabase.storage.from_('images').remove([filename])
                print(f"Deleted image from storage: {filename}")
            except Exception as img_del_error:
                print(f"Could not delete image from storage: {img_del_error}")
                # Continue with report deletion even if image deletion fails
        
        # Delete the report from the database
        delete_result = supabase.table("reports").delete().eq("report_id", report_id).execute()
        
        if delete_result.data:
            print(f"Successfully deleted report: {report_id}")
            return JSONResponse(content={
                "message": "Report deleted successfully",
                "deleted_report_id": report_id
            })
        else:
            raise HTTPException(status_code=500, detail="Failed to delete report from database")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error deleting report {report_id}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to delete report: {str(e)}")

# NEW: Delete report with user authorization
@app.delete("/reports/{report_id}/user/{user_id}")
async def delete_user_report(report_id: str, user_id: str):
    try:
        print(f"Attempting to delete report {report_id} for user {user_id}")
        
        # Check if the report exists and belongs to the user
        check_result = supabase.table("reports").select("*").eq("report_id", report_id).eq("user_id", user_id).execute()
        
        if not check_result.data:
            raise HTTPException(status_code=404, detail="Report not found or you don't have permission to delete it")
        
        report = check_result.data[0]
        
        # Delete the image from Supabase Storage if needed
        image_url = report.get('image_url', '')
        if 'supabase' in image_url:
            try:
                filename = image_url.split('/')[-1]
                supabase.storage.from_('images').remove([filename])
                print(f"Deleted image from storage: {filename}")
            except Exception as img_del_error:
                print(f"Could not delete image from storage: {img_del_error}")
        
        # Delete the report from the database
        delete_result = supabase.table("reports").delete().eq("report_id", report_id).eq("user_id", user_id).execute()
        
        if delete_result.data:
            print(f"Successfully deleted report: {report_id}")
            return JSONResponse(content={
                "message": "Report deleted successfully",
                "deleted_report_id": report_id
            })
        else:
            raise HTTPException(status_code=500, detail="Failed to delete report from database")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error deleting report {report_id} for user {user_id}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to delete report: {str(e)}")

# Test endpoint to upload image directly to Supabase Storage
@app.post("/test-upload/")
async def test_upload(image: UploadFile = File(...)):
    try:
        # Save uploaded image temporarily
        temp_path = os.path.join(temp_uploads_dir, image.filename)
        with open(temp_path, "wb") as f:
            f.write(await image.read())
        
        # Upload to Supabase Storage
        filename = f"test_{uuid.uuid4()}{os.path.splitext(image.filename)[1]}"
        public_url = upload_image_to_supabase(temp_path, filename)
        
        # Clean up
        os.remove(temp_path)
        
        return JSONResponse(content={
            "message": "Image uploaded successfully",
            "public_url": public_url,
            "filename": filename
        })
    except Exception as e:
        return JSONResponse(content={"error": f"Upload failed: {str(e)}"}, status_code=500)

@app.get("/")
async def root():
    return {"message": "Billboard Reporting API is running"}

# NEW: Get count of reports for the current month
@app.get("/reports/count/month")
async def get_monthly_report_count():
    """Get count of reports for the current month"""
    try:
        now = datetime.utcnow()
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        result = supabase.table("reports") \
            .select("report_id", count="exact") \
            .gte("timestamp", start_of_month.isoformat()) \
            .execute()
        return {"count": result.count or 0}
    except Exception as e:
        return {"count": 0, "error": str(e)}

# NEW: Get count of reports with status 'resolved'
@app.get("/reports/count/resolved")
async def get_resolved_report_count():
    """Get count of reports with status 'resolved'"""
    try:
        result = supabase.table("reports") \
            .select("report_id", count="exact") \
            .eq("status", "resolved") \
            .execute()
        return {"count": result.count or 0}
    except Exception as e:
        return {"count": 0, "error": str(e)}

# NEW: Calculate user points based on report status
def calculate_user_points(user_reports):
    """Calculate points for a user based on their report statuses"""
    points = 0
    for report in user_reports:
        status = report.get('status', '').lower()
        if status == 'resolved':
            points += 10
        elif status == 'rejected':
            points = max(0, points - 5)  # Don't go below 0
    return points

# NEW: Get leaderboard data
@app.get("/leaderboard/")
async def get_leaderboard():
    """Get leaderboard with user rankings based on points from resolved/rejected reports"""
    try:
        # Get all users
        users_result = supabase.table("users").select("id, username, full_name").execute()
        if not users_result.data:
            return JSONResponse(content={"leaderboard": []})
        
        leaderboard_data = []
        
        for user in users_result.data:
            user_id = user['id']
            username = user.get('username', user.get('full_name', 'Unknown User'))
            
            # Get all reports for this user
            reports_result = supabase.table("reports").select("status").eq("user_id", user_id).execute()
            
            # Calculate points
            points = calculate_user_points(reports_result.data)
            
            # Count total reports
            total_reports = len(reports_result.data)
            resolved_reports = len([r for r in reports_result.data if r.get('status', '').lower() == 'resolved'])
            rejected_reports = len([r for r in reports_result.data if r.get('status', '').lower() == 'rejected'])
            
            # Only include users with at least some activity
            if total_reports > 0:
                leaderboard_data.append({
                    "user_id": user_id,
                    "username": username,
                    "points": points,
                    "total_reports": total_reports,
                    "resolved_reports": resolved_reports,
                    "rejected_reports": rejected_reports
                })
        
        # Sort by points (descending) and then by total reports (descending)
        leaderboard_data.sort(key=lambda x: (x['points'], x['total_reports']), reverse=True)
        
        # Add rank to each user
        for i, user_data in enumerate(leaderboard_data):
            user_data['rank'] = i + 1
        
        return JSONResponse(content={"leaderboard": leaderboard_data})
        
    except Exception as e:
        print(f"Error getting leaderboard: {e}")
        return JSONResponse(content={"error": f"Failed to get leaderboard: {str(e)}"}, status_code=500)

# NEW: Get specific user's rank and points
@app.get("/users/{user_id}/rank")
async def get_user_rank(user_id: str):
    """Get a specific user's rank and points"""
    try:
        # Validate UUID format
        try:
            validated_uuid = str(uuid.UUID(user_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid user ID format")
        
        # Get leaderboard to find user's rank
        leaderboard_response = await get_leaderboard()
        leaderboard_content = leaderboard_response.body.decode('utf-8')
        leaderboard_data = json.loads(leaderboard_content)
        
        if 'error' in leaderboard_data:
            raise HTTPException(status_code=500, detail="Failed to get leaderboard data")
        
        # Find user in leaderboard
        user_data = None
        for user in leaderboard_data['leaderboard']:
            if user['user_id'] == validated_uuid:
                user_data = user
                break
        
        if user_data:
            return JSONResponse(content={
                "user_id": validated_uuid,
                "rank": user_data['rank'],
                "points": user_data['points'],
                "total_reports": user_data['total_reports'],
                "resolved_reports": user_data['resolved_reports'],
                "rejected_reports": user_data['rejected_reports'],
                "username": user_data['username']
            })
        else:
            # User not in leaderboard (no reports), return default values
            user_result = supabase.table("users").select("username, full_name").eq("id", validated_uuid).execute()
            username = "Unknown User"
            if user_result.data:
                username = user_result.data[0].get('username', user_result.data[0].get('full_name', 'Unknown User'))
            
            return JSONResponse(content={
                "user_id": validated_uuid,
                "rank": None,
                "points": 0,
                "total_reports": 0,
                "resolved_reports": 0,
                "rejected_reports": 0,
                "username": username
            })
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error getting user rank for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get user rank: {str(e)}")

# NEW: Update report status (for admin/testing)
@app.put("/reports/{report_id}/status")
async def update_report_status(report_id: str, status: str = Form(...)):
    """Update report status - useful for testing the points system"""
    try:
        valid_statuses = ['under review', 'resolved', 'rejected', 'in progress']
        if status.lower() not in valid_statuses:
            raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {valid_statuses}")
        
        # Update the report status
        result = supabase.table("reports").update({"status": status.lower()}).eq("report_id", report_id).execute()
        
        if result.data:
            return JSONResponse(content={
                "message": "Report status updated successfully",
                "report_id": report_id,
                "new_status": status.lower()
            })
        else:
            raise HTTPException(status_code=404, detail="Report not found")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error updating report status: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update report status: {str(e)}")