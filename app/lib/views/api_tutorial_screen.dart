import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/channel.dart';
import '../providers/channel_provider.dart';

class ApiTutorialScreen extends StatefulWidget {
  final Channel? channel;
  final int initialTabIndex;

  const ApiTutorialScreen({
    super.key,
    this.channel,
    this.initialTabIndex = 0,
  });

  @override
  State<ApiTutorialScreen> createState() => _ApiTutorialScreenState();
}

class _ApiTutorialScreenState extends State<ApiTutorialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Channel? _selectedChannel;
  String _activeApiKey = '';
  List<ApiKeyItem> _apiKeys = [];
  bool _isLoadingKeys = false;

  // Live Tester State
  final _testPayloadController = TextEditingController(
    text: '{\n  "temperature": 24.5,\n  "humidity": 62.0,\n  "battery_pct": 98\n}',
  );
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _selectedChannel = widget.channel;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final channels = context.read<ChannelProvider>().channels;
      if (_selectedChannel == null && channels.isNotEmpty) {
        setState(() {
          _selectedChannel = channels.first;
        });
      }
      if (_selectedChannel != null) {
        _loadKeysForChannel(_selectedChannel!.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _testPayloadController.dispose();
    super.dispose();
  }

  Future<void> _loadKeysForChannel(int channelId) async {
    setState(() => _isLoadingKeys = true);
    try {
      final keys = await context.read<ChannelProvider>().apiService.getApiKeys(channelId);
      if (mounted) {
        setState(() {
          _apiKeys = keys;
          if (keys.isNotEmpty && _activeApiKey.isEmpty) {
            _activeApiKey = keys.first.apiKey ?? 'tl_write_sample_key';
          }
          _isLoadingKeys = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingKeys = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text('Copied $label to clipboard!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int get _channelId => _selectedChannel?.id ?? 1;
  String get _channelName => _selectedChannel?.name ?? 'My Channel';
  String get _apiBase => AppConfig().apiUrl;
  String get _mqttHost => AppConfig().mqttHost;
  int get _mqttPort => AppConfig().mqttPort;
  String get _keyPlaceholder =>
      _activeApiKey.isNotEmpty ? _activeApiKey : 'tl_write_your_api_key_here';

  @override
  Widget build(BuildContext context) {
    final channels = context.watch<ChannelProvider>().channels;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.integration_instructions_outlined, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text('API & Integration Tutorial'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.rocket_launch_outlined), text: 'Quickstart'),
            Tab(icon: Icon(Icons.upload_file_outlined), text: 'Send Data (HTTP)'),
            Tab(icon: Icon(Icons.download_outlined), text: 'Read Data (HTTP)'),
            Tab(icon: Icon(Icons.bolt_outlined), text: 'MQTT Streaming'),
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Live Tester'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Channel & Endpoint Context Bar
          _buildContextBar(channels),
          const Divider(height: 1),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuickstartTab(),
                _buildHttpIngestTab(),
                _buildHttpQueryTab(),
                _buildMqttTab(),
                _buildLiveTesterTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBar(List<Channel> channels) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sensors, size: 20, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              const Text('Active Channel: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (channels.isEmpty)
                Text('Channel #$_channelId', style: const TextStyle(fontWeight: FontWeight.w600))
              else
                DropdownButton<Channel>(
                  value: _selectedChannel != null && channels.any((c) => c.id == _selectedChannel!.id)
                      ? channels.firstWhere((c) => c.id == _selectedChannel!.id)
                      : (channels.isNotEmpty ? channels.first : null),
                  isDense: true,
                  underline: const SizedBox(),
                  items: channels.map((c) {
                    return DropdownMenuItem<Channel>(
                      value: c,
                      child: Text('${c.name} (ID: ${c.id})', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (ch) {
                    if (ch != null) {
                      setState(() {
                        _selectedChannel = ch;
                        _activeApiKey = '';
                      });
                      _loadKeysForChannel(ch.id);
                    }
                  },
                ),
            ],
          ),
          if (_apiKeys.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key, size: 18, color: Colors.amberAccent),
                const SizedBox(width: 6),
                const Text('Active Key: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<String>(
                  value: _apiKeys.any((k) => (k.apiKey ?? k.prefix) == _activeApiKey)
                      ? _activeApiKey
                      : (_apiKeys.first.apiKey ?? _apiKeys.first.prefix),
                  isDense: true,
                  underline: const SizedBox(),
                  items: _apiKeys.map((k) {
                    final keyVal = k.apiKey ?? k.prefix;
                    return DropdownMenuItem<String>(
                      value: keyVal,
                      child: Text('${k.scope.toUpperCase()} (${k.prefix}***)', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (newKey) {
                    if (newKey != null) {
                      setState(() => _activeApiKey = newKey);
                    }
                  },
                ),
              ],
            )
          else if (_isLoadingKeys)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'API Base: $_apiBase',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: Quickstart Guide
  // ===========================================================================
  Widget _buildQuickstartTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: Colors.blue.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to the ThingLarp Developer API!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ThingLarp allows microcontrollers, servers, and scripts to ingest telemetry without rate limits or strict field limits. Choose between simple HTTP POST (webhooks, scripts) or high-speed MQTT (ESP32, microcontrollers).',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Four Steps to Telemetry Streaming',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildStepCard(
          step: '1',
          title: 'Create a Channel',
          description:
              'A channel acts as a container for your data streams (e.g., "Living Room Weather" or "Solar Inverter"). Every channel has a unique Channel ID (currently #$_channelId: "$_channelName").',
          icon: Icons.create_new_folder_outlined,
        ),
        _buildStepCard(
          step: '2',
          title: 'Generate an API Key or Device Credential',
          description:
              'For HTTP REST requests, generate a Write API Key in the "API Keys" tab. For MQTT microcontrollers, provision a Device to obtain a dedicated username and password.',
          icon: Icons.key_outlined,
        ),
        _buildStepCard(
          step: '3',
          title: 'Send JSON Telemetry Packets',
          description:
              'Send any arbitrary JSON payload (e.g. {"temp": 24.5, "pressure_kpa": 101.3}). You don\'t need to declare fields in advance—ThingLarp automatically discovers and graphs them!',
          icon: Icons.send_outlined,
        ),
        _buildStepCard(
          step: '4',
          title: 'Visualize & Export Data',
          description:
              'Watch incoming readings update live on your Flutter dashboard in real time, or query historical aggregations with auto-downsampling (raw, 1-minute, 1-hour).',
          icon: Icons.auto_graph_outlined,
        ),
        const SizedBox(height: 20),
        const Text(
          'HTTP REST vs. MQTT Protocol Comparison',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildComparisonTable(),
      ],
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(step, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: Colors.cyanAccent),
                      const SizedBox(width: 6),
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        children: const [
          TableRow(
            decoration: BoxDecoration(color: Colors.black26),
            children: [
              Padding(
                padding: EdgeInsets.all(10),
                child: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text('HTTP REST API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Padding(
                padding: EdgeInsets.all(10),
                child: Text('MQTT Ingestion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          TableRow(
            children: [
              Padding(padding: EdgeInsets.all(10), child: Text('Ideal For', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              Padding(padding: EdgeInsets.all(10), child: Text('Webhooks, Cron jobs, Python scripts, Cloud', style: TextStyle(fontSize: 12))),
              Padding(padding: EdgeInsets.all(10), child: Text('ESP32, Arduino, MicroPython, Embedded IoT', style: TextStyle(fontSize: 12))),
            ],
          ),
          TableRow(
            children: [
              Padding(padding: EdgeInsets.all(10), child: Text('Authentication', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              Padding(padding: EdgeInsets.all(10), child: Text('X-API-Key header or Bearer JWT', style: TextStyle(fontSize: 12))),
              Padding(padding: EdgeInsets.all(10), child: Text('Device Username & Password (Bcrypt)', style: TextStyle(fontSize: 12))),
            ],
          ),
          TableRow(
            children: [
              Padding(padding: EdgeInsets.all(10), child: Text('Streaming Speed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              Padding(padding: EdgeInsets.all(10), child: Text('1–10 Hz (New TCP connection per write)', style: TextStyle(fontSize: 12))),
              Padding(padding: EdgeInsets.all(10), child: Text('50–100 Hz+ (Persistent socket connection)', style: TextStyle(fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: Send Data (HTTP Ingestion)
  // ===========================================================================
  Widget _buildHttpIngestTab() {
    final curlSnippet = '''curl -X POST "$_apiBase/channels/$_channelId/data" \\
  -H "Content-Type: application/json" \\
  -H "X-API-Key: $_keyPlaceholder" \\
  -d '{
    "temperature": 25.4,
    "humidity": 58.2,
    "battery_v": 3.75,
    "status": "online"
  }\'''';

    final pythonSnippet = '''import requests
import json

URL = "$_apiBase/channels/$_channelId/data"
API_KEY = "$_keyPlaceholder"

payload = {
    "temperature": 25.4,
    "humidity": 58.2,
    "battery_v": 3.75,
    "status": "online"
}

headers = {
    "Content-Type": "application/json",
    "X-API-Key": API_KEY,
}

response = requests.post(URL, headers=headers, json=payload)
print(f"Status: {response.status_code}, Body: {response.json()}")''';

    final jsSnippet = '''const url = "$_apiBase/channels/$_channelId/data";
const apiKey = "$_keyPlaceholder";

const payload = {
  temperature: 25.4,
  humidity: 58.2,
  battery_v: 3.75,
  status: "online"
};

async function sendTelemetry() {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-Key": apiKey
    },
    body: JSON.stringify(payload)
  });

  const result = await response.json();
  console.log("Telemetry sent:", result);
}

sendTelemetry();''';

    final esp32Snippet = '''#include <WiFi.h>
#include <HTTPClient.h>

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

const char* serverUrl = "$_apiBase/channels/$_channelId/data";
const char* apiKey = "$_keyPlaceholder";

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\\nWiFi connected!");
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-API-Key", apiKey);

    // Read real sensor values or send simulated values:
    float temp = 24.5 + (random(-10, 10) / 10.0);
    float hum = 60.0 + (random(-20, 20) / 10.0);

    String payload = "{\\"temperature\\":" + String(temp, 2) +
                     ",\\"humidity\\":" + String(hum, 2) +
                     ",\\"status\\":\\"active\\"}";

    int httpCode = http.POST(payload);
    Serial.printf("POST status code: %d\\n", httpCode);
    http.end();
  }
  delay(5000); // Send telemetry every 5 seconds
}''';

    final micropythonSnippet = '''import urequests
import ujson
import time

URL = "$_apiBase/channels/$_channelId/data"
API_KEY = "$_keyPlaceholder"

headers = {
    "Content-Type": "application/json",
    "X-API-Key": API_KEY
}

data = {
    "temperature": 23.8,
    "humidity": 65.2,
    "firmware": "v1.2.0"
}

res = urequests.post(URL, headers=headers, data=ujson.dumps(data))
print("Response:", res.status_code, res.text)
res.close()''';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEndpointBanner(
          method: 'POST',
          path: '/channels/$_channelId/data',
          description: 'Ingest telemetry with dynamic field auto-discovery and zero rate limits.',
        ),
        const SizedBox(height: 16),
        _buildCodeSection('cURL (Terminal / Bash)', curlSnippet),
        const SizedBox(height: 16),
        _buildCodeSection('Python (requests)', pythonSnippet),
        const SizedBox(height: 16),
        _buildCodeSection('JavaScript (fetch / Node.js)', jsSnippet),
        const SizedBox(height: 16),
        _buildCodeSection('ESP32 Arduino (C++)', esp32Snippet),
        const SizedBox(height: 16),
        _buildCodeSection('MicroPython (ESP32 / Raspberry Pi Pico W)', micropythonSnippet),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: Read Data (HTTP Query)
  // ===========================================================================
  Widget _buildHttpQueryTab() {
    final curlHistoryFeeds = '''# 1. Fetch Channel History (specify exact number of data entries you want)
curl -X GET "$_apiBase/channels/$_channelId/history?limit=10&order=desc" \\
  -H "X-API-Key: $_keyPlaceholder"

# 2. Fetch Single Latest Reading (limit=1)
curl -X GET "$_apiBase/channels/$_channelId/history?limit=1" \\
  -H "X-API-Key: $_keyPlaceholder"''';

    final curlTimeSeries = '''# 3. Query Time-Series Data (with auto-downsampling & optional limit)
# Supported resolutions: auto, raw, 1m, 1h
curl -X GET "$_apiBase/channels/$_channelId/data?resolution=1m&limit=100" \\
  -H "X-API-Key: $_keyPlaceholder"''';

    final pythonQuery = '''import requests

# Query Channel History (fetch the exact number of entries you want)
URL = "$_apiBase/channels/$_channelId/history"
API_KEY = "$_keyPlaceholder"

headers = {"X-API-Key": API_KEY}
params = {
    "limit": 10,       # Fetch last 10 entries (max 1000)
    "order": "desc"    # 'desc' (newest first) or 'asc' (oldest first)
}

res = requests.get(URL, headers=headers, params=params)
data = res.json()

print(f"Channel ID: {data['channel_id']}, Total Retrieved: {data['count']}")
for feed in data.get("feeds", []):
    print(f"[{feed['time']}] -> {feed['payload']}")''';

    final jsQuery = '''const url = "$_apiBase/channels/$_channelId/history?limit=10&order=desc";
const apiKey = "$_keyPlaceholder";

async function fetchHistory() {
  const res = await fetch(url, {
    headers: { "X-API-Key": apiKey }
  });
  const data = await res.json();
  console.log(`Fetched \${data.count} entries:`, data.feeds);
  data.feeds.forEach(f => {
    console.log(`[\${f.time}]`, f.payload);
  });
}

fetchHistory();''';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEndpointBanner(
          method: 'GET',
          path: '/channels/$_channelId/history?limit={count}&order={desc|asc}',
          description: 'Fetch channel history with full control over the number of records returned (default: 20, max: 1000).',
        ),
        const SizedBox(height: 14),
        _buildCodeSection('cURL (Fetch Channel History / Feeds)', curlHistoryFeeds),
        const SizedBox(height: 16),
        _buildCodeSection('Python (Fetch History & Iterate Records)', pythonQuery),
        const SizedBox(height: 16),
        _buildCodeSection('JavaScript (Web / Node)', jsQuery),
        const SizedBox(height: 20),
        _buildEndpointBanner(
          method: 'GET',
          path: '/channels/$_channelId/data?resolution={auto|raw|1m|1h}&limit={n}',
          description: 'Fetch historical time-series points grouped by field, powered by TimescaleDB hypertables.',
        ),
        const SizedBox(height: 14),
        _buildCodeSection('cURL (Query Time-Series Points)', curlTimeSeries),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: MQTT Streaming (Real-Time Pub/Sub)
  // ===========================================================================
  Widget _buildMqttTab() {
    final mosquittoPub = '''# 1. Publish Telemetry via Mosquitto CLI (Port $_mqttPort TLS)
mosquitto_pub -h "$_mqttHost" -p $_mqttPort \\
  -u "d_YOUR_DEVICE_USERNAME" \\
  -P "YOUR_DEVICE_PASSWORD" \\
  -t "channels/$_channelId/data" \\
  -m '{"temperature": 26.2, "humidity": 55.4, "rssi": -65}'

# 2. Subscribe to Live Channel Events
mosquitto_sub -h "$_mqttHost" -p $_mqttPort \\
  -u "d_YOUR_DEVICE_USERNAME" \\
  -P "YOUR_DEVICE_PASSWORD" \\
  -t "channels/$_channelId/data" -v''';

    final pythonMqtt = '''import paho.mqtt.client as mqtt
import json
import time

BROKER = "$_mqttHost"
PORT = $_mqttPort  # MQTTS TLS
TOPIC = "channels/$_channelId/data"
USERNAME = "d_YOUR_DEVICE_USERNAME"
PASSWORD = "YOUR_DEVICE_PASSWORD"

client = mqtt.Client(client_id="python_sensor_node")
client.tls_set()  # Enable TLS verification
client.username_pw_set(USERNAME, PASSWORD)

def on_connect(c, userdata, flags, rc):
    print("Connected with result code " + str(rc))

client.on_connect = on_connect
client.connect(BROKER, PORT, keepalive=60)
client.loop_start()

try:
    while True:
        payload = {
            "temperature": 24.8,
            "humidity": 61.2,
            "vibration_rms": 0.042
        }
        client.publish(TOPIC, json.dumps(payload), qos=1)
        print(f"Published to {TOPIC}: {payload}")
        time.sleep(2)  # Stream at high frequency (no rate limits!)
except KeyboardInterrupt:
    client.loop_stop()
    client.disconnect()''';

    final esp32Mqtt = '''#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

const char* mqttServer = "$_mqttHost";
const int mqttPort = $_mqttPort;
const char* mqttUser = "d_YOUR_DEVICE_USERNAME";
const char* mqttPass = "YOUR_DEVICE_PASSWORD";
const char* mqttTopic = "channels/$_channelId/data";

WiFiClientSecure espClient;
PubSubClient client(espClient);

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); }

  espClient.setInsecure(); // Skip certificate pinning for fast IoT testing
  client.setServer(mqttServer, mqttPort);
}

void reconnect() {
  while (!client.connected()) {
    if (client.connect("esp32_device_client", mqttUser, mqttPass)) {
      Serial.println("Connected to MQTT Broker!");
    } else {
      delay(2000);
    }
  }
}

void loop() {
  if (!client.connected()) { reconnect(); }
  client.loop();

  String payload = "{\\"temperature\\":26.5,\\"humidity\\":52.1}";
  client.publish(mqttTopic, payload.c_str());
  delay(1000); // High-frequency 1Hz streaming
}''';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.teal.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.bolt, color: Colors.tealAccent, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'MQTT is designed for microsecond, bi-directional telemetry streaming. To connect, generate dedicated hardware credentials in the "Devices" tab of your channel.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildCodeSection('Mosquitto CLI (pub / sub)', mosquittoPub),
        const SizedBox(height: 16),
        _buildCodeSection('Python (paho-mqtt with TLS)', pythonMqtt),
        const SizedBox(height: 16),
        _buildCodeSection('ESP32 Arduino (PubSubClient)', esp32Mqtt),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: Live Tester (Interactive Telemetry Ping)
  // ===========================================================================
  Widget _buildLiveTesterTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.cyanAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Send Live Telemetry to Channel #$_channelId',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Test your channel ingestion right from the app. Edit the JSON packet below and click "Send Telemetry". The Python Ingestion Bridge will record it in TimescaleDB and the live dashboard will update immediately.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                const Text(
                  'JSON Payload:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _testPayloadController,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.black12,
                    hintText: '{\n  "temp": 25.0\n}',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: _isTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_isTesting ? 'Sending...' : 'Send Telemetry Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _isTesting ? null : _executeTestSend,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      child: const Text('Randomize Values'),
                      onPressed: () {
                        final randomTemp = (20.0 + (DateTime.now().millisecond % 150) / 10.0).toStringAsFixed(1);
                        final randomHum = (45.0 + (DateTime.now().second % 40)).toStringAsFixed(1);
                        setState(() {
                          _testPayloadController.text =
                              '{\n  "temperature": $randomTemp,\n  "humidity": $randomHum,\n  "ping_ms": ${DateTime.now().millisecond}\n}';
                        });
                      },
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_testSuccess == true ? Colors.green : Colors.red)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testSuccess == true ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _testSuccess == true ? Icons.check_circle : Icons.error_outline,
                              color: _testSuccess == true ? Colors.greenAccent : Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _testSuccess == true
                                  ? 'Success! Telemetry Ingested'
                                  : 'Failed to Ingest',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _testSuccess == true
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _testResult!,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _executeTestSend() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final raw = _testPayloadController.text.trim();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Payload must be a JSON object with key-value pairs');
      }

      final apiService = context.read<ChannelProvider>().apiService;
      final res = await apiService.postTelemetry(
        channelId: _channelId,
        data: decoded,
        apiKey: _activeApiKey.isNotEmpty ? _activeApiKey : null,
      );

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = true;
          _testResult = 'HTTP 202 Accepted: ${jsonEncode(res)}\nCheck the Telemetry tab to see new live points!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResult = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // ===========================================================================
  // Reusable Code Card & Endpoint Banner Widgets
  // ===========================================================================
  Widget _buildEndpointBanner({
    required String method,
    required String path,
    required String description,
  }) {
    final isPost = method == 'POST';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isPost ? Colors.green : Colors.blue).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isPost ? Colors.green : Colors.blue).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPost ? Colors.green.shade800 : Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  method,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  path,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCodeSection(String title, String code) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.cyanAccent),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy Code',
                  onPressed: () => _copyToClipboard(code, title),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
