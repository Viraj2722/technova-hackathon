import os
import sys
import urllib.request
import subprocess

BEST_PT_URL = "https://raw.githubusercontent.com/Viraj2722/billboard-classification-model/main/best.pt"
REQUIREMENTS_URL = "https://raw.githubusercontent.com/Viraj2722/technova-hackathon/main/backend/requirements.txt"
BACKEND_DIR = os.path.join(os.path.dirname(__file__), "backend")
BEST_PT_PATH = os.path.join("best.pt")
REQUIREMENTS_PATH = os.path.join(BACKEND_DIR, "requirements.txt")

# Download best.pt
if not os.path.exists(BEST_PT_PATH):
    print("Downloading best.pt...")
    urllib.request.urlretrieve(BEST_PT_URL, BEST_PT_PATH)
    print("Downloaded best.pt to current directory.")
else:
    print("best.pt already exists.")

