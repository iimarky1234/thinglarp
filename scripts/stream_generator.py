#!/home/iimarky123/Projects/thinglarp-fr/.venv/bin/python
"""scripts/stream_generator.py: Live sensor data stream simulator for ThingLarp IoT platform."""

import argparse
import asyncio
import json
import math
import random
import sys
import time
import httpx
import aiomqtt

API_BASE = "http://localhost:8000"
MQTT_HOST = "localhost"
MQTT_PORT = 1883


async def run_mqtt_stream(channel_id: int, username: str, password: str, interval: float, count: int | None):
    topic = f"channels/{channel_id}/data"
    print(f"\n📡 Connecting to MQTT broker {MQTT_HOST}:{MQTT_PORT} as {username}...")

    step = 0
    async with aiomqtt.Client(hostname=MQTT_HOST, port=MQTT_PORT, username=username, password=password) as client:
        print(f"✅ Connected to broker! Publishing telemetry to topic '{topic}' every {interval}s")
        print("Press Ctrl+C to stop.\n")

        while count is None or step < count:
            t = time.time()
            step += 1

            # Generate dynamic fluctuating metrics
            temp = round(23.5 + 4.0 * math.sin(step * 0.1) + random.uniform(-0.3, 0.3), 2)
            humidity = round(55.0 + 8.0 * math.cos(step * 0.08) + random.uniform(-0.5, 0.5), 1)
            pressure = round(1013.25 + 2.0 * math.sin(step * 0.05) + random.uniform(-0.1, 0.1), 2)
            voltage = round(3.7 + random.uniform(-0.02, 0.02), 3)
            light = round(max(0, 450.0 + 200.0 * math.sin(step * 0.15) + random.uniform(-20, 20)), 1)
            rssi = round(-65 + random.uniform(-5, 5), 0)

            payload = {
                "temperature": temp,
                "humidity": humidity,
                "pressure": pressure,
                "voltage": voltage,
                "light_lux": light,
                "rssi": rssi,
                "seq": step,
            }

            raw = json.dumps(payload)
            await client.publish(topic, payload=raw, qos=0)
            print(f"[{time.strftime('%H:%M:%S')}] #{step:04d} -> Temp: {temp}°C | Humidity: {humidity}% | Pressure: {pressure}hPa | Light: {light}lux")

            await asyncio.sleep(interval)


async def run_http_stream(channel_id: int, write_key: str, interval: float, count: int | None):
    print(f"\n🌐 Streaming telemetry via HTTP Ingest to channel {channel_id} using Write API Key...")
    step = 0
    headers = {"X-API-Key": write_key}

    async with httpx.AsyncClient(base_url=API_BASE, timeout=5.0) as http:
        while count is None or step < count:
            step += 1
            temp = round(24.0 + 3.0 * math.sin(step * 0.1) + random.uniform(-0.2, 0.2), 2)
            humidity = round(52.0 + 5.0 * math.cos(step * 0.08) + random.uniform(-0.4, 0.4), 1)

            payload = {
                "temperature": temp,
                "humidity": humidity,
                "voltage": 3.72,
                "step": step,
            }

            res = await http.post(f"/channels/{channel_id}/data", json=payload, headers=headers)
            if res.status_code == 200:
                print(f"[{time.strftime('%H:%M:%S')}] HTTP #{step:04d} (200 OK) -> Temp: {temp}°C | Humidity: {humidity}%")
            else:
                print(f"[{time.strftime('%H:%M:%S')}] HTTP #{step:04d} Error {res.status_code}: {res.text}")

            await asyncio.sleep(interval)


def parse_args():
    parser = argparse.ArgumentParser(description="ThingLarp Live Telemetry Stream Generator")
    parser.add_argument("--channel", type=int, required=True, help="Channel ID to publish to")
    parser.add_argument("--interval", type=float, default=1.5, help="Interval between messages in seconds (default: 1.5)")
    parser.add_argument("--count", type=int, default=None, help="Number of messages to send (default: continuous)")
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--device", nargs=2, metavar=("USERNAME", "PASSWORD"), help="Device MQTT username and password")
    group.add_argument("--key", type=str, help="Channel Write API Key for HTTP ingestion")

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    try:
        if args.device:
            asyncio.run(run_mqtt_stream(args.channel, args.device[0], args.device[1], args.interval, args.count))
        else:
            asyncio.run(run_http_stream(args.channel, args.key, args.interval, args.count))
    except KeyboardInterrupt:
        print("\n🛑 Stream stopped by user.")
        sys.exit(0)
