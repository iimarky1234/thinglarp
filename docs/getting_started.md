# Getting Started with ThingLarp

This guide walks you through setting up your account, creating your first channel, and understanding how data is structured in ThingLarp.

---

## 1. Access the Dashboard

Navigate to **[https://thinglarp.iimarky123.io.vn/app/](https://thinglarp.iimarky123.io.vn/app/)** in any modern web browser.

- If you already have an account, enter your username and password.
- If you are new, click **Register** to create a free account.

---

## 2. Channels Explained

In ThingLarp, a **Channel** is the container for all telemetry sent by your devices or sensors (similar to a project or data stream).

Each channel has:
- **Channel ID**: A unique numeric ID (e.g., `42`) used in API endpoints and MQTT topics.
- **Name & Description**: Human-readable label for your dashboard.
- **Visibility**:
    - **Private** (default): Only you can read or publish telemetry.
    - **Public**: Anyone with the link can view live charts and historical feeds without logging in.

### Creating a Channel
1. In the channels overview screen, click **+ New Channel**.
2. Enter a name (e.g., *Greenhouse Sensor*).
3. Optionally add a description.
4. Toggle **Public Channel** if you want to share real-time telemetry with colleagues or the public.
5. Click **Create**.

---

## 3. Dynamic Field Auto-Discovery

Unlike traditional IoT platforms where you must manually pre-configure `field1`, `field2`, etc., ThingLarp features **dynamic schema discovery**.

When your sensor publishes a JSON payload:
```json
{
  "temp_c": 24.8,
  "humidity_pct": 58.2,
  "soil_moisture": 420
}
```

ThingLarp automatically:
1. Detects each new key (`temp_c`, `humidity_pct`, `soil_moisture`).
2. Registers them as channel fields in the database.
3. Automatically generates responsive UI widgets and real-time line charts on your dashboard.
4. Indexes data into continuous 1-minute and 1-hour aggregate views for instantaneous chart rendering.

---

## 4. Choosing How to Connect Your Device

ThingLarp supports two ingestion methods:

1. **HTTP REST API**:
    - Ideal for microcontrollers or webhooks that send periodic updates over HTTPS (e.g., every 10 seconds or 1 minute).
    - Requires an **API Key** generated from the channel's *API Keys* tab.
    - Read the [HTTP Ingestion Guide](sending_data_http.md).

2. **MQTT Broker**:
    - Ideal for high-speed streaming (1Hz – 100Hz) or battery-conscious edge hardware.
    - Requires **Device Credentials** provisioned from the channel's *Devices* tab.
    - Read the [MQTT Ingestion Guide](sending_data_mqtt.md).
