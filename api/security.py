"""api/security.py: Authentication, hashing, JWT handling, and dependencies."""

from datetime import datetime, timedelta, timezone
import hashlib
import secrets
from typing import Annotated, Any
import bcrypt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import OAuth2PasswordBearer, APIKeyHeader
from jose import JWTError, jwt
import asyncpg

from config import settings
from database import get_db

ph = PasswordHasher()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

# -----------------------------------------------------------------------------
# Password Hashing
# -----------------------------------------------------------------------------
def hash_user_password(password: str) -> str:
    """Hash human account password using Argon2id."""
    return ph.hash(password)

def verify_user_password(hash_str: str, password: str) -> bool:
    """Verify human password with Argon2id."""
    try:
        return ph.verify(hash_str, password)
    except VerifyMismatchError:
        return False

def hash_mqtt_password(password: str) -> str:
    """Hash device or MQTT session password using Bcrypt (cost=10) for mosquitto-go-auth."""
    salt = bcrypt.gensalt(rounds=10)
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")

def sha256_hash(data: str) -> str:
    """Hash API keys and refresh tokens."""
    return hashlib.sha256(data.encode("utf-8")).hexdigest()

# -----------------------------------------------------------------------------
# JWT Tokens
# -----------------------------------------------------------------------------
def create_access_token(user_id: int, username: str) -> str:
    expires = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    to_encode = {
        "sub": str(user_id),
        "username": username,
        "exp": expires,
        "type": "access",
    }
    return jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algorithm)

def create_refresh_token() -> str:
    return secrets.token_urlsafe(48)

# -----------------------------------------------------------------------------
# FastAPI Current User Dependency
# -----------------------------------------------------------------------------
class CurrentUser:
    def __init__(self, id: int, username: str):
        self.id = id
        self.username = username

async def get_current_user(
    token: Annotated[str | None, Depends(oauth2_scheme)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
) -> CurrentUser:
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        user_id_str: str = payload.get("sub")
        token_type: str = payload.get("type")
        if user_id_str is None or token_type != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid access token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        user_id = int(user_id_str)
    except (JWTError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    row = await db.fetchrow(
        "SELECT id, username, is_active FROM app.users WHERE id = $1",
        user_id,
    )
    if not row or not row["is_active"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )

    return CurrentUser(id=row["id"], username=row["username"])

async def get_optional_current_user(
    token: Annotated[str | None, Depends(oauth2_scheme)],
    db: Annotated[asyncpg.Connection, Depends(get_db)],
) -> CurrentUser | None:
    if not token:
        return None
    try:
        return await get_current_user(token, db)
    except HTTPException:
        return None
