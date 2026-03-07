# Full-Stack Python App (Flask + FastAPI + MySQL)

A sample full-stack application with a **Flask** frontend and **FastAPI** backend, ready for Docker and Kubernetes deployment.

## Architecture

| Component | Tech | Port | Description |
|-----------|------|------|-------------|
| **Frontend** | Flask + Jinja2 | 5000 | Displays backend health, readiness, and Docker image version |
| **Backend** | FastAPI | 8000 | Health/readiness endpoints, connects to MySQL |
| **MySQL** | MySQL 8 | 3306 | Database (RDS or in-cluster) |

## Quick Start (Docker Compose)

```bash
# Copy env example
cp .env.example .env

# Start all services
docker compose up -d

# Frontend UI
open http://localhost:5000

# Backend API docs
open http://localhost:8000/docs
```

## Project Structure

```
project-root/
├── app/
│   ├── frontend/
│   │   ├── app.py              # Flask app
│   │   ├── templates/
│   │   │   └── index.html      # Jinja2 template
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── backend/
│       ├── main.py             # FastAPI app
│       ├── db.py               # MySQL connection pool
│       ├── requirements.txt
│       └── Dockerfile
├── k8s/
│   └── manifest/               # Kubernetes manifests
├── docker-compose.yml
├── .env.example
└── README.md
```

## Environment Variables

| Variable | Used By | Description |
|----------|---------|-------------|
| `DB_HOST` | Backend | MySQL host (e.g. RDS endpoint or `mysql` for in-cluster) |
| `DB_PORT` | Backend | MySQL port (default: 3306) |
| `DB_USER` | Backend | MySQL user |
| `DB_PASSWORD` | Backend | MySQL password |
| `DB_NAME` | Backend | Database name |
| `BACKEND_URL` | Frontend | Backend API URL (e.g. `http://backend:80` in K8s) |
| `DOCKER_IMAGE_VERSION` | Frontend | Version shown in UI (e.g. `v1.0.0`) |

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Basic health check → `{"status": "ok"}` |
| `GET /ready` | Readiness check (tests MySQL) → `{"status": "ready", "database": "connected"}` or `{"status": "not_ready", "database": "unreachable"}` |
| `GET /docs` | OpenAPI documentation |

## Kubernetes Deployment

See [k8s/README.md](k8s/README.md) for:

- Deploying backend, frontend, and optional in-cluster MySQL
- AWS RDS configuration
- Argo CD (GitOps) setup
- Ingress and path-based routing

## Build Images Locally

```bash
docker build -t backend:latest ./app/backend
docker build -t frontend:latest --build-arg DOCKER_IMAGE_VERSION=v1.0.0 ./app/frontend
```
