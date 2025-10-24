from flask import Blueprint, request, jsonify
from models import Worker
from extensions import db
import json
from services.face_service import encode_face_from_base64

workers_bp = Blueprint('workers', __name__)


@workers_bp.route('/workers', methods=['GET'])
def get_workers():
    workers = Worker.query.all()
    return jsonify([w.to_dict() for w in workers])


@workers_bp.route('/workers/<int:worker_id>', methods=['GET'])
def get_worker(worker_id):
    worker = Worker.query.get_or_404(worker_id)
    return jsonify(worker.to_dict())


@workers_bp.route('/workers', methods=['POST'])
def create_worker():
    data = request.get_json()
    if not data.get('worker_id') or not data.get('name'):
        return jsonify({'error': 'Faltan datos requeridos'}), 400

    existing = Worker.query.filter_by(worker_id=data['worker_id']).first()
    if existing:
        return jsonify({'error': 'Trabajador ya existe'}), 400

    # Determinar y almacenar el encoding facial si viene la imagen base64
    face_encoding_json = None
    if data.get('face_image_base64'):
        try:
            encoding = encode_face_from_base64(data['face_image_base64'])
            face_encoding_json = json.dumps(encoding)
        except ValueError as e:
            return jsonify({'error': str(e)}), 400
    elif data.get('face_encoding') is not None:
        # Permitir enviar el encoding ya calculado
        face_encoding_json = json.dumps(data.get('face_encoding'))

    worker = Worker(
        worker_id=data['worker_id'],
        name=data['name'],
        email=data.get('email'),
        phone=data.get('phone'),
        face_encoding=face_encoding_json,
    )

    db.session.add(worker)
    db.session.commit()
    return jsonify(worker.to_dict()), 201
