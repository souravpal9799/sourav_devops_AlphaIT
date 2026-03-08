
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import declarative_base, sessionmaker
from .config import settings


# We now rely exclusively on environment variables injected via Kubernetes Secret
db_config = {
    "user": settings.DB_USER or "admin",
    "password": settings.DB_PASSWORD or "password",
    "host": settings.DB_HOST or "localhost",
    "port": settings.DB_PORT or 3306,
    "name": settings.DB_NAME or "demo_db",
}

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
        print("✅ DB connection successful.")
    except sqlalchemy.exc.OperationalError as e:
        print(f"❌ DB connection failed. OperationalError: {e}")
    except Exception as e:
        print(f"❌ DB initialization failed: {e}")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
