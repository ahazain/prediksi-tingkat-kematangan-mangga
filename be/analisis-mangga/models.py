from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()

class History(db.Model):
    __tablename__ = 'histories'
    id = db.Column(db.Integer, primary_key=True)
    detected_at = db.Column(db.DateTime, default=datetime.utcnow)
    total_mangoes = db.Column(db.Integer)
    detections = db.relationship('Detection', backref='history', cascade="all, delete-orphan")

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