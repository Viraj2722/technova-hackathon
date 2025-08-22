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

# Mount static directory
app.mount("/croppedresult", StaticFiles(directory=croppedresult_dir), name="croppedresult")

# Load YOLO model
MODEL_PATH = os.path.join(backend_dir, '..', 'best.pt')
model = YOLO(MODEL_PATH)

def get_next_billboard_number():
    """Get the next billboard number for sequential naming"""
    try:
        # Get all existing billboard files
        existing_files = glob.glob(os.path.join(croppedresult_dir, "billboard*.png")) + \
                         glob.glob(os.path.join(croppedresult_dir, "billboard*.jpg"))
        
        if not existing_files:
            return 1
        
        # Extract numbers from existing files
        numbers = []
        for file in existing_files:
            filename = os.path.basename(file)
            match = re.search(r'billboard.*?(\d+)', filename)
            if match:
                numbers.append(int(match.group(1)))
        
        return max(numbers) + 1 if numbers else 1
        
    except Exception as e:
        print(f"Error getting next billboard number: {e}")
        return 1

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

        # Run YOLO model and save directly to static/croppedresult/
        subprocess.run([
            "python",
            os.path.join(backend_dir, "test_model.py"),
            temp_path,
            croppedresult_dir
        ], check=True)

        # Find the cropped image in output_dir
        found_files = glob.glob(os.path.join(croppedresult_dir, "*.png")) + glob.glob(os.path.join(croppedresult_dir, "*.jpg"))
        print("Found cropped files:", found_files)

        if not found_files:
            return JSONResponse(content={"error": "No cropped image found."}, status_code=500)

        # Get the most recent file (in case there are multiple detections)
        cropped_path = max(found_files, key=os.path.getctime)
        
        # Create new filename with sequential numbering
        file_extension = os.path.splitext(cropped_path)[1]
        new_filename = f"billboard{next_billboard_num}{file_extension}"
        new_cropped_path = os.path.join(croppedresult_dir, new_filename)
        
        # Rename the file to the sequential name
        if cropped_path != new_cropped_path:
            shutil.move(cropped_path, new_cropped_path)
            print(f"Renamed {cropped_path} to {new_cropped_path}")
        
        # Clean up any other temporary cropped files
        temp_cropped_files = glob.glob(os.path.join(croppedresult_dir, "cropped_billboard_*.png")) + \
                             glob.glob(os.path.join(croppedresult_dir, "cropped_billboard_*.jpg"))
        for temp_file in temp_cropped_files:
            if temp_file != new_cropped_path:
                try:
                    os.remove(temp_file)
                    print(f"Cleaned up temporary file: {temp_file}")
                except:
                    pass

        image_url = f"/croppedresult/{new_filename}"
        print(f"Using renamed image: {new_filename}")

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
            "image_url": image_url,
            "timestamp": timestamp,
            "status": status,
            "issue": violation_reason,
            "user_id": parsed_user_id  # This can be None for anonymous reports
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

        # Return the full server URL for the image
        server_base_url = "http://192.168.6.99:8000"  # Update this to match your server IP
        full_image_url = f"{server_base_url}{image_url}"
        
        response_data = {
            "report_id": report_id,
            "image_url": full_image_url,
            "local_image_url": image_url,
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

# Get all reports endpoint
@app.get("/reports/")
async def get_reports():
    try:
        result = supabase.table("reports").select("*").execute()
        return JSONResponse(content={"reports": result.data})
    except Exception as e:
        return JSONResponse(content={"error": f"Failed to fetch reports: {str(e)}"}, status_code=500)

@app.get("/")
async def root():
    return {"message": "Billboard Reporting API is running"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)