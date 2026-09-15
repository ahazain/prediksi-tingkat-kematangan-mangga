from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()

class History(db.Model):
    __tablename__ = 'histories'
    id = db.Column(db.Integer, primary_key=True)
    detected_at = db.Column(db.DateTime, default=datetime.utcnow)
    total_mangoes = db.Column(db.Integer)
    detections = db.relationship('Detection', backref='history', cascade="all, delete-orphan")

    def __init__(self, detected_at=None, total_mangoes=None, **kwargs):
        super().__init__(**kwargs)
        if detected_at is not None:
            self.detected_at = detected_at
        if total_mangoes is not None:
            self.total_mangoes = total_mangoes

class Detection(db.Model):
    __tablename__ = 'detections'
    id = db.Column(db.Integer, primary_key=True)
    history_id = db.Column(db.Integer, db.ForeignKey('histories.id'), nullable=False)
    confidence = db.Column(db.Float)
    grade = db.Column(db.String(10))
    ripeness_level = db.Column(db.String(20))
    # GANTI NAMA KOLOM INI:
    bbox_xmin = db.Column(db.Integer)  # dari xmin
    bbox_xmax = db.Column(db.Integer)  # dari xmax  
    bbox_ymin = db.Column(db.Integer)  # dari ymin
    bbox_ymax = db.Column(db.Integer)  # dari ymax

    def __init__(self, history_id=None, confidence=None, grade=None, ripeness_level=None,
                 bbox_xmin=None, bbox_xmax=None, bbox_ymin=None, bbox_ymax=None, **kwargs):
        super().__init__(**kwargs)
        if history_id is not None:
            self.history_id = history_id
        if confidence is not None:
            self.confidence = confidence
        if grade is not None:
            self.grade = grade
        if ripeness_level is not None:
            self.ripeness_level = ripeness_level
        if bbox_xmin is not None:
            self.bbox_xmin = bbox_xmin
        if bbox_xmax is not None:
            self.bbox_xmax = bbox_xmax
        if bbox_ymin is not None:
            self.bbox_ymin = bbox_ymin
        if bbox_ymax is not None:
            self.bbox_ymax = bbox_ymax