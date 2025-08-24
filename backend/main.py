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
    user_id: str = Form(...)  # This should be Supabase UUID
):
    try:
        print(f"Received request for user: {user_id}")

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

# Get user statistics
@app.get("/users/{user_id}/stats")
async def get_user_stats(user_id: str):
    """Get report statistics for a specific user"""
    try:
        print(f"Getting stats for user: {user_id}")
        # Validate UUID format
        try:
            validated_uuid = str(uuid.UUID(user_id))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid user ID format")
        # Get all reports for the user
        reports_result = supabase.table("reports").select("status").eq("user_id", validated_uuid).execute()
        if not reports_result.data:
            return JSONResponse(content={
                "user_id": validated_uuid,
                "total_reports": 0,
                "stats": {}
            })
        # Calculate statistics
        stats = {
            "total": len(reports_result.data),
            "under review": 0,
            "resolved": 0,
            "rejected": 0,
            "in progress": 0
        }
        for report in reports_result.data:
            status = report.get('status', '').lower()
            if status in stats:
                stats[status] += 1
        return JSONResponse(content={
            "user_id": validated_uuid,
            "total_reports": stats["total"],
            "stats": stats
        })
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error getting user stats for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get user stats: {str(e)}")

# Updated get user reports endpoint with better validation
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

# Get all reports endpoint
@app.get("/reports/")
async def get_reports():
    try:
        result = supabase.table("reports").select("*").order("timestamp", desc=True).execute()
        return JSONResponse(content={"reports": result.data})
    except Exception as e:
        return JSONResponse(content={"error": f"Failed to fetch reports: {str(e)}"}, status_code=500)

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

# NEW: Get count of reports with status 'approved'
@app.get("/reports/count/resolved")
async def get_resolved_report_count():
    """Get count of reports with status 'resolved'"""
    try:
        result = supabase.table("reports") \
            .select("report_id", count="exact") \
            .eq("status", "Resolved") \
            .execute()
        return {"count": result.count or 0}
    except Exception as e:
        return {"count": 0, "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)