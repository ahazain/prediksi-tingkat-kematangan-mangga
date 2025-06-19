from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from config import Config
from models import db, History, Detection
from datetime import datetime
from ultralytics import YOLO
from sqlalchemy import func, extract
from collections import defaultdict

app = Flask(__name__)
CORS(app)
app.config.from_object(Config)
db.init_app(app)
migrate = Migrate(app, db)
MODEL_PATH = 'best.pt'
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
        history = History(
            detected_at=datetime.utcnow(),
            total_mangoes=len(detections)
        )
        db.session.add(history)
        db.session.flush()  # supaya dapat history.id sebelum commit

        for det in detections:
            box = det["bounding_box"]
            detection = Detection(
                history_id=history.id,
                confidence=det["confidence"],
                grade=det["grade"],
                ripeness_level=det["ripeness_level"],
                bbox_xmin=box["xmin"],
                bbox_xmax=box["xmax"],
                bbox_ymin=box["ymin"],
                bbox_ymax=box["ymax"]
            )
            db.session.add(detection)

        db.session.commit()
        return jsonify({
            "success": True,
            "detections": detections,
            "total_mangoes": len(detections)
        })
    except Exception as e:
        cleanup_file(image_path)
        return jsonify({'error': f'Prediction failed: {str(e)}'}), 500
    
    
    
@app.route('/yearly-summary', methods=['GET'])
def yearly_summary():
    """
    Endpoint untuk mendapatkan ringkasan tahunan
    """
    try:
        year = request.args.get('year', type=int, default=datetime.now().year)
        
        # Query untuk mendapatkan data tahunan
        monthly_stats = db.session.query(
            extract('month', History.detected_at).label('month'),
            func.count(History.id).label('total_sessions'),
            func.sum(History.total_mangoes).label('total_mangoes')
        ).filter(
            extract('year', History.detected_at) == year
        ).group_by(extract('month', History.detected_at)).all()
        
        # Query untuk distribusi grade
        grade_stats = db.session.query(
            Detection.grade,
            func.count(Detection.id).label('count')
        ).join(History, Detection.history_id == History.id).filter(
            extract('year', History.detected_at) == year
        ).group_by(Detection.grade).all()
        
        # Query untuk distribusi tingkat kematangan
        ripeness_stats = db.session.query(
            Detection.ripeness_level,
            func.count(Detection.id).label('count')
        ).join(History, Detection.history_id == History.id).filter(
            extract('year', History.detected_at) == year
        ).group_by(Detection.ripeness_level).all()
        
        # Format data bulanan
        monthly_data = []
        month_names = [
            '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
            'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
        ]
        
        for month, sessions, mangoes in monthly_stats:
            monthly_data.append({
                'month': int(month),
                'month_name': month_names[int(month)],
                'total_sessions': sessions or 0,
                'total_mangoes': mangoes or 0
            })
        
        # Sort berdasarkan bulan
        monthly_data.sort(key=lambda x: x['month'])
        
        return jsonify({
            'success': True,
            'year': year,
            'monthly_breakdown': monthly_data,
            'grade_distribution': {grade: count for grade, count in grade_stats},
            'ripeness_distribution': {ripeness: count for ripeness, count in ripeness_stats},
            'total_sessions': sum(item['total_sessions'] for item in monthly_data),
            'total_mangoes': sum(item['total_mangoes'] for item in monthly_data)
        })
        
    except Exception as e:
        return jsonify({'error': f'Failed to generate yearly summary: {str(e)}'}), 500

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