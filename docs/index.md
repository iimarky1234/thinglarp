# ThingLarp Documentation

Welcome to **ThingLarp**, a fast, unconstrained IoT telemetry platform built as an open modern alternative to ThingSpeak.

ThingLarp lets you connect microcontrollers, sensors, and hardware devices to ingest data over standard **HTTP REST** or **MQTT**, store time-series metrics with zero rate limits, and visualize your feeds on a real-time web dashboard.

---

## Why ThingLarp?

| Feature | Legacy IoT Platforms | ThingLarp |
| :--- | :--- | :--- |
| **Update Rate Limit** | 1 update every 15–60 seconds | **Zero artificial rate limits** (stream up to 100Hz) |
| **Field Constraints** | Rigid 8 fields (`field1`...`field8`) | **Unlimited dynamic JSON fields** (auto-discovered) |
| **Visualizations** | Static charts | **Real-time live streaming** (QoS 1 WebSockets / MQTT) |
| **Public Sharing** | Complex or locked | **1-click public share links** for any browser |
| **Downlink Control** | Paid addon | **Built-in hardware commands** |

---

## 3-Minute Quickstart

Getting sensor readings streaming into ThingLarp takes 3 simple steps:

### 1. Create a Channel
Open the [ThingLarp Web Dashboard](https://thinglarp.iimarky123.io.vn/app/), sign in, and click **+ New Channel**. Give it a name like *"Weather Station"*.

### 2. Get an API Key or Device Credentials
- **For HTTP REST**: Open your channel, go to the **API Keys** tab, and copy your channel's API key.
- **For MQTT**: Go to the **Devices** tab, click **Provision Device**, and save the generated MQTT username (`d_xxxx`) and password.

### 3. Send Telemetry
Send a JSON payload with your sensor readings:

=== "cURL (HTTP)"
    ```bash
    curl -X POST https://api.iimarky123.io.vn/channels/YOUR_CHANNEL_ID/data \
      -H "X-API-Key: YOUR_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"temperature": 25.4, "humidity": 62.1, "pressure_hpa": 1013.2}'
    ```

=== "Python (HTTP)"
    ```python
    import requests

    requests.post(
        "https://api.iimarky123.io.vn/channels/YOUR_CHANNEL_ID/data",
        headers={"X-API-Key": "YOUR_API_KEY"},
        json={"temperature": 25.4, "humidity": 62.1, "pressure_hpa": 1013.2}
    )
    ```

=== "MQTT (CLI)"
    ```bash
    mosquitto_pub -h mqtt.iimarky123.io.vn -p 8883 \
      -u "YOUR_DEVICE_USER" -P "YOUR_DEVICE_PASS" \
      -t "channels/YOUR_CHANNEL_ID/data" \
      -m '{"temperature": 25.4, "humidity": 62.1}'
    ```

---

## Explore the Guides

- **[Quickstart & First Steps](getting_started.md)**: Account setup, channel management, and field options.
- **[Web Dashboard](dashboard.md)**: Real-time charts, widget customization, and CSV export.
- **[Public Link Sharing](public_sharing.md)**: Sharing live telemetry with anyone on the web.
- **[HTTP Ingestion](sending_data_http.md)**: Complete guide to sending data using HTTP REST API.
- **[MQTT Ingestion](sending_data_mqtt.md)**: High-speed telemetry streaming with MQTT.
- **[Hardware Examples](hardware/esp32.md)**: Arduino C++ (ESP32/ESP8266), MicroPython, and Python code.
- **[REST API Reference](reference/api_reference.md)**: Detailed endpoints, queries, and responses.
