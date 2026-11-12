import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/channel.dart';
import '../models/telemetry.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';

class ChannelProvider extends ChangeNotifier {
  final ApiService apiService;
  final MqttService mqttService = MqttService();

  List<Channel> channels = [];
  Channel? activeChannel;
  List<ChannelField> fields = [];
  List<Device> devices = [];
  List<ApiKeyItem> apiKeys = [];

  // Telemetry state for active channel
  Map<String, List<TelemetryPoint>> chartPoints = {};
  Map<String, dynamic> latestValues = {};
  bool isLoading = false;
  bool isLiveStreaming = false;
  String currentResolution = 'auto';

  StreamSubscription? _mqttDataSub;
  StreamSubscription? _mqttStateSub;

  ChannelProvider({required this.apiService}) {
    _mqttStateSub = mqttService.stateStream.listen((state) {
      isLiveStreaming = state == BrokerState.connected;
      notifyListeners();
    });

    _mqttDataSub = mqttService.dataStream.listen((data) {
      _handleIncomingMqttData(data);
    });
  }

  Future<void> loadChannels() async {
    isLoading = true;
    notifyListeners();
    try {
      channels = await apiService.getChannels();
    } catch (e) {
      debugPrint('Failed to load channels: $e');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<Channel?> createChannel(String name, String? description, bool isPublic) async {
    try {
      final channel = await apiService.createChannel(name, description, isPublic);
      channels.insert(0, channel);
      notifyListeners();
      return channel;
    } catch (e) {
      debugPrint('Failed to create channel: $e');
      return null;
    }
  }

  Future<void> selectChannel(Channel channel) async {
    activeChannel = channel;
    chartPoints.clear();
    latestValues.clear();
    notifyListeners();

    // Load channel metadata & history
    await Future.wait([
      loadFields(channel.id),
      loadDevices(channel.id),
      loadApiKeys(channel.id),
      loadHistoricalData(channel.id),
      loadLatestSnapshot(channel.id),
    ]);

    // Automatically connect live stream
    await startLiveStream();
  }

  Future<void> loadFields(int channelId) async {
    try {
      fields = await apiService.getFields(channelId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading fields: $e');
    }
  }

  Future<void> updateFieldWidgetType(int channelId, int fieldId, String widgetType) async {
    try {
      await apiService.updateField(channelId, fieldId, widgetType: widgetType);
      await loadFields(channelId);
    } catch (e) {
      debugPrint('Error updating field widget type: $e');
      rethrow;
    }
  }

  Future<void> loadDevices(int channelId) async {
    try {
      devices = await apiService.getDevices(channelId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading devices: $e');
    }
  }

  Future<void> loadApiKeys(int channelId) async {
    try {
      apiKeys = await apiService.getApiKeys(channelId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading API keys: $e');
    }
  }

  Future<void> loadHistoricalData(int channelId, {String resolution = 'auto'}) async {
    currentResolution = resolution;
    try {
      final dataRes = await apiService.getTelemetry(channelId, resolution: resolution);
      chartPoints = dataRes.fields;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading historical telemetry: $e');
    }
  }

  Future<void> loadLatestSnapshot(int channelId) async {
    try {
      final res = await apiService.getLatestTelemetry(channelId);
      final rawFields = res['fields'] as Map<String, dynamic>? ?? {};
      latestValues = Map<String, dynamic>.from(rawFields);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading snapshot: $e');
    }
  }

  Future<void> startLiveStream() async {
    if (activeChannel == null) return;
    try {
      // 1. Request short-lived credentials from API
      final session = await apiService.requestMqttSession();
      final username = session['username'] as String;
      final password = session['password'] as String;

      final config = AppConfig();
      await mqttService.connect(
        host: config.mqttHost,
        port: config.mqttPort,
        username: username,
        password: password,
        channelId: activeChannel!.id,
        useTls: config.mqttPort == 8883,
      );
    } catch (e) {
      debugPrint('Failed to start live stream: $e');
    }
  }

  void stopLiveStream() {
    mqttService.disconnect();
  }

  void _handleIncomingMqttData(Map<String, dynamic> data) {
    final now = DateTime.now();

    data.forEach((key, val) {
      if (key == 'ts' || key == 'time' || key == 'timestamp') return;

      // Update latest value card
      latestValues[key] = val;

      // If numeric, append point to active chart list
      if (val is num) {
        final point = TelemetryPoint(time: now, value: val.toDouble());
        if (!chartPoints.containsKey(key)) {
          chartPoints[key] = [];
        }
        chartPoints[key]!.add(point);

        // Keep maximum 100 points in RAM for active live chart
        if (chartPoints[key]!.length > 100) {
          chartPoints[key]!.removeAt(0);
        }
      }
    });

    notifyListeners();
  }

  @override
  void dispose() {
    _mqttDataSub?.cancel();
    _mqttStateSub?.cancel();
    mqttService.dispose();
    super.dispose();
  }
}
