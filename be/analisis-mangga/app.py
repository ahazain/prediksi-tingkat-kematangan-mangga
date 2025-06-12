from flask import Flask, request, jsonify
import os
from PIL import Image
import cv2
import numpy as np

app = Flask(__name__)

# Coba load YOLOv8 terlebih dahulu, fallback ke YOLOv5 jika gagal
def load_model():
    # Prioritas 1: YOLOv8 (lebih stabil)
    try:
        from ultralytics import YOLO
        model = YOLO('best.pt')
        print("YOLOv8 model loaded successfully!")
        return model, 'yolov8'
    except Exception as e:
        print(f"YOLOv8 failed: {e}")
        
        # Prioritas 2: YOLOv5 dengan manual loading
        try:
            import torch
            # Manual clear cache
            import shutil
            cache_dir = os.path.expanduser("~/.cache/torch/hub/ultralytics_yolov5_master")
            if os.path.exists(cache_dir):
                shutil.rmtree(cache_dir)
                print("Cleared YOLOv5 cache")
            
            model = torch.hub.load('ultralytics/yolov5', 'custom', 
                                  path='best.pt', 
                                  force_reload=True,
                                  trust_repo=True)
            print("YOLOv5 model loaded successfully!")
            return model, 'yolov5'
        except Exception as e2:
            print(f"YOLOv5 also failed: {e2}")
            raise e2

# Load model saat startup
try:
    model, model_type = load_model()
    print(f"Model loaded successfully! Type: {model_type}")
except Exception as e:
    print(f"Failed to load any model: {e}")
    model = None
    model_type = None

def hitung_grade_dan_harga(label, xmin, ymin, xmax, ymax):
    luas = (xmax - xmin) * (ymax - ymin)

    if label == "not durian":
        return "X", 0
    elif label in ["musang king", "black thorn", "monthong", "kanyao"]:
        if luas > 50000:
            return "A", 100000
        elif luas > 30000:
            return "B", 70000
        else:
            return "C", 50000
    elif label == "bawor":
        if luas > 50000:
            return "B", 70000
        else:
            return "C", 50000
    else:
        return "C", 50000

@app.route('/predict', methods=['POST'])
def predict():
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500
        
    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    image_file = request.files['image']
    
    # Pastikan folder temp ada
    os.makedirs('temp', exist_ok=True)
    
    image_path = os.path.join('temp', image_file.filename)
    image_file.save(image_path)

    try:
        # Inference berdasarkan tipe model
        results = model(image_path)
        output = []

        if model_type == 'yolov8':
            # YOLOv8 format
            for r in results:
                boxes = r.boxes
                if boxes is not None:
                    for box in boxes:
                        # Get box coordinates
                        x1, y1, x2, y2 = box.xyxy[0]
                        xmin, ymin, xmax, ymax = int(x1), int(y1), int(x2), int(y2)
                        
                        # Get confidence and class
                        conf = float(box.conf[0])
                        cls = int(box.cls[0])
                        label = model.names[cls]
                        
                        grade, harga = hitung_grade_dan_harga(label, xmin, ymin, xmax, ymax)
                        
                        output.append({
                            "label": label,
                            "confidence": conf,
                            "xmin": xmin,
                            "ymin": ymin,
                            "xmax": xmax,
                            "ymax": ymax,
                            "grade": grade,
                            "harga": harga
                        })
        
        elif model_type == 'yolov5':
            # YOLOv5 format - gunakan pandas
            if hasattr(results, 'pandas'):
                df = results.pandas().xyxy[0]
                for _, row in df.iterrows():
                    label = row['name']
                    conf = row['confidence']
                    xmin, ymin, xmax, ymax = int(row['xmin']), int(row['ymin']), int(row['xmax']), int(row['ymax'])
                    
                    grade, harga = hitung_grade_dan_harga(label, xmin, ymin, xmax, ymax)
                    
                    output.append({
                        "label": label,
                        "confidence": conf,
                        "xmin": xmin,
                        "ymin": ymin,
                        "xmax": xmax,
                        "ymax": ymax,
                        "grade": grade,
                        "harga": harga
                    })
            else:
                # Alternative YOLOv5 format
                for r in results:
                    if hasattr(r, 'boxes') and r.boxes is not None:
                        for box in r.boxes:
                            cls_id = int(box.cls)
                            conf = float(box.conf)
                            xyxy = box.xyxy[0].tolist()
                            xmin, ymin, xmax, ymax = map(int, xyxy)
                            label = model.names[cls_id]

                            grade, harga = hitung_grade_dan_harga(label, xmin, ymin, xmax, ymax)

                            output.append({
                                "label": label,
                                "confidence": conf,
                                "xmin": xmin,
                                "ymin": ymin,
                                "xmax": xmax,
                                "ymax": ymax,
                                "grade": grade,
                                "harga": harga
                            })

        # Clean up
        if os.path.exists(image_path):
            os.remove(image_path)
            
        return jsonify(output)
        
    except Exception as e:
        # Clean up on error
        if os.path.exists(image_path):
            os.remove(image_path)
        return jsonify({'error': f'Prediction failed: {str(e)}'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None,
        'model_type': model_type if model is not None else None
    })

if __name__ == '__main__':
    os.makedirs('temp', exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=True)