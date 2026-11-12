"""api/schemas.py: Pydantic request and response models."""

from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field

# -----------------------------------------------------------------------------
# Auth Schemas
# -----------------------------------------------------------------------------
class UserRegister(BaseModel):
    username: str = Field(..., min_length=3, max_length=32, pattern=r"^[a-zA-Z0-9_.-]+$")
    password: str = Field(..., min_length=6, max_length=128)

class UserLogin(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in_minutes: int

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class UserOut(BaseModel):
    id: int
    username: str
    is_admin: bool = False
    created_at: datetime

# -----------------------------------------------------------------------------
# Admin Schemas
# -----------------------------------------------------------------------------
class AdminUserOut(BaseModel):
    id: int
    username: str
    is_active: bool
    is_admin: bool
    created_at: datetime
    channel_count: int = 0
    device_count: int = 0

class AdminUserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=32, pattern=r"^[a-zA-Z0-9_.-]+$")
    password: str = Field(..., min_length=6, max_length=128)
    is_admin: bool = False

class AdminUserUpdate(BaseModel):
    is_active: bool | None = None
    is_admin: bool | None = None
    password: str | None = Field(None, min_length=6, max_length=128)

class AdminStats(BaseModel):
    total_users: int
    active_users: int
    total_channels: int
    total_devices: int
    total_points: int

# -----------------------------------------------------------------------------
# MQTT Session Schemas
# -----------------------------------------------------------------------------
class MqttSessionResponse(BaseModel):
    username: str
    password: str
    expires_at: datetime
    broker_ws_url: str | None = None
    broker_tcp_url: str | None = None

# -----------------------------------------------------------------------------
# Channel Schemas
# -----------------------------------------------------------------------------
class ChannelCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: str | None = Field(None, max_length=500)
    is_public: bool = False

class ChannelUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    description: str | None = Field(None, max_length=500)
    is_public: bool | None = None

class ChannelOut(BaseModel):
    id: int
    owner_id: int
    name: str
    description: str | None
    is_public: bool
    max_fields: int
    created_at: datetime

class FieldOut(BaseModel):
    id: int
    channel_id: int
    key: str
    label: str | None
    unit: str | None
    value_type: str
    first_seen_at: datetime

class FieldUpdate(BaseModel):
    label: str | None = Field(None, max_length=64)
    unit: str | None = Field(None, max_length=16)

# -----------------------------------------------------------------------------
# Device Schemas
# -----------------------------------------------------------------------------
class DeviceCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=64)

class DeviceCreatedOut(BaseModel):
    id: int
    channel_id: int
    name: str
    mqtt_username: str
    mqtt_password: str # Shown once during device creation
    created_at: datetime

class DeviceOut(BaseModel):
    id: int
    channel_id: int
    name: str
    mqtt_username: str
    is_active: bool
    created_at: datetime

# -----------------------------------------------------------------------------
# API Key Schemas
# -----------------------------------------------------------------------------
class ApiKeyCreate(BaseModel):
    scope: str = Field(..., pattern=r"^(read|write)$")

class ApiKeyCreatedOut(BaseModel):
    id: int
    channel_id: int
    prefix: str
    api_key: str # Shown once during creation
    scope: str
    created_at: datetime

class ApiKeyOut(BaseModel):
    id: int
    channel_id: int
    prefix: str
    scope: str
    created_at: datetime
    last_used_at: datetime | None

# -----------------------------------------------------------------------------
# Telemetry Schemas
# -----------------------------------------------------------------------------
class TelemetryPoint(BaseModel):
    time: datetime
    value: float
    min: float | None = None
    max: float | None = None

class ChannelTelemetryOut(BaseModel):
    channel_id: int
    resolution: str
    fields: dict[str, list[TelemetryPoint]]

class LatestTelemetryOut(BaseModel):
    channel_id: int
    timestamp: datetime | None
    fields: dict[str, Any]
