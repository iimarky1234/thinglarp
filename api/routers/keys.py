"""api/routers/keys.py: ThingSpeak-style HTTP API Key management."""

import secrets
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
import asyncpg

from database import get_db
from schemas import ApiKeyCreate, ApiKeyCreatedOut, ApiKeyOut
from security import get_current_user, CurrentUser, sha256_hash
from routers.channels import verify_channel_ownership

router = APIRouter(prefix="/channels/{channel_id}/keys", tags=["API Keys"])

@router.get("", response_model=list[ApiKeyOut])
async def list_api_keys(
    channel_id: int,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)
    rows = await db.fetch(
        """
        SELECT id, channel_id, prefix, scope, created_at, last_used_at
        FROM app.api_keys
        WHERE channel_id = $1 AND revoked_at IS NULL
        ORDER BY created_at DESC;
        """,
        channel_id,
    )
    return [ApiKeyOut(**dict(r)) for r in rows]

@router.post("", response_model=ApiKeyCreatedOut, status_code=status.HTTP_201_CREATED)
async def create_api_key(
    channel_id: int,
    payload: ApiKeyCreate,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)

    raw_key = secrets.token_urlsafe(32)
    prefix = raw_key[:8]
    key_hash = sha256_hash(raw_key)

    row = await db.fetchrow(
        """
        INSERT INTO app.api_keys (channel_id, prefix, key_hash, scope)
        VALUES ($1, $2, $3, $4)
        RETURNING id, channel_id, prefix, scope, created_at;
        """,
        channel_id,
        prefix,
        key_hash,
        payload.scope,
    )

    return ApiKeyCreatedOut(
        id=row["id"],
        channel_id=row["channel_id"],
        prefix=row["prefix"],
        api_key=raw_key,
        scope=row["scope"],
        created_at=row["created_at"],
    )

@router.delete("/{key_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_api_key(
    channel_id: int,
    key_id: int,
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    await verify_channel_ownership(channel_id, current_user.id, db)
    result = await db.execute(
        "UPDATE app.api_keys SET revoked_at = now() WHERE id = $1 AND channel_id = $2",
        key_id,
        channel_id,
    )
    if result == "UPDATE 0":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="API key not found")
