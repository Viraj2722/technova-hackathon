import sys
import os
from ultralytics import YOLO

MODEL_PATH = os.path.join(os.path.dirname(__file__), '..', 'best.pt')
TEST_IMAGE_PATH = 'C:/Users/hp1/OneDrive/Desktop/technova-hackathon/image.png'  # Change this to your test image file

def run_model(image_path, output_dir=None):
    # Load Ultralytics YOLO model
    model = YOLO(MODEL_PATH)
        # Run inference
    results = model(image_path)
    print(results)
    # Load original image
    from PIL import Image
    import numpy as np
    img = Image.open(image_path)
    img_np = np.array(img)
    # Ensure output_dir is valid
    if output_dir is None:
            output_dir = os.path.abspath("static/croppedresult")
    else:
            output_dir = os.path.abspath(output_dir)
    os.makedirs(output_dir, exist_ok=True)
        # Crop and save each detected billboard
    count = 0
    for box in results[0].boxes.xyxy:
            x1, y1, x2, y2 = map(int, box)
            cropped = img_np[y1:y2, x1:x2]
            cropped_img = Image.fromarray(cropped)
            save_path = os.path.join(output_dir, f"cropped_billboard_{count}.png")
            cropped_img.save(save_path)
            print(f"Saved cropped image: {save_path}")
            count += 1
    print(f"Saving cropped results to: {output_dir}")
        # List files in output_dir
    files = os.listdir(output_dir)
    print(f"Files in output_dir: {files}")
        # Find cropped images
    cropped_files = [f for f in files if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    print(f"Found files: {cropped_files}")

if __name__ == '__main__':
    image_path = TEST_IMAGE_PATH
    output_dir = None
    if len(sys.argv) > 2:
        image_path = sys.argv[1]
        output_dir = sys.argv[2]
    elif len(sys.argv) > 1:
        image_path = sys.argv[1]
    run_model(image_path, output_dir)
        
