# my_app

# Technova Hackathon Project

## Overview

This project is a Flutter app and FastAPI backend for reporting non-compliant billboards. The backend uses a YOLO model to crop billboards from uploaded images and stores report data in Supabase.

---

## Prerequisites

## 📂 Model Download
To run this app, please download the trained model file from the link below and place it in the root directory of the app:

🔗 [Download Model File](https://github.com/Viraj2722/billboard-classification-model/)


### Backend

- Python 3.10+
- pip
- Ultralytics YOLO (`pip install ultralytics`)
- FastAPI (`pip install fastapi uvicorn`)
- Supabase Python client (`pip install supabase`)
- dotenv (`pip install python-dotenv`)
- Pillow, numpy (`pip install pillow numpy`)
- Your YOLO model file (`best.pt`) in the backend folder

### Flutter App

- Flutter SDK (https://docs.flutter.dev/get-started/install)
- Android/iOS device or emulator

---

## Backend Setup

1. **Install dependencies:**

   ```sh
   pip install -r requirements.txt
   ```

   Or install manually as above.

2. **Configure Supabase:**

   - Create a `.env` file in the backend folder:
     ```env
     SUPABASE_URL=your_supabase_url
     SUPABASE_KEY=your_supabase_key
     ```

3. **Run the backend server:**
   ```sh
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
   - Make sure your firewall allows port 8000.
   - The server should be accessible at `http://<your-ip>:8000` from your local network.

---

## Flutter App Setup

1. **Install dependencies:**

   ```sh
   flutter pub get
   ```

2. **Update API endpoint:**

   - In `camera-screen.dart`, set the backend URL to your machine's IP (e.g., `http://192.168.0.104:8000/analyze-image/`).

3. **Run the app:**
   ```sh
   flutter run
   ```
   - Use a real device or emulator on the same WiFi network as the backend.

---

## Usage

- Open the app, capture a billboard image, select a violation reason, and submit.
- The backend will crop the billboard, save the result, and store the report in Supabase.
- Cropped images are available at `/croppedresult/` on the backend.

---

## Troubleshooting

- If you get CORS errors, make sure the backend allows all origins (see `main.py`).
- If you get 422 errors, ensure all required fields are sent from the app.
- If the app can't connect, check your IP, firewall, and network.

---

## Folder Structure

- `backend/` - FastAPI server, YOLO model, Supabase integration
- `lib/` - Flutter app code
- `android/`, `ios/` - Platform-specific code

---

test command : 
curl -X POST "http://127.0.0.1:8000/analyze-image/" -F "image=@C:\Users\hp1\OneDrive\Desktop\technova-hackathon\imag2.jpeg" -F "gps_latitude=12.3456" -F "gps_longitude=78.9012" -F "violation_reason=Your Reason Here" -F "user_id=3338bc13-72ba-41ba-9d91-f484628c5950"

## Credits

- Built for Technova Hackathon
- YOLO model by Ultralytics
- Supabase for backend database
