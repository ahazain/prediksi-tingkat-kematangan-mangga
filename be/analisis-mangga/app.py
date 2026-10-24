from flask import Flask, request, jsonify
from flask_cors import CORS
import os
# Matikan autoinstall background pip oleh Ultralytics agar tidak menghambat startup
os.environ["YOLO_AUTOINSTALL"] = "False"

from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from config import Config
from models import db, History, Detection
from datetime import datetime, timedelta
from ultralytics import YOLO
from sqlalchemy import func, extract
from collections import defaultdict
import torch
# Kunci PyTorch ke 1 thread agar tidak terjadi CPU-throttling di CPU Render (0.1 core)
torch.set_num_threads(1)
torch.set_num_interop_threads(1)
import numpy as np
import threading
import time
import cv2
import uuid

# ─────────────────────────────────────────────────────────────────────────────
# Job store in-memory untuk async processing
# Format: { job_id: { 'status': 'processing'|'done'|'error', 'result': {...}, 'created_at': float } }
# ─────────────────────────────────────────────────────────────────────────────
_jobs: dict = {}
_jobs_lock = threading.Lock()

def _cleanup_old_jobs():
    """Hapus job yang sudah lebih dari 10 menit agar RAM tidak penuh."""
    now = time.time()
    with _jobs_lock:
        expired = [jid for jid, j in _jobs.items() if now - j['created_at'] > 600]
        for jid in expired:
            del _jobs[jid]

app = Flask(__name__)
CORS(app)
app.config.from_object(Config)
db.init_app(app)
migrate = Migrate(app, db)
MODEL_PATH = 'best.pt'
TEMP_DIR = 'temp'

# Otomatis buat tabel di database jika belum ada (berguna saat pindah ke Neon.tech)
with app.app_context():
    try:
        db.create_all()
        print("[DATABASE] Inisialisasi tabel database berhasil.")
    except Exception as e:
        print(f"[DATABASE INIT ERROR] {e}")

# Auto-cleanup data riwayat lama (otomatis reset/hapus data > 2 hari agar database selalu ringan)
def cleanup_old_history(days=2):
    with app.app_context():
        try:
            cutoff = datetime.utcnow() - timedelta(days=days)
            old_histories = History.query.filter(History.detected_at < cutoff).all()
            if old_histories:
                old_ids = [h.id for h in old_histories]
                Detection.query.filter(Detection.history_id.in_(old_ids)).delete(synchronize_session=False)
                deleted = History.query.filter(History.id.in_(old_ids)).delete(synchronize_session=False)
                db.session.commit()
                print(f"[AUTO-CLEANUP] Berhasil membersihkan {deleted} riwayat yang lebih dari {days} hari.")
        except Exception as e:
            db.session.rollback()
            print(f"[AUTO-CLEANUP ERROR] {e}")
        finally:
            db.session.remove()

def start_cleanup_scheduler():
    def scheduler_loop():
        time.sleep(5)  # Tunggu 5 detik saat startup
        while True:
            cleanup_old_history(days=2)
            time.sleep(3600 * 6)  # Ulangi pemeriksaan setiap 6 jam

    thread = threading.Thread(target=scheduler_loop, daemon=True)
    thread.start()

start_cleanup_scheduler()

