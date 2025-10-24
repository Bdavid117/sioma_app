from flask_sqlalchemy import SQLAlchemy

# Single global SQLAlchemy instance to avoid circular imports
# Import as: from extensions import db

db = SQLAlchemy()
