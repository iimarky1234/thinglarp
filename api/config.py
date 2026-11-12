"""api/config.py: Application configuration and settings."""

import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Database Settings
    db_host: str = os.getenv("DB_HOST", "timescaledb")
    db_port: int = int(os.getenv("DB_PORT", "5432"))
    db_name: str = os.getenv("DB_NAME", "iot")
    db_user: str = os.getenv("DB_USER", "iot_api")
    db_password: str = os.getenv("DB_PASSWORD", "iot_api_secret")
    db_min_connections: int = int(os.getenv("DB_MIN_CONNECTIONS", "2"))
    db_max_connections: int = int(os.getenv("DB_MAX_CONNECTIONS", "10"))

    # MQTT Internal Publisher Settings
    mqtt_host: str = os.getenv("MQTT_HOST", "mosquitto")
    mqtt_port: int = int(os.getenv("MQTT_PORT", "1883"))
    mqtt_user: str = os.getenv("MQTT_USER", "svc_api")
    mqtt_password: str = os.getenv("MQTT_PASSWORD", "api_mqtt_secret")
    mqtt_client_id: str = os.getenv("MQTT_CLIENT_ID", "iot_api_publisher")

    # Security Settings
    jwt_secret: str = os.getenv("JWT_SECRET", "super_secret_random_jwt_key_32_chars_min")
    jwt_algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
    access_token_expire_minutes: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
    refresh_token_expire_days: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))
    mqtt_session_expire_hours: int = int(os.getenv("MQTT_SESSION_EXPIRE_HOURS", "24"))

settings = Settings()
