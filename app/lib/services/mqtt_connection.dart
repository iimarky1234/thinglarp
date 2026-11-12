import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_connection_native.dart'
    if (dart.library.js_interop) 'mqtt_connection_web.dart' as platform_impl;

MqttClient getPlatformMqttClient({
  required String host,
  required int port,
  required String clientId,
  required bool useTls,
}) {
  return platform_impl.createMqttClient(
    host: host,
    port: port,
    clientId: clientId,
    useTls: useTls,
  );
}