# DIoU-NMS Implementation
def diou_nms(boxes, scores, classes, iou_threshold=0.5):
    """
    Perform DIoU-NMS (Distance-IoU Non-Maximum Suppression)
    
    Args:
        boxes: tensor of shape (n, 4) - [x1, y1, x2, y2]
        scores: tensor of shape (n,) - confidence scores
        classes: tensor of shape (n,) - class labels
        iou_threshold: float - DIoU threshold for suppression
    
    Returns:
        keep_indices: list of indices to keep
    """
    if len(boxes) == 0:
        return []
    
    # Convert to torch tensors if needed
    if not isinstance(boxes, torch.Tensor):
        boxes = torch.tensor(boxes, dtype=torch.float32)
    if not isinstance(scores, torch.Tensor):
        scores = torch.tensor(scores, dtype=torch.float32)
    if not isinstance(classes, torch.Tensor):
        classes = torch.tensor(classes, dtype=torch.float32)
    
    keep_indices = []
    unique_classes = torch.unique(classes)
    
    for cls in unique_classes:
        cls_mask = classes == cls
        cls_boxes = boxes[cls_mask]
        cls_scores = scores[cls_mask]
        cls_original_indices = torch.where(cls_mask)[0]
        
        if len(cls_boxes) == 0:
            continue
            
        # Sort by confidence dan batasi ke 20 kandidat teratas agar while loop tidak lambat di CPU
        _, order = cls_scores.sort(0, descending=True)
        if len(order) > 20:
            order = order[:20]
        
        keep_cls = []
        while len(order) > 0:
            i = order[0]
            keep_cls.append(cls_original_indices[i].item())
            
            if len(order) == 1:
                break
            
            # Calculate DIoU with remaining boxes
            current_box = cls_boxes[i:i+1]
            remaining_boxes = cls_boxes[order[1:]]
            
            # Calculate intersection
            lt = torch.max(current_box[:, :2], remaining_boxes[:, :2])
            rb = torch.min(current_box[:, 2:], remaining_boxes[:, 2:])
            wh = (rb - lt).clamp(min=0)
            inter = wh[:, 0] * wh[:, 1]
            
            # Calculate areas
            area1 = (current_box[:, 2] - current_box[:, 0]) * (current_box[:, 3] - current_box[:, 1])
            area2 = (remaining_boxes[:, 2] - remaining_boxes[:, 0]) * (remaining_boxes[:, 3] - remaining_boxes[:, 1])
            union = area1 + area2 - inter
            
            # IoU
            iou = inter / (union + 1e-7)
            
            # Center points
            center1 = (current_box[:, :2] + current_box[:, 2:]) / 2
            center2 = (remaining_boxes[:, :2] + remaining_boxes[:, 2:]) / 2
            center_distance = torch.sum((center1 - center2) ** 2, dim=1)
            
            # Enclosing box diagonal
            enclose_lt = torch.min(current_box[:, :2], remaining_boxes[:, :2])
            enclose_rb = torch.max(current_box[:, 2:], remaining_boxes[:, 2:])
            diagonal = torch.sum((enclose_rb - enclose_lt) ** 2, dim=1)
            
            # DIoU
            diou = iou - center_distance / (diagonal + 1e-7)
            
            # Keep boxes with DIoU below threshold
            mask = diou <= iou_threshold
            order = order[1:][mask]
        
        keep_indices.extend(keep_cls)
    
    return keep_indices

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

# Process image and return predictions with DIoU-NMS
def process_image(image_path):
    """
    Process image using DIoU-NMS for better accuracy
    
    Args:
        image_path: path to image
    """
    # Get raw predictions without NMS (imgsz=320 hemat komputasi 75% dibanding default 640)
    results = model.predict(image_path, nms=False, conf=0.30, imgsz=320)
    
    filtered_results = []
    
    # Apply DIoU-NMS manually
    for result in results:
        if result.boxes is None or len(result.boxes) == 0:
            continue
        
        boxes = result.boxes.xyxy.cpu().numpy()
        scores = result.boxes.conf.cpu().numpy()
        classes = result.boxes.cls.cpu().numpy()
        
        # Apply DIoU-NMS with threshold 0.5
        keep_indices = diou_nms(boxes, scores, classes, 0.5)
        
        if keep_indices:
            # Create filtered data
            filtered_boxes = boxes[keep_indices]
            filtered_scores = scores[keep_indices]
            filtered_classes = classes[keep_indices]
            
            # Store filtered results
            filtered_results.append({
                'boxes': filtered_boxes,
                'scores': filtered_scores,
                'classes': filtered_classes
            })
    
    output = []

    # Process filtered results
    for filtered_result in filtered_results:
        boxes = filtered_result['boxes']
        scores = filtered_result['scores']
        classes = filtered_result['classes']
        
        for i in range(len(boxes)):
            x1, y1, x2, y2 = boxes[i]
            xmin, ymin, xmax, ymax = int(x1), int(y1), int(x2), int(y2)
            conf = float(scores[i])
            cls = int(classes[i])
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

@app.route('/', methods=['GET'])
def root():
    return jsonify({
        "status": "online",
        "message": "Deteksi Kematangan Mangga API is running"
    }), 200

