import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_connection.dart';

enum BrokerState { disconnected, connecting, connected, error }

class MqttService {
  MqttClient? _client;
  final _stateController = StreamController<BrokerState>.broadcast();
  final _notificationController = StreamController<void>.broadcast();

  Stream<BrokerState> get stateStream => _stateController.stream;
  /// Emits a signal whenever a new telemetry packet arrives on the subscribed channel.
  Stream<void> get notificationStream => _notificationController.stream;
  BrokerState currentState = BrokerState.disconnected;

  Future<void> connect({
    required String host,
    required int port,
    required String username,
    required String password,
    required int channelId,
    bool useTls = false,
  }) async {
    _client?.disconnect();
    _updateState(BrokerState.connecting);

    final clientId = 'flutter_${username}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    _client = getPlatformMqttClient(
      host: host,
      port: port,
      clientId: clientId,
      useTls: useTls,
    );

    final connMessage = MqttConnectMessage()
        .authenticateAs(username, password)
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      final status = await _client!.connect().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('MQTT connection timeout (8s)');
          return null;
        },
      );
      if (status?.state == MqttConnectionState.connected ||
          _client!.connectionStatus?.state == MqttConnectionState.connected) {
        _updateState(BrokerState.connected);

        // Subscribe to channel data topic strictly as a "new data arrived" notification trigger
        final topic = 'channels/$channelId/data';
        _client!.subscribe(topic, MqttQos.atLeastOnce);

        _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
          if (messages.isNotEmpty) {
            _notificationController.add(null);
          }
        });
      } else {
        _updateState(BrokerState.error);
        _client?.disconnect();
      }
    } catch (e) {
      debugPrint('MQTT connection error: $e');
      _updateState(BrokerState.error);
      _client?.disconnect();
    }
  }

  void disconnect() {
    _client?.disconnect();
    _updateState(BrokerState.disconnected);
  }

  void _updateState(BrokerState state) {
    currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _notificationController.close();
  }
}
