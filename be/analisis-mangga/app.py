from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from ultralytics import YOLO

app = Flask(__name__)
CORS(app)
MODEL_PATH = 'best-fix-1.pt'
TEMP_DIR = 'temp'

# Load YOLOv8 model
def load_model():
    try:
        model = YOLO(MODEL_PATH)
        print("YOLOv8 model loaded successfully!")
        return model
    except Exception as e:
        print(f"Failed to load YOLOv8 model: {e}")
        raise e

# Assign grade based on ripeness level and size
def assign_grade(detection):
    cls = detection['ripeness_level']
    bbox = detection['bounding_box']
    width = bbox['xmax'] - bbox['xmin']
    height = bbox['ymax'] - bbox['ymin']
    area = width * height

    if area > 50000:
        size = 'besar'
    elif area > 25000:
        size = 'sedang'
    else:
        size = 'kecil'

    if cls == 'sangat matang':
        return 'A' if size in ['besar', 'sedang'] else 'B'
    elif cls == 'matang':
        return 'A' if size == 'besar' else 'B'
    elif cls == 'mengkal':
        return 'C' if size == 'kecil' else 'B'
    elif cls == 'mentah':
        return 'B' if size == 'besar' else 'C'
    elif cls == 'sangat mentah':
        return 'C'
    else:
        return 'C'

# Process image and return predictions
def process_image(image_path):
    results = model(image_path)
    output = []

    for r in results:
        boxes = r.boxes
        if boxes is None:
            continue

        for box in boxes:
            x1, y1, x2, y2 = box.xyxy[0]
            xmin, ymin, xmax, ymax = int(x1), int(y1), int(x2), int(y2)
            conf = float(box.conf[0])
            cls = int(box.cls[0])
            label = model.names[cls]

            detection = {
                "ripeness_level": label,
                "confidence": conf,
                "bounding_box": {
                    "xmin": xmin,
                    "ymin": ymin,
                    "xmax": xmax,
                    "ymax": ymax
                }
            }
            detection["grade"] = assign_grade(detection)
            output.append(detection)
    
    return output

# Clean up file
def cleanup_file(path):
    if os.path.exists(path):
        os.remove(path)

# Load model saat startup
try:
    model = load_model()
except Exception as e:
    model = None

@app.route('/predict', methods=['POST'])
def predict():
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500

    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    image_file = request.files['image']
    os.makedirs(TEMP_DIR, exist_ok=True)
    image_path = os.path.join(TEMP_DIR, image_file.filename)
    image_file.save(image_path)

    try:
        detections = process_image(image_path)
        cleanup_file(image_path)

        return jsonify({
            "success": True,
            "detections": detections,
            "total_mangoes": len(detections)
        })
    except Exception as e:
        cleanup_file(image_path)
        return jsonify({'error': f'Prediction failed: {str(e)}'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None,
        'model_type': 'yolov8',
        'model_file': MODEL_PATH
    })

if __name__ == '__main__':
    os.makedirs(TEMP_DIR, exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=True)