@app.route('/predict', methods=['POST'])
def predict():
    """Terima gambar, buat job async, langsung kembalikan job_id (< 1 detik).
    Client harus polling GET /result/<job_id> sampai status == 'done'.
    """
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500

    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    image_file = request.files['image']
    os.makedirs(TEMP_DIR, exist_ok=True)

    # Simpan dengan nama unik agar tidak konflik antar request bersamaan
    job_id = str(uuid.uuid4())
    image_path = os.path.join(TEMP_DIR, f"{job_id}.jpg")
    image_file.save(image_path)

    # Registrasi job di store
    with _jobs_lock:
        _jobs[job_id] = {
            'status': 'processing',
            'result': None,
            'created_at': time.time()
        }

    # Jalankan inferensi di background thread
    def _run_inference(jid, img_path):
        try:
            # Downscale ke max 480px
            try:
                img_mat = cv2.imread(img_path)
                if img_mat is not None:
                    h, w = img_mat.shape[:2]
                    if max(h, w) > 480:
                        scale = 480.0 / max(h, w)
                        img_mat = cv2.resize(img_mat, (int(w * scale), int(h * scale)),
                                             interpolation=cv2.INTER_AREA)
                        cv2.imwrite(img_path, img_mat)
            except Exception as img_err:
                print(f"[RESIZE WARNING] {img_err}")

            detections = process_image(img_path)
            cleanup_file(img_path)

            # Simpan ke DB (non-blocking, error tidak menghambat response)
            try:
                with app.app_context():
                    history = History(
                        detected_at=datetime.utcnow(),
                        total_mangoes=len(detections)
                    )
                    db.session.add(history)
                    db.session.flush()
                    for det in detections:
                        box = det["bounding_box"]
                        db.session.add(Detection(
                            history_id=history.id,
                            confidence=det["confidence"],
                            grade=det["grade"],
                            ripeness_level=det["ripeness_level"],
                            bbox_xmin=box["xmin"],
                            bbox_xmax=box["xmax"],
                            bbox_ymin=box["ymin"],
                            bbox_ymax=box["ymax"]
                        ))
                    db.session.commit()
            except Exception as db_err:
                print(f"[PREDICT DB WARNING] {db_err}")
                try:
                    db.session.rollback()
                except Exception:
                    pass

            with _jobs_lock:
                _jobs[jid]['status'] = 'done'
                _jobs[jid]['result'] = {
                    'success': True,
                    'detections': detections,
                    'total_mangoes': len(detections)
                }
        except Exception as e:
            cleanup_file(img_path)
            print(f"[INFERENCE ERROR] {e}")
            with _jobs_lock:
                _jobs[jid]['status'] = 'error'
                _jobs[jid]['result'] = {'error': f'Prediction failed: {str(e)}'}
        finally:
            _cleanup_old_jobs()

    t = threading.Thread(target=_run_inference, args=(job_id, image_path), daemon=True)
    t.start()

    # Langsung balas dalam < 1 detik — tidak ada timeout Cloudflare
    return jsonify({
        'job_id': job_id,
        'status': 'processing',
        'message': 'Gambar diterima, sedang diproses. Polling /result/<job_id> setiap 3 detik.'
    }), 202


@app.route('/result/<job_id>', methods=['GET'])
def get_result(job_id):
    """Cek status job. Kembalikan hasil jika sudah selesai."""
    with _jobs_lock:
        job = _jobs.get(job_id)

    if job is None:
        return jsonify({'error': 'Job tidak ditemukan atau sudah kedaluwarsa'}), 404

    if job['status'] == 'processing':
        return jsonify({'job_id': job_id, 'status': 'processing'}), 202

    if job['status'] == 'error':
        # Hapus job setelah dibaca
        with _jobs_lock:
            _jobs.pop(job_id, None)
        return jsonify(job['result']), 500

    # status == 'done'
    result = job['result']
    with _jobs_lock:
        _jobs.pop(job_id, None)  # Bersihkan setelah dibaca
    return jsonify(result), 200

