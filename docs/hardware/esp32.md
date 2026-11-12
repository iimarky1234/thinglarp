# ESP32 / Arduino C++ Integration

This guide provides complete, production-ready Arduino C++ code to stream sensor data from an **ESP32** or **ESP8266** to ThingLarp using WiFi and MQTT.

---

## Required Libraries

Install via the Arduino Library Manager:
- **`PubSubClient`** by Nick O'Leary
- **`ArduinoJson`** (v6 or v7) by Benoît Blanchon

---

## Complete Arduino C++ Code

```cpp
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASS     = "YOUR_WIFI_PASSWORD";

const char* MQTT_BROKER   = "mqtt.iimarky123.io.vn";
const int   MQTT_PORT     = 8883;

// Device credentials from ThingLarp Dashboard -> Devices tab
const char* MQTT_USER     = "d_YOUR_DEVICE_USER";
const char* MQTT_PASS     = "YOUR_DEVICE_PASSWORD";

const int   CHANNEL_ID    = 42; // Replace with your Channel ID
const char* DATA_TOPIC    = "channels/42/data";

// -----------------------------------------------------------------------------
// Networking
// -----------------------------------------------------------------------------
WiFiClientSecure net;
PubSubClient client(net);
unsigned long lastPublish = 0;

void setupWifi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected! IP: " + WiFi.localIP().toString());

  // Insecure mode for simple deployments without bundle cert
  net.setInsecure();
}

void reconnectMqtt() {
  while (!client.connected()) {
    Serial.print("Connecting to ThingLarp MQTT...");
    String clientId = "ESP32_" + String(random(0xffff), HEX);

    if (client.connect(clientId.c_str(), MQTT_USER, MQTT_PASS)) {
      Serial.println(" Connected!");
    } else {
      Serial.print(" Failed, rc=");
      Serial.print(client.state());
      Serial.println(" Retrying in 5 seconds...");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  setupWifi();
  client.setServer(MQTT_BROKER, MQTT_PORT);
}

void loop() {
  if (!client.connected()) {
    reconnectMqtt();
  }
  client.loop();

  // Publish sensor reading every 5 seconds
  if (millis() - lastPublish > 5000) {
    lastPublish = millis();

    // Read your sensors here
    float temp = 25.0 + (random(-20, 20) / 10.0);
    float humidity = 60.0 + (random(-50, 50) / 10.0);
    int lightRaw = analogRead(34);

    // Build JSON payload
    StaticJsonDocument<200> doc;
    doc["temperature"] = temp;
    doc["humidity"] = humidity;
    doc["light_adc"] = lightRaw;

    char buffer[256];
    serializeJson(doc, buffer);

    Serial.print("Publishing: ");
    Serial.println(buffer);
    client.publish(DATA_TOPIC, buffer, false);
  }
}
```
