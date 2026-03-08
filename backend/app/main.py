from sqlalchemy.orm import Session
from sqlalchemy import text
from .database import get_db, Message, init_db
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI(title="demo API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    init_db()


@app.get("/health")
def health_check():
    version = os.getenv("BUILD_VERSION", "1.0.0")
    return {"status": "healthy", "version": version}


@app.get("/ready")
def readiness_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception:
        raise HTTPException(status_code=503, detail="Database not ready")


@app.get("/message")
def get_message(db: Session = Depends(get_db)):
    version = os.getenv("BUILD_VERSION", "1.0.0")
    msg = db.query(Message).first()
    if msg:
        return {"message": msg.content, "version": version}
    return {"message": "No message found", "version": version}
