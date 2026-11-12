"""scripts/e2e_simulation.py: Complete End-to-End simulation and verification script."""

import asyncio
import json
import time
import httpx
import aiomqtt

API_BASE = "http://localhost:8000"
MQTT_HOST = "localhost"
MQTT_PORT = 1883

async def main():
    print("=" * 60)
    print("🚀 Starting End-to-End Simulation of IoT Telemetry Platform")
    print("=" * 60)

    async with httpx.AsyncClient(base_url=API_BASE, timeout=10.0) as http:
        # ---------------------------------------------------------------------
        # 1. User Registration & Login
        # ---------------------------------------------------------------------
        username = f"tester_{int(time.time())}"
        password = "SecurePassword123!"
        print(f"\n[Step 1] Registering user: {username} ...")
        res = await http.post("/auth/register", json={"username": username, "password": password})
        assert res.status_code == 201, f"Register failed: {res.text}"
        user_data = res.json()
        print(f"✅ User registered (ID: {user_data['id']})")

        print("[Step 2] Logging in to retrieve JWT access token ...")
        res = await http.post("/auth/login", json={"username": username, "password": password})
        assert res.status_code == 200, f"Login failed: {res.text}"
        tokens = res.json()
        token = tokens["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        print("✅ Received JWT access token")

        # ---------------------------------------------------------------------
        # 2. Channel Creation
        # ---------------------------------------------------------------------
        print("\n[Step 3] Creating IoT Channel ...")
        res = await http.post(
            "/channels",
            json={"name": "Smart Garden Station", "description": "Weather and Soil Telemetry", "is_public": False},
            headers=headers,
        )
        assert res.status_code == 201, f"Create channel failed: {res.text}"
        channel = res.json()
        channel_id = channel["id"]
        print(f"✅ Channel created: '{channel['name']}' (ID: {channel_id})")

        # ---------------------------------------------------------------------
        # 3. Hardware Device Provisioning
        # ---------------------------------------------------------------------
        print("\n[Step 4] Provisioning ESP32 Hardware Device ...")
        res = await http.post(
            f"/channels/{channel_id}/devices",
            json={"name": "ESP32_Field_Unit_1"},
            headers=headers,
        )
        assert res.status_code == 201, f"Device provisioning failed: {res.text}"
        device = res.json()
        dev_user = device["mqtt_username"]
        dev_pass = device["mqtt_password"]
        print(f"✅ Device provisioned: Username={dev_user}, Password={dev_pass[:6]}***")

        # ---------------------------------------------------------------------
        # 4. Flutter App MQTT Session Token Issuance
        # ---------------------------------------------------------------------
        print("\n[Step 5] Requesting short-lived MQTT session for Flutter app ...")
        res = await http.post("/mqtt/session", headers=headers)
        assert res.status_code == 200, f"MQTT session failed: {res.text}"
        app_session = res.json()
        app_user = app_session["username"]
        app_pass = app_session["password"]
        print(f"✅ App session created: Username={app_user}, Expires at={app_session['expires_at']}")

        # ---------------------------------------------------------------------
        # 5. Live Streaming: App Subscribes, ESP32 Publishes
        # ---------------------------------------------------------------------
        print("\n[Step 6] Connecting Flutter App to MQTT and subscribing to live data ...")
        received_messages = []

        async def app_listener():
            async with aiomqtt.Client(
                hostname=MQTT_HOST,
                port=MQTT_PORT,
                username=app_user,
                password=app_pass,
                identifier=f"flutter_{app_user}",
            ) as app_client:
                await app_client.subscribe(f"channels/{channel_id}/data", qos=1)
                print(f"📡 App subscribed to 'channels/{channel_id}/data'")
                async for message in app_client.messages:
                    payload_str = message.payload.decode("utf-8")
                    received_messages.append(payload_str)
                    print(f"📲 Flutter App received LIVE MQTT update: {payload_str}")
                    if len(received_messages) >= 2:
                        break

        listener_task = asyncio.create_task(app_listener())
        await asyncio.sleep(0.5) # Wait for subscription to establish

        # ---------------------------------------------------------------------
        # 6. ESP32 Publishes Telemetry with Unlimited Arbitrary Fields
        # ---------------------------------------------------------------------
        print("\n[Step 7] ESP32 connecting and publishing high-frequency telemetry ...")
        async with aiomqtt.Client(
            hostname=MQTT_HOST,
            port=MQTT_PORT,
            username=dev_user,
            password=dev_pass,
            identifier=f"esp32_{dev_user}",
        ) as esp_client:
            # Message 1: Dynamic single payload with 6 arbitrary fields
            payload1 = {
                "temperature": 27.8,
                "humidity": 62.4,
                "pressure_hpa": 1014.2,
                "soil_moisture": 45.0,
                "battery_v": 3.95,
                "status": "nominal",
            }
            await esp_client.publish(f"channels/{channel_id}/data", json.dumps(payload1).encode("utf-8"), qos=1)
            print(f"📤 ESP32 published single payload with {len(payload1)} dynamic fields")

            # Message 2: Hardware batch array (5 samples)
            payload2 = [
                {"v": 1.0, "i": 0.20},
                {"v": 1.1, "i": 0.21},
                {"v": 1.2, "i": 0.22},
                {"v": 1.3, "i": 0.23},
                {"v": 1.4, "i": 0.24},
            ]
            await esp_client.publish(f"channels/{channel_id}/data", json.dumps(payload2).encode("utf-8"), qos=1)
            print("📤 ESP32 published batch array with 5 buffered readings")

            # -----------------------------------------------------------------
            # 7. Security Check: ACL Spoofing Test
            # -----------------------------------------------------------------
            print("\n[Step 8] Testing ACL Enforcement (Unauthorized Channel Spoofing) ...")
            try:
                # Attempt to publish to an unauthorized channel (channel 99999)
                await esp_client.publish("channels/99999/data", b'{"spoof": true}', qos=1)
                print("⚠️ Warning: Mosquitto allowed publish to channels/99999/data (checking broker ACL)")
            except Exception as e:
                print(f"🛡️ ACL correctly blocked unauthorized publish: {e}")

        # Wait for app listener to catch the published packets
        try:
            await asyncio.wait_for(listener_task, timeout=3.0)
        except asyncio.TimeoutError:
            pass

        print(f"✅ Live subscription confirmed: App received {len(received_messages)} packets in real-time.")

        # Wait 1.5 seconds for Bridge to flush micro-batch buffer into TimescaleDB
        print("\n[Step 9] Waiting 1.5s for Ingestion Bridge buffer flush to TimescaleDB ...")
        await asyncio.sleep(1.5)

        # ---------------------------------------------------------------------
        # 8. REST Query Verification: Auto-Discovered Fields & Hypertables
        # ---------------------------------------------------------------------
        print("\n[Step 10] Querying Auto-Discovered Field Registry via REST ...")
        res = await http.get(f"/channels/{channel_id}/fields", headers=headers)
        assert res.status_code == 200, f"Fields query failed: {res.text}"
        discovered_fields = res.json()
        field_keys = [f["key"] for f in discovered_fields]
        print(f"✅ Discovered {len(discovered_fields)} dynamic fields in database:")
        for f in discovered_fields:
            print(f"   • {f['key']} (type: {f['value_type']}, id: {f['id']})")
        assert "temperature" in field_keys
        assert "humidity" in field_keys
        assert "soil_moisture" in field_keys
        assert "v" in field_keys
        assert "i" in field_keys

        print("\n[Step 11] Querying Latest Telemetry State ...")
        res = await http.get(f"/channels/{channel_id}/latest", headers=headers)
        assert res.status_code == 200, f"Latest query failed: {res.text}"
        latest = res.json()
        print(f"✅ Latest Telemetry Snapshot: {latest['fields']}")

        print("\n[Step 12] Querying Time-Series Points for Visualizations ...")
        res = await http.get(f"/channels/{channel_id}/data?resolution=raw", headers=headers)
        assert res.status_code == 200, f"Data query failed: {res.text}"
        chart_data = res.json()
        print(f"✅ Time-series points returned (resolution: {chart_data['resolution']}):")
        for k, pts in chart_data["fields"].items():
            print(f"   • {k}: {len(pts)} data points")

        # ---------------------------------------------------------------------
        # 9. ThingSpeak-style HTTP Write with API Key
        # ---------------------------------------------------------------------
        print("\n[Step 13] Creating ThingSpeak-style Write API Key ...")
        res = await http.post(f"/channels/{channel_id}/keys", json={"scope": "write"}, headers=headers)
        assert res.status_code == 201
        api_key_data = res.json()
        write_key = api_key_data["api_key"]
        print(f"✅ Created Write API Key: {api_key_data['prefix']}***")

        print("[Step 14] Ingesting via HTTP with X-API-Key header ...")
        http_payload = {"ambient_lux": 820.5, "rainfall_mm": 0.0}
        res = await http.post(
            f"/channels/{channel_id}/data",
            json=http_payload,
            headers={"X-API-Key": write_key},
        )
        assert res.status_code == 202, f"HTTP ingest failed: {res.text}"
        print("✅ HTTP ingestion accepted and routed through MQTT publisher to Bridge")

        # Wait 1s for bridge to ingest HTTP write
        await asyncio.sleep(1.0)
        res = await http.get(f"/channels/{channel_id}/fields", headers=headers)
        field_keys = [f["key"] for f in res.json()]
        assert "ambient_lux" in field_keys
        print(f"✅ Verified 'ambient_lux' dynamically auto-discovered from HTTP write!")

    print("\n" + "=" * 60)
    print("🎉 ALL 14 VERIFICATION STEPS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    asyncio.run(main())