@app.route('/predict-compare', methods=['POST'])
def predict_compare():
    """
    Endpoint untuk membandingkan hasil prediksi dengan dan tanpa DIoU-NMS.
    Dioptimasi dengan downscale 480px & imgsz=320 agar 4x-5x lebih cepat.
    """
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500

    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    image_file = request.files['image']
    
    os.makedirs(TEMP_DIR, exist_ok=True)
    image_path = os.path.join(TEMP_DIR, f"compare_{uuid.uuid4().hex[:8]}.jpg")
    image_file.save(image_path)

    # Otomatis downscale gambar ke max 480px agar inferensi cepat di CPU
    try:
        img_mat = cv2.imread(image_path)
        if img_mat is not None:
            h, w = img_mat.shape[:2]
            if max(h, w) > 480:
                scale = 480.0 / max(h, w)
                new_w, new_h = int(w * scale), int(h * scale)
                img_mat = cv2.resize(img_mat, (new_w, new_h), interpolation=cv2.INTER_AREA)
                cv2.imwrite(image_path, img_mat)
    except Exception as img_err:
        print(f"[COMPARE RESIZE WARNING] {img_err}")

    try:
        with torch.no_grad():
            # 1. Prediksi dengan DIoU-NMS
            detections_diou = process_image(image_path)
            
            # 2. Prediksi dengan NMS default (kunci imgsz=320 dan max_det=20)
            default_results = model.predict(image_path, nms=True, conf=0.25, imgsz=320, max_det=20)
            detections_default = []
            
            for r in default_results:
                boxes = r.boxes
                if boxes is None:
                    continue

                for box in boxes:
                    x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                    xmin, ymin, xmax, ymax = int(x1), int(y1), int(x2), int(y2)
                    conf = float(box.conf[0].cpu().item())
                    cls = int(box.cls[0].cpu().item())
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
                    detections_default.append(detection)
        
        cleanup_file(image_path)
        
        return jsonify({
            "success": True,
            "diou_nms": {
                "detections": detections_diou,
                "total_mangoes": len(detections_diou)
            },
            "default_nms": {
                "detections": detections_default,
                "total_mangoes": len(detections_default)
            }
        })
    except Exception as e:
        cleanup_file(image_path)
        return jsonify({'error': f'Comparison failed: {str(e)}'}), 500

