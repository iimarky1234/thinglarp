"""bridge/batcher.py: High-throughput micro-batching buffer using PostgreSQL COPY."""

import asyncio
from datetime import datetime
import logging
from typing import Any
import asyncpg
import orjson

logger = logging.getLogger("bridge.batcher")

class TelemetryBatcher:
    def __init__(
        self,
        pool: asyncpg.Pool,
        batch_size: int = 2000,
        flush_interval_secs: float = 0.5,
    ):
        self._pool = pool
        self._batch_size = batch_size
        self._flush_interval_secs = flush_interval_secs

        # Points: (time, channel_id, field_id, value)
        self._points_buffer: list[tuple[datetime, int, int, float]] = []
        # Messages: (time, channel_id, json_str)
        self._messages_buffer: list[tuple[datetime, int, str]] = []

        self._lock = asyncio.Lock()
        self._flusher_task: asyncio.Task | None = None
        self._running = False

    def start(self) -> None:
        """Start the periodic flush background task."""
        if not self._running:
            self._running = True
            self._flusher_task = asyncio.create_task(self._periodic_flusher())
            logger.info(
                f"Batcher started (batch_size={self._batch_size}, flush_interval={self._flush_interval_secs}s)."
            )

    async def stop(self) -> None:
        """Stop background task and flush remaining records."""
        self._running = False
        if self._flusher_task:
            self._flusher_task.cancel()
            try:
                await self._flusher_task
            except asyncio.CancelledError:
                pass
        await self.flush()
        logger.info("Batcher stopped cleanly.")

    async def add_records(
        self,
        points: list[tuple[datetime, int, int, float]],
        messages: list[tuple[datetime, int, dict[str, Any]]],
    ) -> None:
        """Add parsed records to the memory buffer, flushing immediately if size exceeds threshold."""
        if not points and not messages:
            return

        # Pre-serialize messages to json strings outside the lock
        serialized_messages = [
            (t, cid, orjson.dumps(payload).decode("utf-8"))
            for t, cid, payload in messages
        ]

        should_flush = False
        async with self._lock:
            self._points_buffer.extend(points)
            self._messages_buffer.extend(serialized_messages)
            if len(self._points_buffer) >= self._batch_size:
                should_flush = True

        if should_flush:
            await self.flush()

    async def _periodic_flusher(self) -> None:
        """Periodically flush records if any are buffered."""
        while self._running:
            try:
                await asyncio.sleep(self._flush_interval_secs)
                await self.flush()
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Unexpected error in periodic flusher: {e}", exc_info=True)

    async def flush(self) -> None:
        """Flush in-memory buffers directly into TimescaleDB using COPY protocol."""
        async with self._lock:
            if not self._points_buffer and not self._messages_buffer:
                return

            points_to_write = self._points_buffer
            messages_to_write = self._messages_buffer
            self._points_buffer = []
            self._messages_buffer = []

        try:
            async with self._pool.acquire() as conn:
                async with conn.transaction():
                    if points_to_write:
                        await conn.copy_records_to_table(
                            "points",
                            schema_name="telemetry",
                            records=points_to_write,
                            columns=["time", "channel_id", "field_id", "value"],
                        )
                    if messages_to_write:
                        await conn.copy_records_to_table(
                            "messages",
                            schema_name="telemetry",
                            records=messages_to_write,
                            columns=["time", "channel_id", "payload"],
                        )

            logger.debug(
                f"Flushed {len(points_to_write)} points and {len(messages_to_write)} messages to TimescaleDB."
            )
        except Exception as e:
            logger.error(f"Failed to flush telemetry batch: {e}", exc_info=True)
            # Re-enqueue to prevent data loss on transient DB errors (subject to safety cap)
            async with self._lock:
                if len(self._points_buffer) < 50000:
                    self._points_buffer = points_to_write + self._points_buffer
                    self._messages_buffer = messages_to_write + self._messages_buffer
                else:
                    logger.critical("Buffer exceeded safety cap (50k records). Dropping batch to prevent OOM.")
