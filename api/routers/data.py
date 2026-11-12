"""api/routers/data.py: Telemetry data ingestion via MQTT publishing and historical querying."""

import csv
import io
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Response, status
import asyncpg
import orjson

from database import get_db
from mqtt_client import publisher
from schemas import ChannelTelemetryOut, LatestTelemetryOut, TelemetryPoint
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
