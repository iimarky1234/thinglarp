"""api/routers/devices.py: Hardware device provisioning and management."""

import secrets
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
import asyncpg

from database import get_db
from schemas import DeviceCreate, DeviceCreatedOut, DeviceOut, DeviceUpdate
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
        SELECT id, channel_id, name, mqtt_username, mqtt_password, scope, is_active, created_at
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
        INSERT INTO app.devices (channel_id, name, mqtt_username, mqtt_password, mqtt_password_hash, scope)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, channel_id, name, mqtt_username, mqtt_password, scope, is_active, created_at;
        """,
        channel_id,
        payload.name,
        mqtt_username,
        raw_password,
        password_hash,
        payload.scope,
    )

    return DeviceCreatedOut(
        id=row["id"],
        channel_id=row["channel_id"],
        name=row["name"],
        mqtt_username=row["mqtt_username"],
        mqtt_password=raw_password,
        scope=row["scope"],
        is_active=row["is_active"],
        created_at=row["created_at"],
    )

@router.patch("/{device_id}", response_model=DeviceOut)
async def update_device(
    channel_id: int,
    device_id: int,
    payload: DeviceUpdate,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)

    device = await db.fetchrow(
        "SELECT * FROM app.devices WHERE id = $1 AND channel_id = $2",
        device_id,
        channel_id,
    )
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")

    new_name = payload.name if payload.name is not None else device["name"]
    new_scope = payload.scope if payload.scope is not None else device["scope"]
    new_active = payload.is_active if payload.is_active is not None else device["is_active"]

    updated = await db.fetchrow(
        """
        UPDATE app.devices
        SET name = $1, scope = $2, is_active = $3
        WHERE id = $4 AND channel_id = $5
        RETURNING id, channel_id, name, mqtt_username, mqtt_password, scope, is_active, created_at;
        """,
        new_name,
        new_scope,
        new_active,
        device_id,
        channel_id,
    )
    return DeviceOut(**dict(updated))

@router.post("/{device_id}/reset-password", response_model=DeviceCreatedOut)
async def reset_device_password(
    channel_id: int,
    device_id: int,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)
    raw_password = secrets.token_urlsafe(24)
    password_hash = hash_mqtt_password(raw_password)

    updated = await db.fetchrow(
        """
        UPDATE app.devices
        SET mqtt_password = $1, mqtt_password_hash = $2
        WHERE id = $3 AND channel_id = $4
        RETURNING id, channel_id, name, mqtt_username, mqtt_password, scope, is_active, created_at;
        """,
        raw_password,
        password_hash,
        device_id,
        channel_id,
    )
    if not updated:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")

    return DeviceCreatedOut(
        id=updated["id"],
        channel_id=updated["channel_id"],
        name=updated["name"],
        mqtt_username=updated["mqtt_username"],
        mqtt_password=raw_password,
        scope=updated["scope"],
        is_active=updated["is_active"],
        created_at=updated["created_at"],
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
