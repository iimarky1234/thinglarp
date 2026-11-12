"""bridge/main.py: Asynchronous MQTT Ingestion Bridge service."""

import asyncio
import logging
import signal
import sys
import aiomqtt
import asyncpg

from config import settings
from parser import parse_channel_id, parse_payload
from field_cache import FieldCache
from batcher import TelemetryBatcher

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] (%(name)s) %(message)s",
)
logger = logging.getLogger("bridge")

async def init_db_pool() -> asyncpg.Pool:
    """Connect to TimescaleDB with retry backoff."""
    while True:
        try:
            pool = await asyncpg.create_pool(
                host=settings.db_host,
                port=settings.db_port,
                database=settings.db_name,
                user=settings.db_user,
                password=settings.db_password,
                min_size=settings.db_min_connections,
                max_size=settings.db_max_connections,
            )
            logger.info(f"Connected to TimescaleDB at {settings.db_host}:{settings.db_port}/{settings.db_name}")
            return pool
        except Exception as e:
            logger.warning(f"Database connection waiting ({e}). Retrying in 2 seconds...")
            await asyncio.sleep(2)

async def run_mqtt_consumer(
    pool: asyncpg.Pool,
    field_cache: FieldCache,
    batcher: TelemetryBatcher,
    stop_event: asyncio.Event,
) -> None:
    """MQTT consumer loop with automated reconnect and session handling."""
    reconnect_interval = 2.0

    while not stop_event.is_set():
        try:
            logger.info(f"Connecting to MQTT broker at {settings.mqtt_host}:{settings.mqtt_port}...")
            async with aiomqtt.Client(
                hostname=settings.mqtt_host,
                port=settings.mqtt_port,
                username=settings.mqtt_user,
                password=settings.mqtt_password,
                identifier=settings.mqtt_client_id,
                clean_session=settings.mqtt_clean_session,
            ) as client:
                logger.info("Connected to MQTT Broker.")
                
                # Attempt shared subscription first for load balancing across replicas
                topic_to_sub = settings.mqtt_topic
                try:
                    await client.subscribe(topic_to_sub, qos=1)
                    logger.info(f"Subscribed to topic '{topic_to_sub}' (QoS 1).")
                except Exception as e:
                    logger.warning(f"Failed to subscribe to shared topic '{topic_to_sub}' ({e}). Falling back to '{settings.mqtt_topic_fallback}'.")
                    topic_to_sub = settings.mqtt_topic_fallback
                    await client.subscribe(topic_to_sub, qos=1)
                    logger.info(f"Subscribed to fallback topic '{topic_to_sub}' (QoS 1).")

                reconnect_interval = 2.0  # Reset reconnect timer on successful connection

                async for message in client.messages:
                    if stop_event.is_set():
                        break

                    topic_str = str(message.topic)
                    channel_id = parse_channel_id(topic_str)
                    if channel_id is None:
                        continue

                    raw_payload = bytes(message.payload) if isinstance(message.payload, (bytes, bytearray, memoryview)) else str(message.payload).encode("utf-8")
                    
                    parsed_items = parse_payload(
                        raw_payload,
                        channel_id=channel_id,
                        max_payload_bytes=settings.max_payload_bytes,
                        max_keys=settings.max_keys_per_message,
                    )
                    if not parsed_items:
                        continue

                    points_to_buffer = []
                    messages_to_buffer = []

                    for item in parsed_items:
                        messages_to_buffer.append((item.timestamp, item.channel_id, item.raw_payload))

                        if item.numeric_fields:
                            # Resolve or register field IDs
                            field_ids = await field_cache.get_or_register_fields(
                                item.channel_id,
                                item.field_types,
                                pool,
                            )
                            for field_name, num_val in item.numeric_fields.items():
                                fid = field_ids.get(field_name)
                                if fid is not None:
                                    points_to_buffer.append((item.timestamp, item.channel_id, fid, num_val))

                    await batcher.add_records(points_to_buffer, messages_to_buffer)

        except aiomqtt.MqttError as e:
            if stop_event.is_set():
                break
            logger.warning(f"MQTT connection lost: {e}. Reconnecting in {reconnect_interval}s...")
            await asyncio.sleep(reconnect_interval)
            reconnect_interval = min(reconnect_interval * 1.5, 30.0)
        except Exception as e:
            if stop_event.is_set():
                break
            logger.error(f"Unexpected error in MQTT consumer: {e}", exc_info=True)
            await asyncio.sleep(2)

async def main() -> None:
    logger.info("Initializing IoT Telemetry Ingestion Bridge...")

    pool = await init_db_pool()

    field_cache = FieldCache(default_max_fields=settings.default_max_fields_per_channel)
    try:
        await field_cache.load(pool)
    except Exception as e:
        logger.warning(f"Could not pre-load field cache ({e}). Cache will populate dynamically.")

    batcher = TelemetryBatcher(
        pool=pool,
        batch_size=settings.batch_size,
        flush_interval_secs=settings.flush_interval_secs,
    )
    batcher.start()

    stop_event = asyncio.Event()

    def handle_signal():
        logger.info("Shutdown signal received.")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, handle_signal)

    try:
        await run_mqtt_consumer(pool, field_cache, batcher, stop_event)
    finally:
        logger.info("Shutting down bridge service...")
        await batcher.stop()
        await pool.close()
        logger.info("Shutdown complete.")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
