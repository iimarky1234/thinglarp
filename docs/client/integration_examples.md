# Flutter Integration Guide for ThingLarp IoT Platform

This guide demonstrates how to integrate your Flutter application with the backend:
1. **Authenticate the User** via REST API (JWT).
2. **Fetch Historical Data** to initialize dashboard charts.
3. **Obtain MQTT Session Credentials** (`POST /mqtt/session`).
4. **Subscribe to Live Data** over MQTT (TLS on mobile / WebSockets on Web).

---

## 1. Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  mqtt_client: ^10.4.0
  fl_chart: ^0.68.0 # High-performance charting
```

---

## 2. Authentication & Data Service (`iot_api_service.dart`)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class IotApiService {
  final String baseUrl;
  String? _jwtToken;

  IotApiService({required this.baseUrl});

  // 1. User Login
  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _jwtToken = data['access_token'];
      return true;
    }
    return false;
  }

  // 2. Request Short-Lived MQTT Session Token
  Future<Map<String, dynamic>> requestMqttSession() async {
    final response = await http.post(
      Uri.parse('$baseUrl/mqtt/session'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_jwtToken',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to acquire MQTT session: ${response.body}');
  }

  // 3. Query Historical Points for Charts
  Future<Map<String, dynamic>> getHistoricalData(int channelId, {String resolution = 'auto'}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/channels/$channelId/data?resolution=$resolution'),
      headers: {'Authorization': 'Bearer $_jwtToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load history');
  }
}
```

---

## 3. Real-Time MQTT Client (`iot_mqtt_service.dart`)

```dart
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart'; // Mobile (TCP TLS)
// For Flutter Web, use: import 'package:mqtt_client/mqtt_browser_client.dart';

class IotMqttService {
  final String brokerHost;
  final int port;
  final String username;
  final String password;
  MqttServerClient? _client;

  IotMqttService({
    required this.brokerHost,
    this.port = 8883,
    required this.username,
    required this.password,
  });

  Future<void> connect(int channelId, Function(Map<String, dynamic>) onDataReceived) async {
    _client = MqttServerClient.withPort(brokerHost, 'flutter_${username}', port);
    _client!.secure = true;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 30;

    final connMessage = MqttConnectMessage()
        .authenticateAs(username, password)
        .withClientIdentifier('flutter_${username}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      print('Connecting to MQTT broker at $brokerHost:$port...');
      await _client!.connect();
      print('Connected to MQTT!');

      final topic = 'channels/$channelId/data';
      _client!.subscribe(topic, MqttQos.atLeastOnce);

      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        final recMess = messages[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            onDataReceived(decoded);
          } else if (decoded is List) {
            for (var item in decoded) {
              if (item is Map<String, dynamic>) {
                onDataReceived(item);
              }
            }
          }
        } catch (e) {
          print('Error decoding MQTT packet: $e');
        }
      });
    } catch (e) {
      print('MQTT connection failed: $e');
      _client?.disconnect();
    }
  }

  void disconnect() {
    _client?.disconnect();
  }
}
```

---

## 4. Dashboard Implementation Pattern

```dart
// 1. In initState():
final api = IotApiService(baseUrl: 'https://api.example.com');
await api.login('alex', 'password123');

// 2. Fetch history:
final history = await api.getHistoricalData(channelId);
// Populate initial line chart points...

// 3. Connect live stream:
final session = await api.requestMqttSession();
final mqtt = IotMqttService(
  brokerHost: 'mqtt.example.com',
  port: 8883, // 443 with MqttBrowserClient for Web
  username: session['username'],
  password: session['password'],
);

await mqtt.connect(channelId, (newData) {
  setState(() {
    // Dynamically append new readings to your charts in real-time!
    // Supports any arbitrary field sent by the device (temperature, battery_v, etc.)
  });
});
```
