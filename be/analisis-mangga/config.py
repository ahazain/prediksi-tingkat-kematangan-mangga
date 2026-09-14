import os

class Config:
    database_url = os.getenv('DATABASE_URL', 'postgresql://postgres:12345@localhost:5432/deteksi_mangga')
    # Standarisasi URI postgres:// ke postgresql:// untuk SQLAlchemy
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    
    SQLALCHEMY_DATABASE_URI = database_url
    SQLALCHEMY_TRACK_MODIFICATIONS = False

