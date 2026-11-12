"""api/routers/admin.py: Administrator user management and platform statistics."""

from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
import asyncpg

from database import get_db
from schemas import AdminUserOut, AdminUserCreate, AdminUserUpdate, AdminStats
from security import require_admin, hash_user_password, CurrentUser

router = APIRouter(prefix="/admin", tags=["Administration"])


@router.get("/users", response_model=list[AdminUserOut])
async def list_users(
    admin: Annotated[CurrentUser, Depends(require_admin)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    """List all registered users with channel and device counts."""
    rows = await db.fetch(
        """
        SELECT 
            u.id, 
            u.username, 
            u.is_active, 
            u.is_admin, 
            u.created_at,
            COUNT(DISTINCT c.id) AS channel_count,
            COUNT(DISTINCT d.id) AS device_count
        FROM app.users u
        LEFT JOIN app.channels c ON c.owner_id = u.id
        LEFT JOIN app.devices d ON d.channel_id = c.id
        GROUP BY u.id, u.username, u.is_active, u.is_admin, u.created_at
        ORDER BY u.id ASC;
        """
    )
    return [
        AdminUserOut(
            id=r["id"],
            username=r["username"],
            is_active=r["is_active"],
            is_admin=r["is_admin"],
            created_at=r["created_at"],
            channel_count=r["channel_count"],
            device_count=r["device_count"],
        )
        for r in rows
    ]


@router.post("/users", response_model=AdminUserOut, status_code=status.HTTP_201_CREATED)
async def create_user_by_admin(
    payload: AdminUserCreate,
    admin: Annotated[CurrentUser, Depends(require_admin)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    """Admin endpoint to create a user account directly."""
    existing = await db.fetchrow("SELECT id FROM app.users WHERE username = $1", payload.username)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )

    pwd_hash = hash_user_password(payload.password)
    row = await db.fetchrow(
        """
        INSERT INTO app.users (username, password_hash, is_admin)
        VALUES ($1, $2, $3)
        RETURNING id, username, is_active, is_admin, created_at;
        """,
        payload.username,
        pwd_hash,
        payload.is_admin,
    )
    return AdminUserOut(
        id=row["id"],
        username=row["username"],
        is_active=row["is_active"],
        is_admin=row["is_admin"],
        created_at=row["created_at"],
        channel_count=0,
        device_count=0,
    )


@router.patch("/users/{user_id}", response_model=AdminUserOut)
async def update_user(
    user_id: int,
    payload: AdminUserUpdate,
    admin: Annotated[CurrentUser, Depends(require_admin)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    """Update active status, admin role, or reset password for a user."""
    user = await db.fetchrow(
        "SELECT id, username, is_active, is_admin, created_at FROM app.users WHERE id = $1",
        user_id,
    )
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # Prevent admin from deactivating or revoking their own admin role
    if user_id == admin.id:
        if payload.is_active is False:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You cannot deactivate your own administrative account",
            )
        if payload.is_admin is False:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You cannot revoke your own administrator role",
            )

    updates = []
    values = [user_id]
    idx = 2

    if payload.is_active is not None:
        updates.append(f"is_active = ${idx}")
        values.append(payload.is_active)
        idx += 1

    if payload.is_admin is not None:
        updates.append(f"is_admin = ${idx}")
        values.append(payload.is_admin)
        idx += 1

    if payload.password is not None:
        pwd_hash = hash_user_password(payload.password)
        updates.append(f"password_hash = ${idx}")
        values.append(pwd_hash)
        idx += 1

    if updates:
        sql = f"UPDATE app.users SET {', '.join(updates)} WHERE id = $1 RETURNING id, username, is_active, is_admin, created_at;"
        updated_row = await db.fetchrow(sql, *values)
    else:
        updated_row = user

    # Get counts
    counts = await db.fetchrow(
        """
        SELECT 
            COUNT(DISTINCT c.id) AS channel_count,
            COUNT(DISTINCT d.id) AS device_count
        FROM app.channels c
        LEFT JOIN app.devices d ON d.channel_id = c.id
        WHERE c.owner_id = $1;
        """,
        user_id,
    )

    return AdminUserOut(
        id=updated_row["id"],
        username=updated_row["username"],
        is_active=updated_row["is_active"],
        is_admin=updated_row["is_admin"],
        created_at=updated_row["created_at"],
        channel_count=counts["channel_count"] or 0,
        device_count=counts["device_count"] or 0,
    )


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: int,
    admin: Annotated[CurrentUser, Depends(require_admin)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    """Delete a user account and all owned channels and devices."""
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot delete your own administrative account",
        )

    res = await db.execute("DELETE FROM app.users WHERE id = $1", user_id)
    if res == "DELETE 0":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")


@router.get("/stats", response_model=AdminStats)
async def get_admin_stats(
    admin: Annotated[CurrentUser, Depends(require_admin)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    """Get system-wide metrics and stats."""
    row = await db.fetchrow(
        """
        SELECT
            (SELECT COUNT(*) FROM app.users) AS total_users,
            (SELECT COUNT(*) FROM app.users WHERE is_active = true) AS active_users,
            (SELECT COUNT(*) FROM app.channels) AS total_channels,
            (SELECT COUNT(*) FROM app.devices) AS total_devices,
            COALESCE((SELECT COUNT(*) FROM telemetry.points), 0) AS total_points;
        """
    )
    return AdminStats(
        total_users=row["total_users"],
        active_users=row["active_users"],
        total_channels=row["total_channels"],
        total_devices=row["total_devices"],
        total_points=row["total_points"],
    )
