"""bridge/config.py: Bridge configuration and settings."""

import os
from dataclasses import dataclass

@dataclass(frozen=True)
class Settings:
    # Database Settings
    db_host: str = os.getenv("DB_HOST", "timescaledb")
    db_port: int = int(os.getenv("DB_PORT", "5432"))
    db_name: str = os.getenv("DB_NAME", "iot")
    db_user: str = os.getenv("DB_USER", "iot_bridge")
    db_password: str = os.getenv("DB_PASSWORD", "iot_bridge_secret")
    db_min_connections: int = int(os.getenv("DB_MIN_CONNECTIONS", "2"))
    db_max_connections: int = int(os.getenv("DB_MAX_CONNECTIONS", "10"))

    # MQTT Settings
    mqtt_host: str = os.getenv("MQTT_HOST", "mosquitto")
    mqtt_port: int = int(os.getenv("MQTT_PORT", "1883"))
    mqtt_user: str = os.getenv("MQTT_USER", "svc_bridge")
    mqtt_password: str = os.getenv("MQTT_PASSWORD", "bridge_mqtt_secret")
    mqtt_client_id: str = os.getenv("MQTT_CLIENT_ID", "iot_bridge_ingest")
    mqtt_topic: str = os.getenv("MQTT_TOPIC", "$share/ingest/channels/+/data")
    mqtt_topic_fallback: str = os.getenv("MQTT_TOPIC_FALLBACK", "channels/+/data")
    mqtt_clean_session: bool = os.getenv("MQTT_CLEAN_SESSION", "false").lower() == "true"

    # Batching & Performance Settings
    batch_size: int = int(os.getenv("BATCH_SIZE", "2000"))
    flush_interval_secs: float = float(os.getenv("FLUSH_INTERVAL_SECS", "0.5"))
    max_payload_bytes: int = int(os.getenv("MAX_PAYLOAD_BYTES", "65536"))  # 64 KB
    max_keys_per_message: int = int(os.getenv("MAX_KEYS_PER_MESSAGE", "256"))
    default_max_fields_per_channel: int = int(os.getenv("MAX_FIELDS_PER_CHANNEL", "500"))

settings = Settings()
