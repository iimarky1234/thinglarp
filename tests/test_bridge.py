"""tests/test_bridge.py: Unit tests for bridge parsing, caching, and batching."""

import sys
import os
from datetime import datetime, timezone, timedelta
import pytest
from unittest.mock import AsyncMock, MagicMock

# Add bridge directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../bridge")))

from parser import parse_channel_id, parse_payload, resolve_timestamp
from field_cache import FieldCache
from batcher import TelemetryBatcher

# -----------------------------------------------------------------------------
# Topic Parsing Tests
# -----------------------------------------------------------------------------
def test_parse_channel_id_valid():
    assert parse_channel_id("channels/1/data") == 1
    assert parse_channel_id("channels/4294967295/data") == 4294967295

def test_parse_channel_id_invalid():
    # Leading slash should be rejected
    assert parse_channel_id("/channels/1/data") is None
    # Wrong suffix
    assert parse_channel_id("channels/1/status") is None
    # Non-numeric channel ID
    assert parse_channel_id("channels/abc/data") is None
    # Wildcard topics
    assert parse_channel_id("channels/+/data") is None


# -----------------------------------------------------------------------------
# Timestamp Resolution Tests
# -----------------------------------------------------------------------------
def test_resolve_timestamp_variations():
    now = datetime(2026, 11, 12, 12, 0, 0, tzinfo=timezone.utc)

    # 1. None -> returns now
    assert resolve_timestamp(None, now) == now

    # 2. Milliseconds epoch
    epoch_ms = int(datetime(2026, 11, 12, 11, 59, 0, tzinfo=timezone.utc).timestamp() * 1000)
    resolved = resolve_timestamp(epoch_ms, now)
    assert resolved.year == 2026
    assert resolved.minute == 59

    # 3. Seconds epoch
    epoch_sec = int(datetime(2026, 11, 12, 11, 58, 0, tzinfo=timezone.utc).timestamp())
    resolved = resolve_timestamp(epoch_sec, now)
    assert resolved.minute == 58

    # 4. ISO string
    iso_str = "2026-11-12T11:55:00Z"
    resolved = resolve_timestamp(iso_str, now)
    assert resolved.minute == 55

    # 5. Out of bounds future (> 5 mins) -> fallback to now
    future_ms = int((now + timedelta(minutes=10)).timestamp() * 1000)
    assert resolve_timestamp(future_ms, now) == now

    # 6. Out of bounds past (> 7 days) -> fallback to now
    past_ms = int((now - timedelta(days=10)).timestamp() * 1000)
    assert resolve_timestamp(past_ms, now) == now


# -----------------------------------------------------------------------------
# Payload Parsing Tests
# -----------------------------------------------------------------------------
def test_parse_payload_single_object():
    payload = b'{"temp": 24.5, "humidity": 60, "status": "active", "battery_ok": true}'
    results = parse_payload(payload, channel_id=10)
    assert len(results) == 1
    record = results[0]

    assert record.channel_id == 10
    assert record.numeric_fields == {"temp": 24.5, "humidity": 60.0}
    assert record.field_types == {
        "temp": "number",
        "humidity": "number",
        "status": "string",
        "battery_ok": "boolean",
    }
    assert record.raw_payload["status"] == "active"

def test_parse_payload_array_batch():
    payload = b'[{"ts": 1731410000000, "v": 1.2}, {"ts": 1731410001000, "v": 1.3}]'
    results = parse_payload(payload, channel_id=20)
    assert len(results) == 2
    assert results[0].numeric_fields == {"v": 1.2}
    assert results[1].numeric_fields == {"v": 1.3}

def test_parse_payload_invalid_key_names():
    # Keys with spaces, dollar signs, or special chars must be skipped
    payload = b'{"valid_key": 10, "invalid key": 20, "$bad": 30}'
    results = parse_payload(payload, channel_id=1)
    assert len(results) == 1
    assert "valid_key" in results[0].numeric_fields
    assert "invalid key" not in results[0].numeric_fields
    assert "$bad" not in results[0].numeric_fields

def test_parse_payload_corrupt_json():
    assert parse_payload(b'{"incomplete": ', channel_id=1) == []
    assert parse_payload(b'plain text', channel_id=1) == []

def test_parse_payload_oversized():
    # Exceeding 64KB should be rejected
    huge_payload = b'{"data": "' + (b"A" * 70000) + b'"}'
    assert parse_payload(huge_payload, channel_id=1, max_payload_bytes=65536) == []


# -----------------------------------------------------------------------------
# Field Cache Tests
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_field_cache_fast_path():
    cache = FieldCache(default_max_fields=10)
    # Preload cache manually
    cache._fields[(1, "temp")] = 101
    cache._channel_counts[1] = 1

    mock_pool = MagicMock()
    # Should resolve from memory without calling pool
    result = await cache.get_or_register_fields(
        channel_id=1,
        fields_with_types={"temp": "number"},
        pool=mock_pool,
    )
    assert result == {"temp": 101}
    mock_pool.acquire.assert_not_called()

@pytest.mark.asyncio
async def test_field_cache_guardrail_limit():
    # Max fields = 2
    cache = FieldCache(default_max_fields=2)
    cache._channel_max[1] = 2
    cache._channel_counts[1] = 2
    cache._fields[(1, "f1")] = 1
    cache._fields[(1, "f2")] = 2

    mock_pool = MagicMock()
    # Trying to add 'f3' should be rejected due to guardrail limit
    result = await cache.get_or_register_fields(
        channel_id=1,
        fields_with_types={"f3": "number"},
        pool=mock_pool,
    )
    assert "f3" not in result
    mock_pool.acquire.assert_not_called()


# -----------------------------------------------------------------------------
# Telemetry Batcher Tests
# -----------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_batcher_accumulation_and_flush():
    mock_conn = AsyncMock()
    mock_conn.transaction = MagicMock()
    mock_conn.copy_records_to_table = AsyncMock()

    mock_pool = MagicMock()
    mock_pool.acquire.return_value.__aenter__.return_value = mock_conn

    batcher = TelemetryBatcher(pool=mock_pool, batch_size=2, flush_interval_secs=10.0)

    now = datetime.now(timezone.utc)
    point1 = (now, 1, 10, 25.0)
    msg1 = (now, 1, {"temp": 25.0})

    # Adding 1 record should not trigger flush yet (threshold is 2)
    await batcher.add_records([point1], [msg1])
    assert len(batcher._points_buffer) == 1
    mock_conn.copy_records_to_table.assert_not_called()

    # Adding second record reaches batch_size=2 and triggers immediate flush
    point2 = (now, 1, 10, 26.0)
    msg2 = (now, 1, {"temp": 26.0})
    await batcher.add_records([point2], [msg2])

    assert len(batcher._points_buffer) == 0
    assert mock_conn.copy_records_to_table.call_count == 2
