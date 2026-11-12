# Downlink Commands (Device Control)

ThingLarp allows you to send downlink control messages from the Web Dashboard or API directly to edge devices (e.g. toggling relays, updating sensor sample intervals, or triggering reboots).

---

## 1. Device Setup for Downlinks

When provisioning your device in the dashboard:
- Ensure the access scope is set to **Subscribe (Sub)** or **Pub/Sub**.
- Devices with *Publish-only* scope cannot subscribe to downlink topics.

### Device Topic to Subscribe:
```text
channels/{channel_id}/commands
```

---

## 2. Sending a Command from the Dashboard

1. Open your channel in the [Web Dashboard](https://thinglarp.iimarky123.io.vn/app/).
2. In the top action bar, click the **Downlink Commands** icon (`📲`).
3. Select the target device (or `all`), enter the command name (e.g., `relay_1`) and parameters (`{"state": "ON"}`).
4. Click **Dispatch Command**.

---

## 3. Sending a Command via HTTP API

You can trigger a downlink programmatically via HTTP:

```bash
curl -X POST "https://api.iimarky123.io.vn/channels/42/commands" \
  -H "X-API-Key: tl_ak_YOUR_API_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "command": "set_interval",
    "params": {"interval_sec": 10},
    "target_device": "esp32_node_1"
  }'
```

---

## 4. Handling Commands on ESP32 (Arduino C++)

```cpp
void onMessage(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println("Command received: " + message);

  StaticJsonDocument<200> doc;
  deserializeJson(doc, message);

  const char* cmd = doc["command"];
  if (strcmp(cmd, "relay_1") == 0) {
    bool state = doc["params"]["state"] == "ON";
    digitalWrite(LED_BUILTIN, state ? HIGH : LOW);
  }
}

void setup() {
  // ... wifi setup ...
  client.setCallback(onMessage);
  client.subscribe("channels/42/commands");
}
```
