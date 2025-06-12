from flask import Flask, request, jsonify
import os
from ultralytics import YOLO

app = Flask(__name__)

def load_model():
    try:
        model = YOLO('best2.pt')
        print("YOLOv8 model loaded successfully!")
        return model
    except Exception as e:
        print(f"Failed to load YOLOv8 model: {e}")
        raise e

# Load model saat startup
try:
    model = load_model()
    print("Model loaded successfully!")
except Exception as e:
    print(f"Failed to load model: {e}")
    model = None

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
        # Inference dengan YOLOv8
        results = model(image_path)
        output = []

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
                    
                    output.append({
                        "ripeness_level": label,
                        "confidence": conf,
                        "bounding_box": {
                            "xmin": xmin,
                            "ymin": ymin,
                            "xmax": xmax,
                            "ymax": ymax
                        }
                    })

        # Clean up
        if os.path.exists(image_path):
            os.remove(image_path)
            
        return jsonify({
            "success": True,
            "detections": output,
            "total_mangoes": len(output)
        })
        
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
        'model_type': 'yolov8',
        'model_file': 'best2.pt'
    })

if __name__ == '__main__':
    os.makedirs('temp', exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=True)