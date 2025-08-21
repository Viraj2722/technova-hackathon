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

# Endpoint to manually upload a cropped image
@app.post("/upload-cropped/")
async def upload_cropped_image(
    image: UploadFile = File(...)
):
    output_dir = os.path.join(os.path.dirname(__file__), "static", "croppedresult")
    os.makedirs(output_dir, exist_ok=True)
    dest_filename = f"{uuid.uuid4()}_{image.filename}"
    dest_path = os.path.join(output_dir, dest_filename)
    with open(dest_path, "wb") as f:
        f.write(await image.read())
    image_url = f"/croppedresult/{dest_filename}"
    return {"image_url": image_url, "message": "Cropped image uploaded successfully."}

# Mount static directory so images are served
app.mount("/croppedresult", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "croppedresult")), name="croppedresult")

# Load YOLO model
MODEL_PATH = os.path.join(os.path.dirname(__file__), '..', 'best.pt')
model = YOLO(MODEL_PATH)

@app.post("/analyze-image/")
async def analyze_image(
    image: UploadFile = File(...),
    gps_latitude: float = Form(...),
    gps_longitude: float = Form(...),
    violation_reason: str = Form(...),
    user_id: str = Form(...)
):
    # Save uploaded image temporarily
    temp_dir = "temp_uploads"
    os.makedirs(temp_dir, exist_ok=True)
    if not isinstance(image.filename, str):
        raise ValueError("image.filename must be a string")
    temp_path = os.path.join(temp_dir, image.filename)
    with open(temp_path, "wb") as f:
        f.write(await image.read())

        # Run YOLO model and save directly to static/croppedresult/
        output_dir = os.path.join(os.path.dirname(__file__), "static", "croppedresult")
        os.makedirs(output_dir, exist_ok=True)
        # Call test_model.py with output_dir as argument
        subprocess.run([
            "python",
            os.path.join(os.path.dirname(__file__), "test_model.py"),
            temp_path,
            output_dir
        ], check=True)

        # Find the cropped image in output_dir
        found_files = glob.glob(os.path.join(output_dir, "*.png")) + glob.glob(os.path.join(output_dir, "*.jpg"))
        print("Found files:", found_files)

        if not found_files:
            return JSONResponse(content={"error": "No cropped image found."}, status_code=500)

        cropped_path = max(found_files, key=os.path.getctime)  # get the newest file
        dest_filename = os.path.basename(cropped_path)
        image_url = f"/croppedresult/{dest_filename}"

    # Insert into Supabase
    report_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat()
    status = "under review"
    report = {
        "report_id": report_id,
        "image_url": image_url,
        "gps_latitude": gps_latitude,
        "gps_longitude": gps_longitude,
        "timestamp": timestamp,
        "status": status,
        "issue": violation_reason,
        "user_id": user_id
    }
    supabase.table("reports").insert(report).execute()

    return JSONResponse(content=report)
