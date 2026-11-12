# Flutter Client Application

The **ThingLarp App** (`app/`) is a cross-platform client developed with Flutter 3.x that runs on **Linux Desktop**, **macOS**, **Windows**, **Android**, **iOS**, and **Web**.

---

## Key Features

- **Dynamic Endpoints:** Configure custom API endpoints and MQTT broker addresses on the fly with persistent local storage (`SharedPreferences`).
- **Interactive Time-Series Visualizations:** Line charts powered by `fl_chart` with touch tooltips, dynamic multi-field coloring, and time-axis formatting.
- **Dynamic Field Auto-Discovery:** Badges and metric cards dynamically spawn as incoming JSON packets reveal new keys.
- **Real-Time MQTT Streaming:** Direct subscription to live channel topics (`channels/{id}/data`) using ephemeral session tokens.
- **Resolution Selector:** Toggle between **Auto**, **Raw**, **1-Minute**, and **1-Hour** historical aggregations.
- **Hardware & Key Management:** Provision new device credentials and issue HTTP Read/Write API keys with one click.

---

## Application Structure

```
app/lib/
├── config.dart                     # AppConfig: API & MQTT endpoint persistence
├── models/
│   ├── user.dart                   # AuthToken & User profile models
│   ├── channel.dart                # Channel, Device, & ApiKey models
│   └── telemetry.dart              # TelemetryPoint, TimeSeries, & TelemetryMessage
├── services/
│   ├── api_service.dart            # HTTP client managing JWT headers & requests
│   └── mqtt_service.dart           # MQTT stream consumer subscribing to live channels
├── providers/
│   ├── auth_provider.dart          # Session state, login, register, logout
│   └── channel_provider.dart       # Channel list, telemetry history, & live updates
├── views/
│   ├── settings_screen.dart        # Host / Port / API endpoint configuration
│   ├── login_screen.dart           # Sign In & Registration forms
│   ├── channels_screen.dart        # Channel list cards & channel creation modal
│   └── channel_detail_screen.dart  # Channel dashboard: Charts, Messages, Devices, Keys
└── main.dart                       # App initialization with Dark/Light theme
```

---

## Building and Running

### Prerequisites
- Flutter SDK 3.24+ (Dart 3.5+)
- Linux Desktop dependencies: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.

### Running on Linux Desktop
```bash
cd app/
flutter run -d linux
```

### Running on Web
```bash
cd app/
flutter run -d chrome
```

### Compiling a Release Binary
=== "Linux Desktop"
    ```bash
    flutter build linux --release
    # Binary output: app/build/linux/x64/release/bundle/thinglarp_app
    ```

=== "Web Bundle"
    ```bash
    flutter build web --release
    # Static output: app/build/web/
    ```

=== "Android APK"
    ```bash
    flutter build apk --release
    ```

---

## State Management (`Provider`)

The application uses Flutter's `provider` architecture:

```mermaid
graph TD
    UserAction["User Action / UI Event"] -->|"Call Method"| Provider["AuthProvider / ChannelProvider"]
    Provider -->|"HTTP Request"| ApiService["ApiService"]
    Provider -->|"Stream Subscription"| MqttService["MqttService"]
    ApiService -->|"REST Response"| Provider
    MqttService -->|"Live Packet"| Provider
    Provider -->|"notifyListeners()"| UIWidgets["ChannelDetailScreen / Charts"]
```