@app.route('/predict-live', methods=['POST'])
def predict_live():
    """
    Endpoint ultra-cepat khusus Live Camera Frame:
    - Tidak simpan riwayat ke DB Neon (menghilangkan delay 300-500ms)
    - Downscale ke max 320px
    - YOLO imgsz=256 dengan max_det=10
    - Respon langsung dalam <300ms
    """
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500

    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    image_file = request.files['image']
    os.makedirs(TEMP_DIR, exist_ok=True)
    live_path = os.path.join(TEMP_DIR, f"live_{uuid.uuid4().hex[:6]}.jpg")
    image_file.save(live_path)

    try:
        # Downscale ke 320px
        try:
            img_mat = cv2.imread(live_path)
            if img_mat is not None:
                h, w = img_mat.shape[:2]
                if max(h, w) > 320:
                    scale = 320.0 / max(h, w)
                    img_mat = cv2.resize(img_mat, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
                    cv2.imwrite(live_path, img_mat)
        except Exception:
            pass

        with torch.no_grad():
            results = model.predict(live_path, nms=True, conf=0.35, imgsz=256, max_det=10)
            detections = []
            for r in results:
                if r.boxes is None:
                    continue
                for box in r.boxes:
                    x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                    conf = float(box.conf[0].cpu().item())
                    cls = int(box.cls[0].cpu().item())
                    label = model.names[cls]
                    det = {
                        "ripeness_level": label,
                        "confidence": conf,
                        "bounding_box": {
                            "xmin": int(x1),
                            "ymin": int(y1),
                            "xmax": int(x2),
                            "ymax": int(y2)
                        }
                    }
                    det["grade"] = assign_grade(det)
                    detections.append(det)

        cleanup_file(live_path)
        return jsonify({
            "success": True,
            "detections": detections,
            "total_mangoes": len(detections)
        })
    except Exception as e:
        cleanup_file(live_path)
        return jsonify({'error': f'Live prediction error: {str(e)}'}), 500
    
@app.route('/summary', methods=['GET'])
@app.route('/yearly-summary', methods=['GET'])
def yearly_summary():
    """
    Endpoint untuk mendapatkan ringkasan riwayat deteksi.
    Mendukung filter harian (?date=YYYY-MM-DD) maupun tahunan (?year=YYYY).
    """
    try:
        date_str = request.args.get('date')
        year_param = request.args.get('year')

        # Default otomatis: jika tidak ada parameter, langsung ambil data hari ini!
        if not date_str and not year_param:
            date_str = datetime.now().strftime('%Y-%m-%d')

        if date_str:
            try:
                target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            except ValueError:
                return jsonify({'error': 'Format tanggal salah, gunakan YYYY-MM-DD'}), 400

            start_date = datetime.combine(target_date, datetime.min.time())
            end_date = datetime.combine(target_date, datetime.max.time())

            # Query data harian
            sessions = History.query.filter(
                History.detected_at >= start_date,
                History.detected_at <= end_date
            ).all()

            total_sessions = len(sessions)
            total_mangoes = sum((s.total_mangoes or 0) for s in sessions)

            # Query distribusi grade
            grade_stats = db.session.query(
                Detection.grade,
                func.count(Detection.id).label('count')
            ).join(History, Detection.history_id == History.id).filter(
                History.detected_at >= start_date,
                History.detected_at <= end_date
            ).group_by(Detection.grade).all()

            # Query distribusi kematangan
            ripeness_stats = db.session.query(
                Detection.ripeness_level,
                func.count(Detection.id).label('count')
            ).join(History, Detection.history_id == History.id).filter(
                History.detected_at >= start_date,
                History.detected_at <= end_date
            ).group_by(Detection.ripeness_level).all()

            # Query per jam untuk hari tersebut
            hourly_stats = db.session.query(
                extract('hour', History.detected_at).label('hour'),
                func.count(History.id).label('total_sessions'),
                func.sum(History.total_mangoes).label('total_mangoes')
            ).filter(
                History.detected_at >= start_date,
                History.detected_at <= end_date
            ).group_by(extract('hour', History.detected_at)).all()

            hourly_data = []
            for hour, s_cnt, m_cnt in hourly_stats:
                h_int = int(hour)
                hourly_data.append({
                    'hour': h_int,
                    'time_label': f"{h_int:02d}:00 - {h_int+1:02d}:00",
                    'total_sessions': s_cnt or 0,
                    'total_mangoes': m_cnt or 0
                })
            hourly_data.sort(key=lambda x: x['hour'])

            month_names = [
                '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
                'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
            ]
            formatted_date_id = f"{target_date.day} {month_names[target_date.month]} {target_date.year}"

            return jsonify({
                'success': True,
                'filter_type': 'daily',
                'date': date_str,
                'date_formatted': formatted_date_id,
                'total_sessions': total_sessions,
                'total_mangoes': total_mangoes,
                'grade_distribution': {grade: count for grade, count in grade_stats if grade},
                'ripeness_distribution': {ripeness: count for ripeness, count in ripeness_stats if ripeness},
                'breakdown': hourly_data,
                'breakdown_title': 'Rangkuman Jam Deteksi Hari Ini'
            })

        # Jika tidak menyertakan date, gunakan filter tahunan (default: tahun berjalan)
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
                'label': month_names[int(month)],
                'total_sessions': sessions or 0,
                'total_mangoes': mangoes or 0
            })
        
        # Sort berdasarkan bulan
        monthly_data.sort(key=lambda x: x['month'])
        
        return jsonify({
            'success': True,
            'filter_type': 'yearly',
            'year': year,
            'monthly_breakdown': monthly_data,
            'breakdown': monthly_data,
            'breakdown_title': 'Rangkuman Bulanan',
            'grade_distribution': {grade: count for grade, count in grade_stats if grade},
            'ripeness_distribution': {ripeness: count for ripeness, count in ripeness_stats if ripeness},
            'total_sessions': sum(item['total_sessions'] for item in monthly_data),
            'total_mangoes': sum(item['total_mangoes'] for item in monthly_data)
        })
        
    except Exception as e:
        return jsonify({'error': f'Failed to generate summary: {str(e)}'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None,
        'model_type': 'yolov8',
        'model_file': MODEL_PATH,
        'nms_type': 'DIoU-NMS'
    })

if __name__ == '__main__':
    os.makedirs(TEMP_DIR, exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=True)