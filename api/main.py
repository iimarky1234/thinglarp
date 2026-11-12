"""api/main.py: FastAPI Application Gateway."""

from contextlib import asynccontextmanager
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import init_db, close_db, is_db_connected
from config import settings
from mqtt_client import publisher
from routers import auth, mqtt, channels, devices, keys, data, admin

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] (%(name)s) %(message)s",
)
logger = logging.getLogger("api")

async def ensure_initial_admin() -> None:
    admin_user = (settings.initial_admin_username or "").strip()
    admin_pass = (settings.initial_admin_password or "").strip()

    if not admin_user or not admin_pass:
        return

    from database import db_pool
    from security import hash_user_password, verify_user_password

    if not db_pool:
        logger.warning("Database pool unavailable; skipping initial admin bootstrap.")
        return

    async with db_pool.acquire() as conn:
        existing = await conn.fetchrow(
            "SELECT id, username, password_hash, is_admin FROM app.users WHERE username = $1;",
            admin_user,
        )
        if existing:
            needs_update = False
            updates = []
            params = []
            idx = 1

            if not verify_user_password(existing["password_hash"], admin_pass):
                new_hash = hash_user_password(admin_pass)
                updates.append(f"password_hash = ${idx}")
                params.append(new_hash)
                idx += 1
                needs_update = True

            if not existing["is_admin"]:
                updates.append(f"is_admin = ${idx}")
                params.append(True)
                idx += 1
                needs_update = True

            if needs_update:
                params.append(existing["id"])
                sql = f"UPDATE app.users SET {', '.join(updates)} WHERE id = ${idx};"
                await conn.execute(sql, *params)
                logger.info(f"Updated initial admin account '{admin_user}' (is_admin=True, password synced).")
            else:
                logger.info(f"Initial admin account '{admin_user}' is verified and active (is_admin=True).")
        else:
            pwd_hash = hash_user_password(admin_pass)
            await conn.execute(
                """
                INSERT INTO app.users (username, password_hash, is_admin)
                VALUES ($1, $2, TRUE);
                """,
                admin_user,
                pwd_hash,
            )
            logger.info(f"Created initial admin user '{admin_user}' from .env configuration.")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing API services...")
    # 1. Connect to PostgreSQL
    try:
        await init_db()
    except Exception as e:
        logger.error(f"Failed to connect to database: {e}")

    # 2. Bootstrap initial admin account if configured in .env
    try:
        await ensure_initial_admin()
    except Exception as e:
        logger.error(f"Failed to bootstrap initial admin account: {e}")

    # 3. Connect internal MQTT publisher
    try:
        await publisher.connect()
    except Exception as e:
        logger.warning(f"MQTT publisher deferred connection: {e}")

    yield

    logger.info("Shutting down API services...")
    await publisher.disconnect()
    await close_db()
    logger.info("API shutdown complete.")

app = FastAPI(
    title="IoT Telemetry Platform API",
    version="1.0.0",
    description="ThingSpeak alternative supporting unlimited dynamic fields and high-frequency MQTT streams.",
    lifespan=lifespan,
)

# CORS Middleware (Allows Flutter Web and mobile clients)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router)
app.include_router(mqtt.router)
app.include_router(channels.router)
app.include_router(devices.router)
app.include_router(keys.router)
app.include_router(data.router)
app.include_router(admin.router)

@app.get("/health", tags=["Health"])
async def health_check():
    db_status = "connected" if is_db_connected() else "disconnected"
    return {
        "status": "ok",
        "database": db_status,
        "mqtt_publisher": "connected" if publisher._connected else "disconnected",
    }

@app.get("/", tags=["Health"])
async def root():
    return {
        "service": "IoT Telemetry API",
        "documentation": "/docs",
        "openapi": "/openapi.json",
    }
