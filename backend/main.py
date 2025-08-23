from fastapi import FastAPI, UploadFile, File, Form
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
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
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
    user_id: str = Form(...)
):
    try:
        print(f"Received request:")
        print(f"- GPS Latitude: {gps_latitude}")
        print(f"- GPS Longitude: {gps_longitude}")
        print(f"- Violation Reason: {violation_reason}")
        print(f"- User ID: {user_id}")
        print(f"- Image filename: {image.filename}")

        # Save uploaded image temporarily
        if not isinstance(image.filename, str):
            raise ValueError("image.filename must be a string")
        temp_path = os.path.join(temp_uploads_dir, image.filename)
        with open(temp_path, "wb") as f:
            f.write(await image.read())

        print(f"Saved temporary image to: {temp_path}")

        # Get the next billboard number for sequential naming
        next_billboard_num = get_next_billboard_number()
        print(f"Next billboard number: {next_billboard_num}")

        # Run YOLO model and save to temporary directory
        with tempfile.TemporaryDirectory() as temp_output_dir:
            subprocess.run([
                "python",
                os.path.join(backend_dir, "test_model.py"),
                temp_path,
                temp_output_dir
            ], check=True)

            # Find the cropped image in temp output directory
            found_files = glob.glob(os.path.join(temp_output_dir, "*.png")) + \
                         glob.glob(os.path.join(temp_output_dir, "*.jpg"))
            print("Found cropped files:", found_files)

            if not found_files:
                return JSONResponse(content={"error": "No cropped image found."}, status_code=500)

            # Get the most recent file (in case there are multiple detections)
            cropped_path = max(found_files, key=os.path.getctime)
            
            # Create filename with sequential numbering
            file_extension = os.path.splitext(cropped_path)[1]
            filename = f"billboard{next_billboard_num}{file_extension}"
            
            print(f"Uploading image as: {filename}")
            
            # Upload to Supabase Storage
            try:
                public_url = upload_image_to_supabase(cropped_path, filename)
                print(f"Image uploaded to Supabase Storage: {public_url}")
            except Exception as upload_error:
                print(f"Failed to upload to Supabase Storage: {upload_error}")
                # Fallback to local storage
                local_cropped_path = os.path.join(croppedresult_dir, filename)
                shutil.copy2(cropped_path, local_cropped_path)
                public_url = f"http://192.168.6.99:8000/croppedresult/{filename}"
                print(f"Fallback: Saved locally at {public_url}")

        # Convert GPS coordinates to float, handle empty strings
        try:
            lat = float(gps_latitude) if gps_latitude.strip() else None
            lng = float(gps_longitude) if gps_longitude.strip() else None
        except (ValueError, AttributeError):
            lat = None
            lng = None

        print(f"Processed coordinates: lat={lat}, lng={lng}")

        # Handle user_id - improved validation and user creation if needed
        parsed_user_id = None
        if user_id and user_id.strip() and user_id != 'anonymous':
            try:
                # First check if it's a valid UUID format
                validated_uuid = str(uuid.UUID(user_id))
                
                # Check if user exists in database
                user_check = supabase.table("users").select("id").eq("id", validated_uuid).execute()
                if user_check.data:
                    parsed_user_id = validated_uuid
                    print(f"Using existing user_id: {parsed_user_id}")
                else:
                    print(f"User {validated_uuid} not found in database")
                    parsed_user_id = None
            except ValueError:
                print(f"Invalid UUID format for user_id: {user_id}")
                try:
                    user_check = supabase.table("users").select("id").eq("firebase_uid", user_id).execute()
                    if user_check.data:
                        parsed_user_id = user_check.data[0]["id"]
                        print(f"Found user by firebase_uid: {parsed_user_id}")
                    else:
                        parsed_user_id = None
                        print(f"No user found with firebase_uid: {user_id}")
                except Exception as e:
                    print(f"Error checking firebase_uid: {e}")
                    parsed_user_id = None
        else:
            print("Anonymous or empty user_id, setting to None")

        # Prepare data for Supabase
        report_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        status = "under review"
        
        report_data = {
            "report_id": report_id,
            "image_url": public_url,  # Now contains Supabase Storage URL
            "timestamp": timestamp,
            "status": status,
            "issue": violation_reason,
            "user_id": parsed_user_id
        }
        
        # Only add GPS coordinates if they are valid
        if lat is not None:
            report_data["gps_latitude"] = lat
        if lng is not None:
            report_data["gps_longitude"] = lng

        print(f"Inserting report into Supabase: {report_data}")

        # Insert into Supabase
        result = supabase.table("reports").insert(report_data).execute()
        print(f"Supabase insert result: {result}")

        # Clean up temporary file
        if os.path.exists(temp_path):
            os.remove(temp_path)
            print(f"Cleaned up temporary file: {temp_path}")

        response_data = {
            "report_id": report_id,
            "image_url": public_url,  # Supabase Storage URL
            "billboard_number": next_billboard_num,
            "gps_latitude": lat,
            "gps_longitude": lng,
            "timestamp": timestamp,
            "status": status,
            "issue": violation_reason,
            "user_id": parsed_user_id,
            "message": "Report submitted successfully"
        }

        print(f"Returning response: {response_data}")
        return JSONResponse(content=response_data)

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

# Get reports by user ID endpoint
@app.get("/reports/user/{user_id}")
async def get_user_reports(user_id: str):
    try:
        result = supabase.table("reports").select("*").eq("user_id", user_id).order("timestamp", desc=True).execute()
        return JSONResponse(content={"reports": result.data})
    except Exception as e:
        return JSONResponse(content={"error": f"Failed to fetch user reports: {str(e)}"}, status_code=500)

# Get all reports endpoint
@app.get("/reports/")
async def get_reports():
    try:
        result = supabase.table("reports").select("*").order("timestamp", desc=True).execute()
        return JSONResponse(content={"reports": result.data})
    except Exception as e:
        return JSONResponse(content={"error": f"Failed to fetch reports: {str(e)}"}, status_code=500)

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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)