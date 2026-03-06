"""
FastAPI backend with MySQL connection.
Provides /health and /ready endpoints for container orchestration.
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from db import check_db_connection, close_pool, init_pool

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: init DB pool. Shutdown: close pool."""
    await init_pool()
    yield
    await close_pool()


app = FastAPI(title="Backend API", lifespan=lifespan)


@app.get("/health")
def health() -> dict:
    """Basic health check - always returns ok if the app is running."""
    return {"status": "ok"}


@app.get("/ready")
async def ready() -> dict:
    """
    Readiness check - verifies MySQL connectivity.
    Returns not_ready if database is unreachable.
    """
    db_ok = await check_db_connection()
    if db_ok:
        return {"status": "ready", "database": "connected"}
    return {"status": "not_ready", "database": "unreachable"}
