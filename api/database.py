"""api/database.py: Database connection pooling and FastAPI dependency."""

from typing import AsyncGenerator
import asyncpg
import logging
from config import settings

logger = logging.getLogger("api.database")

db_pool: asyncpg.Pool | None = None

async def init_db() -> asyncpg.Pool:
    global db_pool
    if db_pool is None:
        db_pool = await asyncpg.create_pool(
            host=settings.db_host,
            port=settings.db_port,
            database=settings.db_name,
            user=settings.db_user,
            password=settings.db_password,
            min_size=settings.db_min_connections,
            max_size=settings.db_max_connections,
        )
        logger.info(f"Database pool established for {settings.db_user}@{settings.db_host}:{settings.db_port}")
    return db_pool

async def close_db() -> None:
    global db_pool
    if db_pool:
        await db_pool.close()
        db_pool = None
        logger.info("Database pool closed.")

def is_db_connected() -> bool:
    return db_pool is not None

async def get_db() -> AsyncGenerator[asyncpg.Connection, None]:
    global db_pool
    if db_pool is None:
        raise RuntimeError("Database pool is not initialized.")
    async with db_pool.acquire() as connection:
        yield connection
