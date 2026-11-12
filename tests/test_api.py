"""tests/test_api.py: Unit tests for API security, schema validation, and routes."""

import sys
import os
import pytest
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import AsyncClient, ASGITransport

# Add api directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../api")))

from security import (
    hash_user_password,
    verify_user_password,
    hash_mqtt_password,
    sha256_hash,
    create_access_token,
    CurrentUser,
)
import bcrypt
from main import app
from database import get_db

# -----------------------------------------------------------------------------
# Security & Hashing Tests
# -----------------------------------------------------------------------------
def test_argon2_password_hashing():
    pwd = "secure_test_password_123"
    hashed = hash_user_password(pwd)
    assert hashed != pwd
    assert verify_user_password(hashed, pwd) is True
    assert verify_user_password(hashed, "wrong_password") is False

def test_bcrypt_mqtt_password_hashing():
    pwd = "device_secret_token_abc"
    hashed = hash_mqtt_password(pwd)
    assert bcrypt.checkpw(pwd.encode("utf-8"), hashed.encode("utf-8")) is True
    assert bcrypt.checkpw(b"wrong", hashed.encode("utf-8")) is False

def test_sha256_hashing():
    token = "random_api_key_string"
    h1 = sha256_hash(token)
    h2 = sha256_hash(token)
    assert h1 == h2
    assert len(h1) == 64

def test_jwt_access_token_generation():
    token = create_access_token(user_id=42, username="testuser")
    assert isinstance(token, str)
    assert len(token.split(".")) == 3


# -----------------------------------------------------------------------------
# FastAPI Route Tests
# -----------------------------------------------------------------------------
@pytest.fixture
def mock_db():
    db = AsyncMock()
    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.clear()

@pytest.mark.asyncio
async def test_health_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/health")
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "ok"
        assert "database" in data
        assert "mqtt_publisher" in data

@pytest.mark.asyncio
async def test_auth_register_validation(mock_db):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # Invalid username (contains space)
        res = await client.post("/auth/register", json={"username": "bad user", "password": "password123"})
        assert res.status_code == 422

@pytest.mark.asyncio
async def test_auth_register_success(mock_db):
    mock_db.fetchrow.side_effect = [
        {"registration_enabled": True},  # System settings check
        None,  # Check existing username -> not found
        {"id": 1, "username": "valid_user", "is_admin": False, "created_at": datetime.now(timezone.utc)},  # Insert returning
    ]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/auth/register", json={"username": "valid_user", "password": "password123"})
        assert res.status_code == 201
        data = res.json()
        assert data["id"] == 1
        assert data["username"] == "valid_user"
        assert data["is_admin"] is False

@pytest.mark.asyncio
async def test_auth_register_locked(mock_db):
    mock_db.fetchrow.side_effect = [
        {"registration_enabled": False},  # System settings check: registration disabled
    ]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/auth/register", json={"username": "new_user", "password": "password123"})
        assert res.status_code == 403
        data = res.json()
        assert "disabled" in data["detail"].lower()

@pytest.mark.asyncio
async def test_auth_config(mock_db):
    mock_db.fetchrow.side_effect = [
        {"registration_enabled": False},
    ]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/auth/config")
        assert res.status_code == 200
        data = res.json()
        assert data["registration_enabled"] is False

@pytest.mark.asyncio
async def test_channel_creation(mock_db):
    token = create_access_token(user_id=1, username="testuser")
    mock_db.fetchrow.side_effect = [
        {"id": 1, "username": "testuser", "is_active": True, "is_admin": False}, # Auth check
        {
            "id": 10,
            "owner_id": 1,
            "name": "Weather Station",
            "description": "Garden sensor",
            "is_public": False,
            "max_fields": 500,
            "created_at": datetime.now(timezone.utc),
        }, # Insert channel returning
    ]

    headers = {"Authorization": f"Bearer {token}"}
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post(
            "/channels",
            json={"name": "Weather Station", "description": "Garden sensor", "is_public": False},
            headers=headers,
        )
        assert res.status_code == 201
        data = res.json()
        assert data["id"] == 10
        assert data["name"] == "Weather Station"

@pytest.mark.asyncio
async def test_admin_settings_toggle(mock_db):
    admin_token = create_access_token(user_id=1, username="admin")
    mock_db.fetchrow.side_effect = [
        {"id": 1, "username": "admin", "is_active": True, "is_admin": True}, # Auth check
        {"registration_enabled": False}, # Return after update
    ]

    headers = {"Authorization": f"Bearer {admin_token}"}
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.patch(
            "/admin/settings",
            json={"registration_enabled": False},
            headers=headers,
        )
        assert res.status_code == 200
        assert res.json()["registration_enabled"] is False

