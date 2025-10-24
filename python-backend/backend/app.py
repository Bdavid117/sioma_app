from flask import Flask, request, jsonify
from flask_cors import CORS
from extensions import db

app = Flask(__name__)
CORS(app)

# Configuración
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///database.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)

# Importar modelos y rutas (después de init_app para evitar circular imports)
from models import Worker, Attendance  # noqa: E402,F401
from routes import workers_bp, attendance_bp  # noqa: E402,F401

# Registrar blueprints
app.register_blueprint(workers_bp, url_prefix='/api')
app.register_blueprint(attendance_bp, url_prefix='/api')

@app.get("/health")
def health():
    return {"status": "ok"}

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)
