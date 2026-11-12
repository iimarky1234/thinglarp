"""api/mqtt_client.py: MQTT client for internal API publishing."""

import asyncio
import logging
import aiomqtt
from config import settings

logger = logging.getLogger("api.mqtt")

class MqttPublisher:
    def __init__(self):
        self._client: aiomqtt.Client | None = None
        self._lock = asyncio.Lock()
        self._connected = False

    async def connect(self) -> None:
        """Initialize connection to Mosquitto."""
        try:
            self._client = aiomqtt.Client(
                hostname=settings.mqtt_host,
                port=settings.mqtt_port,
                username=settings.mqtt_user,
                password=settings.mqtt_password,
                identifier=settings.mqtt_client_id,
            )
            await self._client.__aenter__()
            self._connected = True
            logger.info(f"API MQTT publisher connected to {settings.mqtt_host}:{settings.mqtt_port}")
        except Exception as e:
            logger.warning(f"Could not immediately connect API MQTT publisher: {e}")
            self._connected = False

    async def disconnect(self) -> None:
        """Close connection cleanly."""
        if self._client and self._connected:
            try:
                await self._client.__aexit__(None, None, None)
            except Exception as e:
                logger.error(f"Error disconnecting MQTT client: {e}")
            self._connected = False
            self._client = None
            logger.info("API MQTT publisher disconnected.")

    async def publish(self, topic: str, payload: bytes | str, qos: int = 1) -> bool:
        """Publish message to MQTT broker. Reconnects on demand if necessary."""
        async with self._lock:
            if not self._connected or self._client is None:
                await self.connect()

            if not self._connected or self._client is None:
                logger.error(f"Failed to publish to '{topic}': MQTT client not connected.")
                return False

            try:
                await self._client.publish(topic, payload=payload, qos=qos)
                return True
            except Exception as e:
                logger.error(f"MQTT publish error on topic '{topic}': {e}")
                self._connected = False
                return False

publisher = MqttPublisher()
