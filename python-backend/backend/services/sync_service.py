from datetime import datetime
from typing import List, Tuple, Dict, Any


def sync_records(db, Worker, Attendance, records: List[Dict[str, Any]]) -> Tuple[int, List[str]]:
    """
    Procesa una lista de registros de asistencia y los guarda en la base de datos.
    Retorna (synced_count, errors).
    Cada record debe tener: worker_id (externo), timestamp (ISO), event_type, location (opcional)
    """
    synced_count = 0
    errors: List[str] = []

    for record in records:
        try:
            worker_ext_id = record.get('worker_id')
            if not worker_ext_id:
                errors.append("Registro sin worker_id")
                continue

            worker = Worker.query.filter_by(worker_id=worker_ext_id).first()
            if not worker:
                errors.append(f"Trabajador {worker_ext_id} no encontrado")
                continue

            try:
                ts = datetime.fromisoformat(record['timestamp'])
            except Exception:
                errors.append(f"Timestamp inválido para worker {worker_ext_id}")
                continue

            attendance = Attendance(
                worker_id=worker.id,
                timestamp=ts,
                event_type=record.get('event_type'),
                location=record.get('location'),
                synced_at=datetime.utcnow(),
            )

            db.session.add(attendance)
            synced_count += 1
        except Exception as e:
            errors.append(str(e))

    db.session.commit()
    return synced_count, errors
