"""api/routers/devices.py: Hardware device provisioning and management."""

import secrets
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
import asyncpg

from database import get_db
from schemas import DeviceCreate, DeviceCreatedOut, DeviceOut
from security import get_current_user, CurrentUser, hash_mqtt_password
from routers.channels import verify_channel_ownership

router = APIRouter(prefix="/channels/{channel_id}/devices", tags=["Devices"])

@router.get("", response_model=list[DeviceOut])
async def list_devices(
    channel_id: int,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)
    rows = await db.fetch(
        """
        SELECT id, channel_id, name, mqtt_username, is_active, created_at
        FROM app.devices
        WHERE channel_id = $1
        ORDER BY created_at DESC;
        """,
        channel_id,
    )
    return [DeviceOut(**dict(r)) for r in rows]

@router.post("", response_model=DeviceCreatedOut, status_code=status.HTTP_201_CREATED)
async def create_device(
    channel_id: int,
    payload: DeviceCreate,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)

    # Generate device credentials
    mqtt_username = f"d_{secrets.token_hex(8)}"
    raw_password = secrets.token_urlsafe(24)
    password_hash = hash_mqtt_password(raw_password)

    row = await db.fetchrow(
        """
        INSERT INTO app.devices (channel_id, name, mqtt_username, mqtt_password_hash)
        VALUES ($1, $2, $3, $4)
        RETURNING id, channel_id, name, mqtt_username, created_at;
        """,
        channel_id,
        payload.name,
        mqtt_username,
        password_hash,
    )

    return DeviceCreatedOut(
        id=row["id"],
        channel_id=row["channel_id"],
        name=row["name"],
        mqtt_username=row["mqtt_username"],
        mqtt_password=raw_password,
        created_at=row["created_at"],
    )

@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(
    channel_id: int,
    device_id: int,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)
    result = await db.execute(
        "DELETE FROM app.devices WHERE id = $1 AND channel_id = $2",
        device_id,
        channel_id,
    )
    if result == "DELETE 0":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")
