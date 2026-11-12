"""api/routers/data.py: Telemetry data ingestion via MQTT publishing and historical querying."""

import csv
import io
import re
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Response, status
import asyncpg
import orjson

from database import get_db
from mqtt_client import publisher
from schemas import (
    ChannelTelemetryOut,
    LatestTelemetryOut,
    TelemetryPoint,
    CommandDispatch,
    CommandDispatchOut,
    ImportResultOut,
)
from security import (
    get_optional_current_user,
    CurrentUser,
    sha256_hash,
)

router = APIRouter(prefix="/channels/{channel_id}", tags=["Telemetry Data"])

async def authorize_channel_access(
    channel_id: int,
    required_scope: str, # 'read' or 'write'
    api_key: str | None,
    current_user: CurrentUser | None,
    db: asyncpg.Connection,
) -> dict:
    """Validate access via API Key, User JWT, or Public channel access."""
    channel = await db.fetchrow("SELECT * FROM app.channels WHERE id = $1", channel_id)
    if not channel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Channel not found")

    # 1. API Key authorization
    if api_key:
        key_hash = sha256_hash(api_key)
        key_row = await db.fetchrow(
            """
            SELECT id, scope, revoked_at
            FROM app.api_keys
            WHERE channel_id = $1 AND key_hash = $2 AND revoked_at IS NULL;
            """,
            channel_id,
            key_hash,
        )
        if key_row:
            if required_scope == "read" or key_row["scope"] == "write":
                # Update last used timestamp
                await db.execute("UPDATE app.api_keys SET last_used_at = now() WHERE id = $1", key_row["id"])
                return dict(channel)

    # 2. Authenticated user authorization
    if current_user:
        if channel["owner_id"] == current_user.id:
            return dict(channel)

    # 3. Public channel access (Read-only)
    if required_scope == "read" and channel["is_public"]:
        return dict(channel)

    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")


@router.post("/data", status_code=status.HTTP_202_ACCEPTED)
async def publish_telemetry(
    channel_id: int,
    request: Request,
    db: Annotated[asyncpg.Connection, Depends(get_db)],
    x_api_key: Annotated[str | None, Header()] = None,
    current_user: Annotated[CurrentUser | None, Depends(get_optional_current_user)] = None,
):
    """
    Ingest telemetry via HTTP.
    Authenticates via X-API-Key header or Bearer JWT, then publishes to MQTT
    topic 'channels/{channel_id}/data'.
    """
    await authorize_channel_access(channel_id, "write", x_api_key, current_user, db)

    body_bytes = await request.body()
    try:
        # Validate that payload is JSON
        orjson.loads(body_bytes)
    except orjson.JSONDecodeError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid JSON payload")

    topic = f"channels/{channel_id}/data"
    published = await publisher.publish(topic, body_bytes, qos=1)
    if not published:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Broker unavailable")

    return {"status": "published", "channel_id": channel_id}


