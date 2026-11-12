# MQTT Topics & Authorization Matrix

This document outlines the MQTT topic structure and topic-level access control rules enforced by `mosquitto-go-auth` and `mqtt.acl_topics()`.

---

## Topic Naming Conventions

All MQTT topics follow strict hierarchical namespaces:

```
channels/
└── {channel_id}/
    ├── data       # High-frequency JSON sensor telemetry
    ├── commands   # Downlink actuator commands (relays, triggers, configs)
    └── status     # Last Will and Testament (LWT) & online status
```

---

## Authorization Permission Matrix

`mosquitto-go-auth` passes an integer access flag into PostgreSQL:
- **`1`** = Read
- **`2`** = Write
- **`4`** = Subscribe

| Topic Pattern | Client Identity | Allowed Operations | Condition / Evaluation Logic |
| :--- | :--- | :--- | :--- |
| `channels/{id}/data` | Hardware Device (`d_*`) | **Write (`2`)** | Device is active (`is_active = true`) and scope is `publish` or `pubsub`. |
| `channels/{id}/data` | Hardware Device (`d_*`) | **Sub (`4`)**, **Read (`1`)** | Device is active and scope is `subscribe` or `pubsub`. |
| `channels/{id}/commands` | Hardware Device (`d_*`) | **Sub (`4`)**, **Read (`1`)** | Device is active and scope is `subscribe` or `pubsub`. Receives downlink control payloads. |
| `channels/{id}/status` | Hardware Device (`d_*`) | **Write (`2`)** | Device is active and scope is `publish` or `pubsub`. Used for LWT messages. |
| `channels/{id}/data` | User Frontend Session (`s_*`) | **Sub (`4`)**, **Read (`1`)** | Channel `{id}` is owned by user or has `is_public = true`. |
| `channels/{id}/status` | User Frontend Session (`s_*`) | **Sub (`4`)**, **Read (`1`)** | Same as data channel. |
| `channels/{id}/commands` | API Service Account (`svc_api`) | **Write (`2`)** | Dispatches HTTP command requests to MQTT. |
| `$share/ingest/channels/+/data` | Ingestion Bridge (`svc_bridge`) | **Sub (`4`)** | Dedicated ingestion bridge shared consumer group. |
| `#` (All Topics) | Service Accounts (`svc_bridge`, `svc_api`) | Superuser | System services bypass topic checks. |

---

## Example Ingestion Payloads

Payloads published to `channels/{id}/data` must be valid JSON objects. Numeric values are automatically cataloged as discrete time-series points:

```json
{
  "temp_c": 22.45,
  "humidity_rh": 58.1,
  "lux": 340.0,
  "vibration": 0.003,
  "metadata": {
    "node_fw": "v1.4.2",
    "boot_count": 12
  }
}
```

- `temp_c`, `humidity_rh`, `lux`, and `vibration` are parsed into individual time-series entries in `telemetry.points`.
- The entire JSON payload (including `metadata`) is preserved verbatim in `telemetry.messages`.
