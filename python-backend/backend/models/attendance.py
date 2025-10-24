from extensions import db
from datetime import datetime


class Attendance(db.Model):
    __tablename__ = 'attendance'

    id = db.Column(db.Integer, primary_key=True)
    worker_id = db.Column(db.Integer, db.ForeignKey('workers.id'), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    event_type = db.Column(db.String(10))
    location = db.Column(db.String(100))
    synced_at = db.Column(db.DateTime)

    def to_dict(self):
        return {
            'id': self.id,
            'worker_id': self.worker_id,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
            'event_type': self.event_type,
            'location': self.location,
            'synced_at': self.synced_at.isoformat() if self.synced_at else None
        }