@router.get("/data", response_model=ChannelTelemetryOut)
async def query_telemetry(
    channel_id: int,
    db: Annotated[asyncpg.Connection, Depends(get_db)],
    fields: str | None = Query(None, description="Comma-separated field keys (e.g. temp,humidity)"),
    start: datetime | None = Query(None, description="Start time (defaults to -24h)"),
    end: datetime | None = Query(None, description="End time (defaults to now)"),
    resolution: str = Query("auto", pattern=r"^(auto|raw|1m|1h)$"),
    x_api_key: Annotated[str | None, Header()] = None,
    current_user: Annotated[CurrentUser | None, Depends(get_optional_current_user)] = None,
):
    """Query time-series telemetry with automated downsampling."""
    await authorize_channel_access(channel_id, "read", x_api_key, current_user, db)

    now = datetime.now(timezone.utc)
    end_time = end or now
    start_time = start or (end_time - timedelta(hours=24))

    # Determine resolution
    chosen_resolution = resolution
    if resolution == "auto":
        duration = end_time - start_time
        if duration <= timedelta(hours=6):
            chosen_resolution = "raw"
        elif duration <= timedelta(days=30):
            chosen_resolution = "1m"
        else:
            chosen_resolution = "1h"

    # Resolve field IDs
    field_filter = [f.strip() for f in fields.split(",")] if fields else []
    if field_filter:
        field_rows = await db.fetch(
            "SELECT id, key FROM app.channel_fields WHERE channel_id = $1 AND key = ANY($2::text[])",
            channel_id,
            field_filter,
        )
    else:
        field_rows = await db.fetch(
            "SELECT id, key FROM app.channel_fields WHERE channel_id = $1",
            channel_id,
        )

    field_map = {r["id"]: r["key"] for r in field_rows}
    if not field_map:
        return ChannelTelemetryOut(channel_id=channel_id, resolution=chosen_resolution, fields={})

    field_ids = list(field_map.keys())
    result_fields: dict[str, list[TelemetryPoint]] = {key: [] for key in field_map.values()}

    if chosen_resolution == "raw":
        query = """
            SELECT time, field_id, value
            FROM telemetry.points
            WHERE channel_id = $1 AND field_id = ANY($2::int[]) AND time >= $3 AND time <= $4
            ORDER BY time ASC;
        """
        rows = await db.fetch(query, channel_id, field_ids, start_time, end_time)
        for r in rows:
            key = field_map[r["field_id"]]
            result_fields[key].append(TelemetryPoint(time=r["time"], value=r["value"]))
    elif chosen_resolution == "1m":
        query = """
            SELECT bucket AS time, field_id, avg_v AS value, min_v, max_v
            FROM telemetry.points_1m
            WHERE channel_id = $1 AND field_id = ANY($2::int[]) AND bucket >= $3 AND bucket <= $4
            ORDER BY bucket ASC;
        """
        rows = await db.fetch(query, channel_id, field_ids, start_time, end_time)
        for r in rows:
            key = field_map[r["field_id"]]
            result_fields[key].append(
                TelemetryPoint(time=r["time"], value=r["value"], min=r["min_v"], max=r["max_v"])
            )
    else: # 1h
        query = """
            SELECT bucket_1h AS time, field_id, avg_v AS value, min_v, max_v
            FROM telemetry.points_1h
            WHERE channel_id = $1 AND field_id = ANY($2::int[]) AND bucket_1h >= $3 AND bucket_1h <= $4
            ORDER BY bucket_1h ASC;
        """
        rows = await db.fetch(query, channel_id, field_ids, start_time, end_time)
        for r in rows:
            key = field_map[r["field_id"]]
            result_fields[key].append(
                TelemetryPoint(time=r["time"], value=r["value"], min=r["min_v"], max=r["max_v"])
            )

    return ChannelTelemetryOut(
        channel_id=channel_id,
        resolution=chosen_resolution,
        fields=result_fields,
    )


@router.get("/latest", response_model=LatestTelemetryOut)
async def get_latest_telemetry(
    channel_id: int,
    db: Annotated[asyncpg.Connection, Depends(get_db)],
    x_api_key: Annotated[str | None, Header()] = None,
    current_user: Annotated[CurrentUser | None, Depends(get_optional_current_user)] = None,
):
    """Retrieve the latest complete JSON telemetry packet."""
    await authorize_channel_access(channel_id, "read", x_api_key, current_user, db)

    row = await db.fetchrow(
        """
        SELECT time, payload
        FROM telemetry.messages
        WHERE channel_id = $1
        ORDER BY time DESC
        LIMIT 1;
        """,
        channel_id,
    )

    if not row:
        return LatestTelemetryOut(channel_id=channel_id, timestamp=None, fields={})

    raw_payload = row["payload"]
    fields_dict = orjson.loads(raw_payload) if isinstance(raw_payload, str) else raw_payload

    return LatestTelemetryOut(
        channel_id=channel_id,
        timestamp=row["time"],
        fields=fields_dict,
    )


