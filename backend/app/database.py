import json
import boto3
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import declarative_base, sessionmaker
from .config import settings


def get_db_credentials():
    session = boto3.session.Session()
    client = session.client(
        service_name="secretsmanager",
        region_name=settings.AWS_REGION
    )
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=settings.SECRET_NAME
        )
        secret = json.loads(get_secret_value_response["SecretString"])
        return {
            "user": secret.get("DB_USER", settings.DB_USER),
            "password": secret.get("DB_PASSWORD", settings.DB_PASSWORD),
            "host": secret.get("DB_HOST", settings.DB_HOST),
            "port": secret.get("DB_PORT", settings.DB_PORT),
            "name": secret.get("DB_NAME", settings.DB_NAME),
        }
    except Exception as e:
        print(f"Error retrieving secrets, falling back to env vars: {e}")
        return {
            "user": settings.DB_USER or "admin",
            "password": settings.DB_PASSWORD or "password",
            "host": settings.DB_HOST or "localhost",
            "port": settings.DB_PORT or 3306,
            "name": settings.DB_NAME or "demo_db",
        }


db_config = get_db_credentials()
database_url = (
    f"mysql+pymysql://{db_config['user']}:{db_config['password']}"
    f"@{db_config['host']}:{db_config['port']}/{db_config['name']}"
)

engine = create_engine(database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Message(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True, index=True)
    content = Column(String(255), index=True)


def init_db():
    import sqlalchemy.exc

    try:
        print("Attempting to connect to the database...")
        Base.metadata.create_all(bind=engine)
        db = SessionLocal()
        if not db.query(Message).first():
            db.add(Message(content="Hello from RDS MySQL via FastAPI!"))
            db.commit()
        db.close()
        print("✅ Database connection successful and initialized properly.")
    except sqlalchemy.exc.OperationalError as e:
        print(f"❌ Database connection failed. OperationalError: {e}")
    except Exception as e:
        print(f"❌ Database initialization failed with an unexpected error: {e}")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
