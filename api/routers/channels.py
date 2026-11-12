"""api/routers/channels.py: Channel and field registry management."""

from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
import asyncpg

from database import get_db
from schemas import ChannelCreate, ChannelUpdate, ChannelOut, FieldOut, FieldUpdate
from security import get_current_user, CurrentUser

router = APIRouter(prefix="/channels", tags=["Channels"])

async def verify_channel_ownership(channel_id: int, user_id: int, db: asyncpg.Connection) -> dict:
    row = await db.fetchrow("SELECT * FROM app.channels WHERE id = $1", channel_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Channel not found")
    if row["owner_id"] != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not channel owner")
    return dict(row)

@router.get("", response_model=list[ChannelOut])
async def list_channels(
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    rows = await db.fetch(
        """
        SELECT id, owner_id, name, description, is_public, max_fields, created_at
        FROM app.channels
        WHERE owner_id = $1 OR is_public = true
        ORDER BY created_at DESC;
        """,
        current_user.id,
    )
    return [ChannelOut(**dict(r)) for r in rows]

@router.post("", response_model=ChannelOut, status_code=status.HTTP_201_CREATED)
async def create_channel(
    payload: ChannelCreate,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    row = await db.fetchrow(
        """
        INSERT INTO app.channels (owner_id, name, description, is_public)
        VALUES ($1, $2, $3, $4)
        RETURNING id, owner_id, name, description, is_public, max_fields, created_at;
        """,
        current_user.id,
        payload.name,
        payload.description,
        payload.is_public,
    )
    return ChannelOut(**dict(row))

@router.get("/{channel_id}", response_model=ChannelOut)
async def get_channel(
    channel_id: int,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    row = await db.fetchrow("SELECT * FROM app.channels WHERE id = $1", channel_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Channel not found")
    if row["owner_id"] != current_user.id and not row["is_public"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
    return ChannelOut(**dict(row))

@router.patch("/{channel_id}", response_model=ChannelOut)
async def update_channel(
    channel_id: int,
    payload: ChannelUpdate,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    channel = await verify_channel_ownership(channel_id, current_user.id, db)

    name = payload.name if payload.name is not None else channel["name"]
    description = payload.description if payload.description is not None else channel["description"]
    is_public = payload.is_public if payload.is_public is not None else channel["is_public"]

    row = await db.fetchrow(
        """
        UPDATE app.channels
        SET name = $1, description = $2, is_public = $3
        WHERE id = $4
        RETURNING id, owner_id, name, description, is_public, max_fields, created_at;
        """,
        name,
        description,
        is_public,
        channel_id,
    )
    return ChannelOut(**dict(row))

@router.delete("/{channel_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_channel(
    channel_id: int,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)
    # Explicitly clear telemetry data before deleting channel metadata
    async with db.transaction():
        await db.execute("DELETE FROM telemetry.points WHERE channel_id = $1", channel_id)
        await db.execute("DELETE FROM telemetry.messages WHERE channel_id = $1", channel_id)
        await db.execute("DELETE FROM app.channels WHERE id = $1", channel_id)

@router.get("/{channel_id}/fields", response_model=list[FieldOut])
async def list_channel_fields(
    channel_id: int,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    channel = await db.fetchrow("SELECT owner_id, is_public FROM app.channels WHERE id = $1", channel_id)
    if not channel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Channel not found")
    if channel["owner_id"] != current_user.id and not channel["is_public"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    rows = await db.fetch(
        """
        SELECT id, channel_id, key, label, unit, value_type, first_seen_at
        FROM app.channel_fields
        WHERE channel_id = $1
        ORDER BY id ASC;
        """,
        channel_id,
    )
    return [FieldOut(**dict(r)) for r in rows]

@router.patch("/{channel_id}/fields/{field_id}", response_model=FieldOut)
async def update_channel_field(
    channel_id: int,
    field_id: int,
    payload: FieldUpdate,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)

    field = await db.fetchrow(
        "SELECT * FROM app.channel_fields WHERE id = $1 AND channel_id = $2",
        field_id,
        channel_id,
    )
    if not field:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Field not found")

    label = payload.label if payload.label is not None else field["label"]
    unit = payload.unit if payload.unit is not None else field["unit"]

    row = await db.fetchrow(
        """
        UPDATE app.channel_fields
        SET label = $1, unit = $2
        WHERE id = $3 AND channel_id = $4
        RETURNING id, channel_id, key, label, unit, value_type, first_seen_at;
        """,
        label,
        unit,
        field_id,
        channel_id,
    )
    return FieldOut(**dict(row))
