"""api/routers/auth.py: User registration, login, token refresh, and profile."""

from datetime import datetime, timedelta, timezone
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, status
import asyncpg

from config import settings
from database import get_db
from schemas import (
    UserRegister,
    UserLogin,
    TokenResponse,
    RefreshTokenRequest,
    UserOut,
    SystemSettingsOut,
)
from security import (
    hash_user_password,
    verify_user_password,
    create_access_token,
    create_refresh_token,
    sha256_hash,
    get_current_user,
    CurrentUser,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.get("/config", response_model=SystemSettingsOut)
async def get_public_auth_config(db: Annotated[asyncpg.Connection, Depends(get_db)]):
    """Retrieve public authentication settings (e.g. whether registration is enabled)."""
    row = await db.fetchrow(
        "SELECT (value = 'true'::jsonb) AS registration_enabled FROM app.system_settings WHERE key = 'registration_enabled'"
    )
    reg_enabled = row["registration_enabled"] if row is not None else True
    return SystemSettingsOut(registration_enabled=reg_enabled)

@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def register(payload: UserRegister, db: Annotated[asyncpg.Connection, Depends(get_db)]):
    # Check if registration is enabled
    setting = await db.fetchrow(
        "SELECT (value = 'true'::jsonb) AS registration_enabled FROM app.system_settings WHERE key = 'registration_enabled'"
    )
    is_enabled = setting["registration_enabled"] if setting is not None else True
    if not is_enabled:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Public registration is currently disabled by system administrator",
        )

    # Check if username exists
    existing = await db.fetchrow("SELECT id FROM app.users WHERE username = $1", payload.username)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )

    pwd_hash = hash_user_password(payload.password)
    row = await db.fetchrow(
        """
        INSERT INTO app.users (username, password_hash)
        VALUES ($1, $2)
        RETURNING id, username, is_admin, created_at;
        """,
        payload.username,
        pwd_hash,
    )
    return UserOut(id=row["id"], username=row["username"], is_admin=row["is_admin"], created_at=row["created_at"])

@router.post("/login", response_model=TokenResponse)
async def login(payload: UserLogin, db: Annotated[asyncpg.Connection, Depends(get_db)]):
    user = await db.fetchrow(
        "SELECT id, username, password_hash, is_active FROM app.users WHERE username = $1",
        payload.username,
    )
    if not user or not user["is_active"] or not verify_user_password(user["password_hash"], payload.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    # Create tokens
    access_token = create_access_token(user["id"], user["username"])
    raw_refresh_token = create_refresh_token()
    refresh_hash = sha256_hash(raw_refresh_token)
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)

    await db.execute(
        """
        INSERT INTO app.refresh_tokens (user_id, token_hash, expires_at)
        VALUES ($1, $2, $3);
        """,
        user["id"],
        refresh_hash,
        expires_at,
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh_token,
        expires_in_minutes=settings.access_token_expire_minutes,
    )

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(payload: RefreshTokenRequest, db: Annotated[asyncpg.Connection, Depends(get_db)]):
    refresh_hash = sha256_hash(payload.refresh_token)
    row = await db.fetchrow(
        """
        SELECT r.id, r.user_id, r.expires_at, r.revoked_at, u.username, u.is_active
        FROM app.refresh_tokens r
        JOIN app.users u ON u.id = r.user_id
        WHERE r.token_hash = $1;
        """,
        refresh_hash,
    )

    if not row or row["revoked_at"] is not None or row["expires_at"] <= datetime.now(timezone.utc) or not row["is_active"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    # Issue new access token
    new_access_token = create_access_token(row["user_id"], row["username"])

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=payload.refresh_token,
        expires_in_minutes=settings.access_token_expire_minutes,
    )

@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(payload: RefreshTokenRequest, db: Annotated[asyncpg.Connection, Depends(get_db)]):
    refresh_hash = sha256_hash(payload.refresh_token)
    await db.execute(
        "UPDATE app.refresh_tokens SET revoked_at = now() WHERE token_hash = $1",
        refresh_hash,
    )

@router.get("/me", response_model=UserOut)
async def get_profile(
    current_user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
):
    row = await db.fetchrow("SELECT id, username, is_admin, created_at FROM app.users WHERE id = $1", current_user.id)
    return UserOut(id=row["id"], username=row["username"], is_admin=row["is_admin"], created_at=row["created_at"])
