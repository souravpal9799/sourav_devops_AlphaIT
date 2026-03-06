"""
Flask frontend that displays backend health, readiness, and Docker image version.
Calls backend /health and /ready endpoints.
"""
import os
import logging
from flask import Flask, render_template
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Backend URL - from env for K8s (backend service name) or localhost for dev
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")


def fetch_backend_health() -> tuple[str, str]:
    """Call backend /health, return (status_text, status_class)."""
    try:
        r = requests.get(f"{BACKEND_URL}/health", timeout=5)
        r.raise_for_status()
        data = r.json()
        return "OK" if data.get("status") == "ok" else "UNKNOWN", "ok"
    except Exception as e:
        logger.warning("Backend health check failed: %s", e)
        return "ERROR", "error"


def fetch_backend_ready() -> tuple[str, str]:
    """Call backend /ready, return (status_text, status_class)."""
    try:
        r = requests.get(f"{BACKEND_URL}/ready", timeout=5)
        r.raise_for_status()
        data = r.json()
        if data.get("status") == "ready":
            return "YES", "ok"
        return "NO", "error"
    except Exception as e:
        logger.warning("Backend readiness check failed: %s", e)
        return "NO", "error"


@app.route("/")
def index():
    """Homepage: backend health, readiness, and Docker image version."""
    health_status, health_class = fetch_backend_health()
    ready_status, ready_class = fetch_backend_ready()
    docker_version = os.getenv("DOCKER_IMAGE_VERSION", "unknown")

    return render_template(
        "index.html",
        backend_health=health_status,
        backend_health_class=health_class,
        backend_ready=ready_status,
        backend_ready_class=ready_class,
        docker_image_version=docker_version,
    )


@app.route("/health")
def health():
    """Frontend health endpoint for probes."""
    return {"status": "ok"}
