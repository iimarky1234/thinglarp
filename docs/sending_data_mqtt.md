# MQTT Ingestion

For high-frequency sensor streams (1Hz–100Hz) or battery-powered microcontrollers, **MQTT** provides low network overhead, instant delivery, and bidirectional communication.

---

## Connection Parameters

| Parameter | Production Value | Description |
| :--- | :--- | :--- |
| **Broker Host** | `mqtt.iimarky123.io.vn` | Domain for the MQTT broker |
| **TCP Port (TLS)** | `8883` | Secure TLS connection for ESP32 & native apps |
| **WebSocket Port** | `443` | Secure WSS (`/mqtt`) for web browsers |
| **Username** | `d_xxxxxxxxx` | Device-specific username provisioned in your channel |
| **Password** | *(random 32-char token)* | Generated during device provisioning |
| **Telemetry Topic** | `channels/{channel_id}/data` | Topic to publish sensor JSON readings |
| **QoS Level** | `0` or `1` | QoS 1 recommended for guaranteed delivery |

---

## Provisioning a Device

1. Open your channel in the [Web Dashboard](https://thinglarp.iimarky123.io.vn/app/).
2. Select the **Devices** tab.
3. Click **Provision New Device**.
4. Choose an access scope:
   - **Publish (Pub)**: Device can only publish sensor readings.
   - **Pub/Sub**: Device can publish telemetry and receive downlink commands.
5. Click **Generate Credentials** and copy the username and password.

---

## Publishing Telemetry

Publish a standard JSON object to:
```text
channels/{channel_id}/data
```

### CLI Example with mosquitto_pub

```bash
mosquitto_pub \
  -h mqtt.iimarky123.io.vn \
  -p 8883 \
  -u "d_YOUR_DEVICE_USER" \
  -P "YOUR_DEVICE_PASS" \
  -t "channels/42/data" \
  -m '{"rpm": 1250, "vibration_g": 0.042, "current_a": 3.12}' \
  -q 1
```

Once published, the data is ingested into TimescaleDB within milliseconds and pushed to all active web and mobile viewers listening on that channel.
