"""bridge/parser.py: Validates topics and deserializes JSON payloads."""

import re
from datetime import datetime, timezone, timedelta
from typing import Any
import orjson

# Topic pattern: channels/{channel_id}/data
TOPIC_REGEX = re.compile(r"^channels/(?P<channel_id>\d+)/data$")

# Field key allowed format: alphanumeric, underscore, dot, hyphen (1-64 chars)
KEY_REGEX = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")

# Reserved keys used for message timestamping
TIMESTAMP_KEYS = frozenset({"ts", "time", "timestamp"})

# Timestamp validation boundaries (relative to server clock)
MAX_PAST_DELTA = timedelta(days=7)
MAX_FUTURE_DELTA = timedelta(minutes=5)

def parse_channel_id(topic: str) -> int | None:
    """Extract integer channel_id from MQTT topic."""
    match = TOPIC_REGEX.match(topic)
    if not match:
        return None
    try:
        return int(match.group("channel_id"))
    except ValueError:
        return None

def resolve_timestamp(raw_val: Any, now: datetime) -> datetime:
    """Validate and convert timestamp values (ms, seconds, or ISO string) to UTC datetime."""
    if raw_val is None:
        return now

    candidate: datetime | None = None
    if isinstance(raw_val, (int, float)):
        try:
            # If timestamp > 1e11 it's in milliseconds (e.g. 1731410153000)
            sec = raw_val / 1000.0 if raw_val > 1e11 else float(raw_val)
            candidate = datetime.fromtimestamp(sec, tz=timezone.utc)
        except (ValueError, OverflowError, OSError):
            candidate = None
    elif isinstance(raw_val, str):
        try:
            candidate = datetime.fromisoformat(raw_val.replace("Z", "+00:00"))
            if candidate.tzinfo is None:
                candidate = candidate.replace(tzinfo=timezone.utc)
        except ValueError:
            candidate = None

    if candidate is None:
        return now

    # Check boundaries (-7 days <= candidate <= +5 mins)
    if (now - MAX_PAST_DELTA) <= candidate <= (now + MAX_FUTURE_DELTA):
        return candidate
    return now

class ParsedMessage:
    __slots__ = ("channel_id", "timestamp", "numeric_fields", "raw_payload", "field_types")

    def __init__(
        self,
        channel_id: int,
        timestamp: datetime,
        numeric_fields: dict[str, float],
        raw_payload: dict[str, Any],
        field_types: dict[str, str],
    ):
        self.channel_id = channel_id
        self.timestamp = timestamp
        self.numeric_fields = numeric_fields
        self.raw_payload = raw_payload
        self.field_types = field_types

def parse_payload(
    payload_bytes: bytes,
    channel_id: int,
    max_payload_bytes: int = 65536,
    max_keys: int = 256,
) -> list[ParsedMessage]:
    """Parse raw bytes into one or multiple ParsedMessage objects."""
    if len(payload_bytes) > max_payload_bytes:
        return []

    try:
        data = orjson.loads(payload_bytes)
    except orjson.JSONDecodeError:
        return []

    # Handle both single dictionary and array of dictionaries
    items: list[dict[str, Any]]
    if isinstance(data, dict):
        items = [data]
    elif isinstance(data, list):
        items = [item for item in data if isinstance(item, dict)]
    else:
        return []

    results: list[ParsedMessage] = []
    now = datetime.now(timezone.utc)

    for item in items:
        if len(item) > max_keys:
            continue

        # Extract explicit timestamp if present
        raw_ts = None
        for k in TIMESTAMP_KEYS:
            if k in item:
                raw_ts = item[k]
                break
        record_time = resolve_timestamp(raw_ts, now)

        numeric_fields: dict[str, float] = {}
        field_types: dict[str, str] = {}

        for key, val in item.items():
            if key in TIMESTAMP_KEYS:
                continue
            if not KEY_REGEX.match(key):
                continue

            if isinstance(val, (int, float)) and not isinstance(val, bool):
                try:
                    fval = float(val)
                    numeric_fields[key] = fval
                    field_types[key] = "number"
                except (ValueError, OverflowError):
                    continue
            elif isinstance(val, bool):
                field_types[key] = "boolean"
            elif isinstance(val, str):
                field_types[key] = "string"

        results.append(
            ParsedMessage(
                channel_id=channel_id,
                timestamp=record_time,
                numeric_fields=numeric_fields,
                raw_payload=item,
                field_types=field_types,
            )
        )

    return results