@router.delete("/data", status_code=status.HTTP_200_OK)
async def clear_telemetry(
    channel_id: int,
    db: Annotated[asyncpg.Connection, Depends(get_db)],
    current_user: Annotated[CurrentUser | None, Depends(get_optional_current_user)] = None,
    x_api_key: Annotated[str | None, Header()] = None,
):
    """
    Clear all telemetry data (points and message logs) for a channel.
    Requires channel owner authorization or API key with write access.
    """
    await authorize_channel_access(channel_id, "write", x_api_key, current_user, db)

    await db.execute("DELETE FROM telemetry.points WHERE channel_id = $1;", channel_id)
    await db.execute("DELETE FROM telemetry.messages WHERE channel_id = $1;", channel_id)

    return {
        "status": "cleared",
        "channel_id": channel_id,
        "detail": "All telemetry points and messages have been cleared.",
    }


@router.get("/export")
async def export_telemetry(
    channel_id: int,
    db: Annotated[asyncpg.Connection, Depends(get_db)],
    format: str = Query("csv", pattern=r"^(csv|json)$"),
    resolution: str = Query("raw", pattern=r"^(auto|raw|1m|1h)$"),
    fields: str | None = Query(None, description="Comma-separated field keys"),
    start: datetime | None = Query(None),
    end: datetime | None = Query(None),
    x_api_key: Annotated[str | None, Header()] = None,
    current_user: Annotated[CurrentUser | None, Depends(get_optional_current_user)] = None,
):
    """
    Export channel telemetry data in CSV or JSON format.
    Supports time-range filtering and resolution selection.
    """
    await authorize_channel_access(channel_id, "read", x_api_key, current_user, db)

    now = datetime.now(timezone.utc)
    end_time = end or now
    start_time = start or (end_time - timedelta(days=30))

    # Resolve field mappings
    field_rows = await db.fetch("SELECT id, key FROM app.channel_fields WHERE channel_id = $1", channel_id)
    field_map = {r["id"]: r["key"] for r in field_rows}

    if not field_map:
        if format == "csv":
            return Response(content="time,field,value\n", media_type="text/csv", headers={
                "Content-Disposition": f'attachment; filename="channel_{channel_id}_export.csv"'
            })
        return Response(content=orjson.dumps({"channel_id": channel_id, "points": []}), media_type="application/json", headers={
            "Content-Disposition": f'attachment; filename="channel_{channel_id}_export.json"'
        })

    filter_keys = [f.strip() for f in fields.split(",")] if fields else None
    if filter_keys:
        field_map = {fid: fkey for fid, fkey in field_map.items() if fkey in filter_keys}
    field_ids = list(field_map.keys())

    if not field_ids:
        rows = []
        chosen_resolution = resolution
    else:
        chosen_resolution = resolution
        if chosen_resolution == "auto":
            delta = end_time - start_time
            if delta > timedelta(days=14):
                chosen_resolution = "1h"
            elif delta > timedelta(hours=6):
                chosen_resolution = "1m"
            else:
                chosen_resolution = "raw"

        if chosen_resolution == "raw":
            query = """
                SELECT time, field_id, value
                FROM telemetry.points
                WHERE channel_id = $1 AND field_id = ANY($2::int[]) AND time >= $3 AND time <= $4
                ORDER BY time ASC;
            """
            raw_rows = await db.fetch(query, channel_id, field_ids, start_time, end_time)
            rows = [{"time": r["time"].isoformat(), "field": field_map[r["field_id"]], "value": r["value"]} for r in raw_rows]
        elif chosen_resolution == "1m":
            query = """
                SELECT bucket_1m AS time, field_id, avg_value AS value, min_value, max_value, count_points
                FROM telemetry.points_1m
                WHERE channel_id = $1 AND field_id = ANY($2::int[]) AND bucket_1m >= $3 AND bucket_1m <= $4
                ORDER BY bucket_1m ASC;
            """
            agg_rows = await db.fetch(query, channel_id, field_ids, start_time, end_time)
            rows = [{
                "time": r["time"].isoformat(),
                "field": field_map[r["field_id"]],
                "value": r["value"],
                "min": r["min_value"],
                "max": r["max_value"],
                "count": r["count_points"],
            } for r in agg_rows]
        else:
            query = """
                SELECT bucket_1h AS time, field_id, avg_value AS value, min_value, max_value, count_points
                FROM telemetry.points_1h
                WHERE channel_id = $1 AND field_id = ANY($2::int[]) AND bucket_1h >= $3 AND bucket_1h <= $4
                ORDER BY bucket_1h ASC;
            """
            agg_rows = await db.fetch(query, channel_id, field_ids, start_time, end_time)
            rows = [{
                "time": r["time"].isoformat(),
                "field": field_map[r["field_id"]],
                "value": r["value"],
                "min": r["min_value"],
                "max": r["max_value"],
                "count": r["count_points"],
            } for r in agg_rows]

    if format == "csv":
        output = io.StringIO()
        writer = csv.writer(output)
        if chosen_resolution == "raw":
            writer.writerow(["time", "field", "value"])
            for r in rows:
                writer.writerow([r["time"], r["field"], r["value"]])
        else:
            writer.writerow(["time", "field", "avg_value", "min_value", "max_value", "count"])
            for r in rows:
                writer.writerow([r["time"], r["field"], r["value"], r["min"], r["max"], r["count"]])

        csv_bytes = output.getvalue().encode("utf-8")
        return Response(
            content=csv_bytes,
            media_type="text/csv",
            headers={"Content-Disposition": f'attachment; filename="channel_{channel_id}_export.csv"'},
        )
    else:
        json_bytes = orjson.dumps({
            "channel_id": channel_id,
            "resolution": chosen_resolution,
            "count": len(rows),
            "points": rows,
        }, option=orjson.OPT_INDENT_2)
        return Response(
            content=json_bytes,
            media_type="application/json",
            headers={"Content-Disposition": f'attachment; filename="channel_{channel_id}_export.json"'},
        )


