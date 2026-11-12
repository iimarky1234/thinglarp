"""bridge/field_cache.py: In-memory registry with guardrail channel field limits."""

import asyncio
import logging
from typing import Any
import asyncpg

logger = logging.getLogger("bridge.field_cache")

class FieldCache:
    def __init__(self, default_max_fields: int = 500):
        self._default_max_fields = default_max_fields
        # (channel_id, field_key) -> field_id
        self._fields: dict[tuple[int, str], int] = {}
        # channel_id -> max_fields limit
        self._channel_max: dict[int, int] = {}
        # channel_id -> count of existing fields
        self._channel_counts: dict[int, int] = {}
        self._lock = asyncio.Lock()

    async def load(self, pool: asyncpg.Pool) -> None:
        """Pre-populate cache from PostgreSQL on startup."""
        async with pool.acquire() as conn:
            # 1. Load channel configurations
            channels = await conn.fetch("SELECT id, max_fields FROM app.channels")
            for row in channels:
                self._channel_max[row["id"]] = row["max_fields"]

            # 2. Load existing channel fields
            fields = await conn.fetch("SELECT id, channel_id, key FROM app.channel_fields")
            for row in fields:
                self._fields[(row["channel_id"], row["key"])] = row["id"]
                self._channel_counts[row["channel_id"]] = self._channel_counts.get(row["channel_id"], 0) + 1

        logger.info(
            f"FieldCache initialized with {len(self._fields)} fields across {len(self._channel_max)} channels."
        )

    async def get_or_register_fields(
        self,
        channel_id: int,
        fields_with_types: dict[str, str],
        pool: asyncpg.Pool,
    ) -> dict[str, int]:
        """Resolve field_ids from memory, registering any new fields under channel limits."""
        if not fields_with_types:
            return {}

        resolved: dict[str, int] = {}
        missing: list[tuple[str, str]] = []

        # Fast path: check in-memory cache
        for key, val_type in fields_with_types.items():
            field_id = self._fields.get((channel_id, key))
            if field_id is not None:
                resolved[key] = field_id
            else:
                missing.append((key, val_type))

        if not missing:
            return resolved

        # Slow path: handle unregistered fields under lock
        async with self._lock:
            # Double check under lock
            to_insert: list[tuple[str, str]] = []
            for key, val_type in missing:
                field_id = self._fields.get((channel_id, key))
                if field_id is not None:
                    resolved[key] = field_id
                else:
                    to_insert.append((key, val_type))

            if not to_insert:
                return resolved

            max_allowed = self._channel_max.get(channel_id, self._default_max_fields)
            current_count = self._channel_counts.get(channel_id, 0)

            # Enforce max field guardrails
            allowed_to_insert: list[tuple[str, str]] = []
            for key, val_type in to_insert:
                if current_count >= max_allowed:
                    logger.warning(
                        f"Channel {channel_id} reached max fields limit ({max_allowed}). Dropping new key '{key}'."
                    )
                    continue
                allowed_to_insert.append((key, val_type))
                current_count += 1

            if not allowed_to_insert:
                return resolved

            async with pool.acquire() as conn:
                for key, val_type in allowed_to_insert:
                    try:
                        row = await conn.fetchrow(
                            """
                            INSERT INTO app.channel_fields (channel_id, key, value_type)
                            VALUES ($1, $2, $3)
                            ON CONFLICT (channel_id, key) DO UPDATE
                            SET value_type = EXCLUDED.value_type
                            RETURNING id;
                            """,
                            channel_id,
                            key,
                            val_type,
                        )
                        if row:
                            fid = row["id"]
                            self._fields[(channel_id, key)] = fid
                            self._channel_counts[channel_id] = self._channel_counts.get(channel_id, 0) + 1
                            resolved[key] = fid
                    except Exception as e:
                        logger.error(f"Failed to register field '{key}' on channel {channel_id}: {e}")

        return resolved
