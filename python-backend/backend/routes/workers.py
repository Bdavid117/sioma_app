from flask import Blueprint, request, jsonify
from models import Worker
from extensions import db
import json

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

    # Guardar el encoding facial solo si viene provisto por el cliente (sin procesar imágenes)
    face_encoding_json = None
    if data.get('face_encoding') is not None:
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


@workers_bp.route('/workers/ext/<string:ext_worker_id>', methods=['PUT'])
def update_worker_by_ext_id(ext_worker_id: str):
    data = request.get_json() or {}
    worker = Worker.query.filter_by(worker_id=ext_worker_id).first()
    if not worker:
        return jsonify({'error': 'Trabajador no encontrado'}), 404

    # Actualizar campos básicos
    if 'name' in data:
        worker.name = data['name']
    if 'email' in data:
        worker.email = data['email']
    if 'phone' in data:
        worker.phone = data['phone']
    if 'face_encoding' in data:
        worker.face_encoding = json.dumps(data['face_encoding']) if data['face_encoding'] is not None else None

    db.session.commit()
    return jsonify(worker.to_dict())


@workers_bp.route('/workers/bulk_upsert', methods=['POST'])
def bulk_upsert_workers():
    payload = request.get_json() or {}
    items = payload.get('workers', [])
    if not isinstance(items, list) or not items:
        return jsonify({'error': 'No hay trabajadores para procesar'}), 400

    created = 0
    updated = 0
    errors = []

    for idx, item in enumerate(items):
        try:
            ext_id = item.get('worker_id')
            name = item.get('name')
            if not ext_id or not name:
                errors.append(f'Item {idx}: faltan worker_id o name')
                continue

            worker = Worker.query.filter_by(worker_id=ext_id).first()
            face_encoding_json = json.dumps(item.get('face_encoding')) if item.get('face_encoding') is not None else None

            if worker:
                # update
                worker.name = name
                worker.email = item.get('email')
                worker.phone = item.get('phone')
                if 'face_encoding' in item:
                    worker.face_encoding = face_encoding_json
                updated += 1
            else:
                # create
                worker = Worker(
                    worker_id=ext_id,
                    name=name,
                    email=item.get('email'),
                    phone=item.get('phone'),
                    face_encoding=face_encoding_json,
                )
                db.session.add(worker)
                created += 1
        except Exception as e:
            errors.append(f'Item {idx}: {str(e)}')

    db.session.commit()
    return jsonify({'success': True, 'created': created, 'updated': updated, 'errors': errors})
