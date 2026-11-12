# MQTT Topics & Authorization Matrix

This document outlines the MQTT topic structure and topic-level access control rules enforced by `mosquitto-go-auth` and `mqtt.acl_topics()`.

---

## Topic Naming Conventions

All MQTT topics follow strict hierarchical namespaces:

```
channels/
└── {channel_id}/
    ├── data       # High-frequency JSON sensor telemetry
    ├── command    # Downlink actuator commands (Future)
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
| `channels/{id}/data` | Hardware Device (`d_*`) | **Write (`2`)** | Device is mapped to channel `{id}` in `app.devices`. |
| `channels/{id}/data` | User Frontend Session (`s_*`) | **Sub (`4`)**, **Read (`1`)** | Channel `{id}` is owned by user or has `is_public = true`. |
| `channels/{id}/status` | Hardware Device (`d_*`) | **Write (`2`)** | Device is mapped to channel `{id}`. Used for LWT messages. |
| `channels/{id}/status` | User Frontend Session (`s_*`) | **Sub (`4`)**, **Read (`1`)** | Same as data channel. |
| `$share/ingest/channels/+/data` | Service Account (`svc_bridge`) | **Sub (`4`)** | Dedicated ingestion bridge shared group. |
| `#` (All Topics) | Service Account (`svc_bridge`) | **Read (`1`)** | Superuser flag active. |
| `#` (All Topics) | Service Account (`svc_api`) | **Write (`2`)** | Superuser flag active for HTTP forwarding. |

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
