import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient({
  required String host,
  required int port,
  required String clientId,
  required bool useTls,
}) {
  final client = MqttServerClient.withPort(host, clientId, port);
  client.secure = useTls;
  client.keepAlivePeriod = 30;
  client.autoReconnect = true;
  client.logging(on: false);

  if (useTls) {
    client.securityContext = SecurityContext.defaultContext;
  }

  return client;
}
