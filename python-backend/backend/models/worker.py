from extensions import db
from datetime import datetime


class Worker(db.Model):
    __tablename__ = 'workers'

    id = db.Column(db.Integer, primary_key=True)
    worker_id = db.Column(db.String(50), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100))
    phone = db.Column(db.String(20))
    face_encoding = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    attendance_records = db.relationship('Attendance', backref='worker', lazy=True)

    def to_dict(self):
        return {
            'id': self.id,
            'worker_id': self.worker_id,
            'name': self.name,
            'email': self.email,
            'phone': self.phone,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
