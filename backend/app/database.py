import json
import boto3
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import declarative_base, sessionmaker
from .config import settings

def get_db_credentials():
    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager', region_name=settings.AWS_REGION)
    try:
        get_secret_value_response = client.get_secret_value(SecretId=settings.SECRET_NAME)
        secret = json.loads(get_secret_value_response['SecretString'])
        return secret['username'], secret['password']
    except Exception as e:
        print(f"Error retrieving secrets: {e}")
        return "admin", "password" # Fallback for local testing if needed

user, password = get_db_credentials()
database_url = f"mysql+pymysql://{user}:{password}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"

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
        Base.metadata.create_all(bind=engine)
        db = SessionLocal()
        if not db.query(Message).first():
            db.add(Message(content="Hello from RDS MySQL via FastAPI!"))
            db.commit()
        db.close()
    except sqlalchemy.exc.OperationalError as e:
        print(f"Warning: Could not connect to the database. {e}")
    except Exception as e:
        print(f"Warning: Database initialization failed. {e}")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
