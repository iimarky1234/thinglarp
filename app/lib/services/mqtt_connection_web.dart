import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient({
  required String host,
  required int port,
  required String clientId,
  required bool useTls,
}) {
  // In web browsers, connection must be WebSocket (ws:// or wss://)
  final scheme = useTls ? 'wss' : 'ws';
  final wsUrl = '$scheme://$host/mqtt';
  final effectivePort = useTls ? 443 : port;

  final client = MqttBrowserClient(wsUrl, clientId);
  client.port = effectivePort;
  client.keepAlivePeriod = 30;
  client.autoReconnect = true;
  client.logging(on: false);
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

  return client;
}
