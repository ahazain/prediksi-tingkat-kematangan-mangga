import os

class Config:
    database_url = os.getenv('DATABASE_URL', 'postgresql://postgres:12345@localhost:5432/deteksi_mangga')

    # Standarisasi URI:
    # - postgres:// → postgresql+psycopg2://  (Heroku-style shorthand)
    # - postgresql:// → postgresql+psycopg2:// (eksplisit pakai psycopg2)
    # Ini memaksa SQLAlchemy pakai psycopg2, bukan psycopg3, di Python 3.14
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql+psycopg2://", 1)
    elif database_url.startswith("postgresql://") and "+psycopg" not in database_url:
        database_url = database_url.replace("postgresql://", "postgresql+psycopg2://", 1)

    SQLALCHEMY_DATABASE_URI = database_url
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "pool_recycle": 300,
    }
