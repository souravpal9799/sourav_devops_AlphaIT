"""
MySQL database connection pool for FastAPI backend.
Configured via environment variables: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME.

Optional: load the DB_* values from AWS Secrets Manager at startup.
Set:
- AWS_SECRETSMANAGER_SECRET_ID (secret name or ARN)
- AWS_REGION (or AWS_DEFAULT_REGION)

Secret value should be a JSON object containing keys like:
DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
(or common variants: host, port, username/user, password, dbname/database/name)
"""
import os
import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator
import json
import asyncio

import aiomysql
import boto3

logger = logging.getLogger(__name__)

# Connection pool (created at startup)
_pool: aiomysql.Pool | None = None


def _get_env_db_config() -> dict:
    """Read database config from environment variables."""
    return {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "3306")),
        "user": os.getenv("DB_USER", "root"),
        "password": os.getenv("DB_PASSWORD", ""),
        "db": os.getenv("DB_NAME", "app"),
    }

def _coalesce(*values: str | None) -> str | None:
    for v in values:
        if v is not None and str(v).strip() != "":
            return str(v)
    return None


def _normalize_secret_db_config(secret_payload: dict) -> dict:
    """
    Normalize common secret JSON formats into our config shape:
    {host, port, user, password, db}
    """
    host = _coalesce(
        secret_payload.get("DB_HOST"),
        secret_payload.get("host"),
        secret_payload.get("hostname"),
        secret_payload.get("endpoint"),
    )
    port_raw = _coalesce(
        secret_payload.get("DB_PORT"),
        secret_payload.get("port"),
    )
    user = _coalesce(
        secret_payload.get("DB_USER"),
        secret_payload.get("user"),
        secret_payload.get("username"),
    )
    password = _coalesce(
        secret_payload.get("DB_PASSWORD"),
        secret_payload.get("password"),
    )
    db = _coalesce(
        secret_payload.get("DB_NAME"),
        secret_payload.get("db"),
        secret_payload.get("dbname"),
        secret_payload.get("database"),
        secret_payload.get("name"),
    )

    normalized = {}
    if host is not None:
        normalized["host"] = host
    if port_raw is not None:
        try:
            normalized["port"] = int(port_raw)
        except ValueError:
            logger.warning("Invalid DB port in Secrets Manager payload: %r", port_raw)
    if user is not None:
        normalized["user"] = user
    if password is not None:
        normalized["password"] = password
    if db is not None:
        normalized["db"] = db
    return normalized


def _fetch_aws_secret_sync(secret_id: str, region: str | None) -> dict:
    """
    Fetch secret from AWS Secrets Manager (sync).
    Uses ambient AWS credentials (IAM role, env vars, or AWS profile on the node).
    """
    client = boto3.client("secretsmanager", region_name=region)
    resp = client.get_secret_value(SecretId=secret_id)
    secret_string = resp.get("SecretString")
    if not secret_string:
        raise RuntimeError("SecretString is empty (binary secrets not supported here).")
    return json.loads(secret_string)


async def resolve_db_config() -> dict:
    """
    Resolve DB config.
    - If AWS_SECRETSMANAGER_SECRET_ID is set, load DB settings from Secrets Manager.
    - Always fall back to DB_* env vars for any missing values (dev/local).
    """
    env_config = _get_env_db_config()

    secret_id = os.getenv("AWS_SECRETSMANAGER_SECRET_ID")
    if not secret_id:
        return env_config

    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
    try:
        payload = await asyncio.to_thread(_fetch_aws_secret_sync, secret_id, region)
        secret_config = _normalize_secret_db_config(payload)
        merged = {**env_config, **secret_config}
        logger.info("Loaded DB config from AWS Secrets Manager (%s)", secret_id)
        return merged
    except Exception as e:
        logger.warning("Failed to load DB config from AWS Secrets Manager: %s", e)
        return env_config


async def init_pool() -> None:
    """Create connection pool at application startup."""
    global _pool
    config = await resolve_db_config()
    try:
        _pool = await aiomysql.create_pool(
            host=config["host"],
            port=config["port"],
            user=config["user"],
            password=config["password"],
            db=config["db"],
            minsize=1,
            maxsize=10,
            autocommit=True,
        )
        logger.info("MySQL connection pool initialized")
    except Exception as e:
        logger.warning("Failed to initialize MySQL pool: %s", e)
        _pool = None


async def close_pool() -> None:
    """Close connection pool at shutdown."""
    global _pool
    if _pool:
        _pool.close()
        await _pool.wait_closed()
        _pool = None
        logger.info("MySQL connection pool closed")


@asynccontextmanager
async def get_connection() -> AsyncGenerator[aiomysql.Connection, None]:
    """Acquire a connection from the pool."""
    if _pool is None:
        raise RuntimeError("Database pool not initialized")
    async with _pool.acquire() as conn:
        yield conn


async def check_db_connection() -> bool:
    """Execute SELECT 1 to verify database connectivity."""
    if _pool is None:
        return False
    try:
        async with get_connection() as conn:
            async with conn.cursor() as cur:
                await cur.execute("SELECT 1")
                await cur.fetchone()
        return True
    except Exception as e:
        logger.warning("Database health check failed: %s", e)
        return False
