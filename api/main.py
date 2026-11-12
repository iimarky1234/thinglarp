"""api/main.py: FastAPI Application Gateway."""

from contextlib import asynccontextmanager
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import init_db, close_db, is_db_connected
from mqtt_client import publisher
from routers import auth, mqtt, channels, devices, keys, data

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] (%(name)s) %(message)s",
)
logger = logging.getLogger("api")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing API services...")
    # 1. Connect to PostgreSQL
    try:
        await init_db()
    except Exception as e:
        logger.error(f"Failed to connect to database: {e}")

    # 2. Connect internal MQTT publisher
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
