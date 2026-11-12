"""api/routers/mqtt.py: Issues short-lived MQTT credentials for Flutter app."""

import os
from datetime import datetime, timedelta, timezone
import secrets
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
import asyncpg

from config import settings
from database import get_db
from schemas import MqttSessionResponse
from security import get_current_user, CurrentUser, hash_mqtt_password

router = APIRouter(prefix="/mqtt", tags=["MQTT Sessions"])

@router.post("/session", response_model=MqttSessionResponse)
async def create_mqtt_session(
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    """
    Generate short-lived MQTT credentials for the Flutter application.
    The app uses these credentials to connect to Mosquitto (via TCP TLS 8883 or WebSocket 443/mqtt).
    """
    session_user = f"s_{secrets.token_hex(8)}"
    raw_password = secrets.token_urlsafe(24)
    password_hash = hash_mqtt_password(raw_password)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.mqtt_session_expire_hours)

    await db.execute(
        """
        INSERT INTO app.mqtt_sessions (username, user_id, password_hash, expires_at)
        VALUES ($1, $2, $3, $4);
        """,
        session_user,
        current_user.id,
        password_hash,
        expires_at,
    )

    mqtt_domain = os.getenv("MQTT_DOMAIN", "localhost")
    return MqttSessionResponse(
        username=session_user,
        password=raw_password,
        expires_at=expires_at,
        broker_ws_url=f"wss://{mqtt_domain}/mqtt",
        broker_tcp_url=f"mqtts://{mqtt_domain}:8883",
    )