@router.post("/commands", response_model=CommandDispatchOut, status_code=status.HTTP_200_OK)
async def dispatch_command(
    channel_id: int,
    payload: CommandDispatch,
    db: Annotated[asyncpg.Connection, Depends(get_db)],
    x_api_key: Annotated[str | None, Header()] = None,
    current_user: Annotated[CurrentUser | None, Depends(get_optional_current_user)] = None,
):
    """
    Dispatch a downlink command down to subscribed IoT hardware devices over MQTT.
    Publishes to topic 'channels/{channel_id}/{subtopic}' (default 'commands').
    """
    await authorize_channel_access(channel_id, "write", x_api_key, current_user, db)

    subtopic = payload.subtopic or "commands"
    topic = f"channels/{channel_id}/{subtopic}"
    body_bytes = orjson.dumps(payload.payload)

    published = await publisher.publish(topic, body_bytes, qos=1)
    if not published:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Broker unavailable")

    return CommandDispatchOut(
        status="dispatched",
        channel_id=channel_id,
        topic=topic,
        payload=payload.payload,
    )


@router.post("/import", response_model=ImportResultOut, status_code=status.HTTP_200_OK)
async def import_telemetry(
    channel_id: int,
    request: Request,
    db: Annotated[asyncpg.Connection, Depends(get_db)],
    x_api_key: Annotated[str | None, Header()] = None,
    current_user: Annotated[CurrentUser | None, Depends(get_optional_current_user)] = None,
):
    """
    Import historical telemetry from CSV data.
    Supports ThingSpeak format (created_at,entry_id,field1,field2...)
    or standard format (time,field,value or time,temp,humidity...).
    """
    await authorize_channel_access(channel_id, "write", x_api_key, current_user, db)

    body_bytes = await request.body()
    try:
        csv_text = body_bytes.decode("utf-8")
    except UnicodeDecodeError:
        try:
            csv_text = body_bytes.decode("latin-1")
        except Exception:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Could not decode CSV text")

    # If payload is JSON with { "csv": "..." }, extract it
    stripped = csv_text.strip()
    if stripped.startswith("{") and stripped.endswith("}"):
        try:
            parsed_json = orjson.loads(stripped)
            if isinstance(parsed_json, dict) and "csv" in parsed_json:
                csv_text = parsed_json["csv"]
        except Exception:
            pass

    reader = csv.reader(io.StringIO(csv_text))
    rows = list(reader)
    if not rows or len(rows) < 2:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="CSV must contain a header row and at least one data row")

    header = [h.strip().lower() for h in rows[0]]

    # Detect time column
    time_idx = None
    for idx, col in enumerate(header):
        if col in ("time", "created_at", "timestamp", "datetime", "date"):
            time_idx = idx
            break
    if time_idx is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No timestamp column found (expected 'time', 'created_at', or 'timestamp')")

    # Check if this is narrow format: time, field, value
    is_narrow = False
    field_col_idx = None
    val_col_idx = None
    if "field" in header and "value" in header:
        is_narrow = True
        field_col_idx = header.index("field")
        val_col_idx = header.index("value")

    # Collect existing fields for this channel
    existing_fields = await db.fetch("SELECT id, key FROM app.channel_fields WHERE channel_id = $1", channel_id)
    field_map = {r["key"]: r["id"] for r in existing_fields}

    async def get_or_create_field_id(key: str) -> int:
        clean_key = re.sub(r'[^A-Za-z0-9_.-]', '_', key)[:64]
        if clean_key in field_map:
            return field_map[clean_key]
        row = await db.fetchrow(
            """
            INSERT INTO app.channel_fields (channel_id, key, label, value_type)
            VALUES ($1, $2, $3, 'number')
            ON CONFLICT (channel_id, key) DO UPDATE SET channel_id = EXCLUDED.channel_id
            RETURNING id;
            """,
            channel_id,
            clean_key,
            clean_key.capitalize(),
        )
        fid = row["id"]
        field_map[clean_key] = fid
        return fid

    def parse_time(val: str) -> datetime:
        val = val.strip().replace(" UTC", "+00:00").replace("Z", "+00:00")
        try:
            return datetime.fromisoformat(val)
        except Exception:
            for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M:%S%z", "%Y-%m-%dT%H:%M:%S", "%Y/%m/%d %H:%M:%S"):
                try:
                    dt = datetime.strptime(val, fmt)
                    if dt.tzinfo is None:
                        dt = dt.replace(tzinfo=timezone.utc)
                    return dt
                except Exception:
                    continue
            raise ValueError(f"Unable to parse timestamp: {val}")

    points_to_insert = []
    discovered_keys = set()

    for row_idx, r in enumerate(rows[1:], start=2):
        if not r or all(not cell.strip() for cell in r):
            continue
        if len(r) <= time_idx:
            continue
        try:
            ts = parse_time(r[time_idx])
        except Exception:
            continue

        if is_narrow:
            if len(r) > max(field_col_idx, val_col_idx):
                fkey = r[field_col_idx].strip()
                try:
                    fval = float(r[val_col_idx].strip())
                except ValueError:
                    continue
                fid = await get_or_create_field_id(fkey)
                discovered_keys.add(fkey)
                points_to_insert.append((ts, channel_id, fid, fval))
        else:
            for c_idx, cell in enumerate(r):
                if c_idx == time_idx:
                    continue
                col_name = header[c_idx]
                if col_name in ("entry_id", "id", "#"):
                    continue
                val_str = cell.strip()
                if not val_str:
                    continue
                try:
                    fval = float(val_str)
                except ValueError:
                    continue
                fid = await get_or_create_field_id(col_name)
                discovered_keys.add(col_name)
                points_to_insert.append((ts, channel_id, fid, fval))

    if points_to_insert:
        await db.copy_records_to_table(
            "points",
            records=points_to_insert,
            columns=["time", "channel_id", "field_id", "value"],
            schema_name="telemetry",
        )

    return ImportResultOut(
        status="imported",
        channel_id=channel_id,
        points_imported=len(points_to_insert),
        fields_discovered=sorted(list(discovered_keys)),
    )
