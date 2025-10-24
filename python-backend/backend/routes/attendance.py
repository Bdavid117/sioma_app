from flask import Blueprint, request, jsonify
from models import Attendance, Worker
from extensions import db
from datetime import datetime
from services.sync_service import sync_records

attendance_bp = Blueprint('attendance', __name__)


@attendance_bp.route('/sync', methods=['POST'])
def sync_attendance():
    data = request.get_json()
    if not data or 'records' not in data:
        return jsonify({'error': 'No hay registros para sincronizar'}), 400

    synced_count, errors = sync_records(db, Worker, Attendance, data['records'])

    return jsonify({'success': True, 'synced': synced_count, 'errors': errors})


@attendance_bp.route('/attendance', methods=['GET'])
def get_attendance():
    worker_id = request.args.get('worker_id')
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')

    query = Attendance.query

    if worker_id:
        query = query.filter_by(worker_id=worker_id)

    if start_date:
        query = query.filter(Attendance.timestamp >= datetime.fromisoformat(start_date))

    if end_date:
        query = query.filter(Attendance.timestamp <= datetime.fromisoformat(end_date))

    records = query.order_by(Attendance.timestamp.desc()).all()
    return jsonify([r.to_dict() for r in records])
