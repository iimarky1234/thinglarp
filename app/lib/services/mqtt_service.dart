import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

enum BrokerState { disconnected, connecting, connected, error }

class MqttService {
  MqttServerClient? _client;
  final _stateController = StreamController<BrokerState>.broadcast();
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<BrokerState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  BrokerState currentState = BrokerState.disconnected;

  Future<void> connect({
    required String host,
    required int port,
    required String username,
    required String password,
    required int channelId,
    bool useTls = false,
  }) async {
    _updateState(BrokerState.connecting);

    final clientId = 'flutter_${username}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    _client = MqttServerClient.withPort(host, clientId, port);

    _client!.secure = useTls;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.logging(on: false);

    if (useTls) {
      _client!.securityContext = SecurityContext.defaultContext;
    }

    final connMessage = MqttConnectMessage()
        .authenticateAs(username, password)
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      final status = await _client!.connect();
      if (status?.state == MqttConnectionState.connected ||
          _client!.connectionStatus?.state == MqttConnectionState.connected) {
        _updateState(BrokerState.connected);

        // Subscribe to channel data topic
        final topic = 'channels/$channelId/data';
        _client!.subscribe(topic, MqttQos.atLeastOnce);

        _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
          for (final msg in messages) {
            final recMess = msg.payload as MqttPublishMessage;
            final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

            try {
              final decoded = jsonDecode(payload);
              if (decoded is Map<String, dynamic>) {
                _dataController.add(decoded);
              } else if (decoded is List) {
                for (final item in decoded) {
                  if (item is Map<String, dynamic>) {
                    _dataController.add(item);
                  }
                }
              }
            } catch (e) {
              debugPrint('Error parsing incoming MQTT message: $e');
            }
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
    _dataController.close();
  }
}
