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
  static const int maxPointLimit = 10000;
  static const Map<String, Duration> _timeWindowDurations = {
    '15m': Duration(minutes: 15),
    '1h': Duration(hours: 1),
    '6h': Duration(hours: 6),
    '24h': Duration(hours: 24),
    '7d': Duration(days: 7),
    '30d': Duration(days: 30),
  };

  Map<String, List<TelemetryPoint>> chartPoints = {};
  Map<String, dynamic> latestValues = {};
  bool isLoading = false;
  bool isLiveStreaming = false;
  String currentResolution = 'auto';
  int pointLimit = 100;
  String timeWindow = '1h';
  DateTime? lastSyncedAt;

  StreamSubscription? _mqttNotifySub;
  StreamSubscription? _mqttStateSub;
  Timer? _syncDebounceTimer;
  bool _isSyncInFlight = false;
  bool _pendingResync = false;

  ChannelProvider({required this.apiService}) {
    _mqttStateSub = mqttService.stateStream.listen((state) {
      isLiveStreaming = state == BrokerState.connected;
      if (!isLiveStreaming) {
        _cancelPendingSync();
      }
      notifyListeners();
    });

    _mqttNotifySub = mqttService.notificationStream.listen((_) {
      _onMqttDataArrived();
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

  Future<Channel?> updateChannel(int channelId, {String? name, String? description, bool? isPublic}) async {
    try {
      final updated = await apiService.updateChannel(channelId, name: name, description: description, isPublic: isPublic);
      final idx = channels.indexWhere((c) => c.id == channelId);
      if (idx != -1) {
        channels[idx] = updated;
      }
      if (activeChannel?.id == channelId) {
        activeChannel = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      debugPrint('Error updating channel: $e');
      return null;
    }
  }

  Future<void> selectChannel(Channel channel, {bool isReadOnly = false}) async {
    _cancelPendingSync();
    activeChannel = channel;
    chartPoints.clear();
    latestValues.clear();
    lastSyncedAt = null;
    notifyListeners();

    if (isReadOnly) {
      await Future.wait([
        loadFields(channel.id),
        loadHistoricalData(channel.id),
        loadLatestSnapshot(channel.id),
      ]);
      if (apiService.isAuthenticated) {
        try {
          await startLiveStream();
        } catch (_) {}
      }
    } else {
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
  }

  Future<void> loadFields(int channelId) async {
    try {
      final loaded = await apiService.getFields(channelId);
      if (activeChannel?.id == channelId) {
        fields = loaded;
        notifyListeners();
      }
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

  Future<void> loadHistoricalData(
    int channelId, {
    String? resolution,
    int? limit,
    String? window,
  }) async {
    if (resolution != null) currentResolution = resolution;
    if (limit != null) pointLimit = limit.clamp(1, maxPointLimit);
    if (window != null) timeWindow = window;

    final now = DateTime.now().toUtc();
    final isAllTime = timeWindow == 'all';
    final duration = _timeWindowDurations[timeWindow];
    final DateTime? startTime = isAllTime ? null : now.subtract(duration ?? const Duration(hours: 1));

    try {
      final dataRes = await apiService.getTelemetry(
        channelId,
        resolution: currentResolution,
        start: startTime,
        end: now,
        limit: pointLimit,
        allTime: isAllTime,
      );
      if (activeChannel?.id == channelId) {
        chartPoints = dataRes.fields;
        lastSyncedAt = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading historical telemetry: $e');
    }
  }

  Future<void> loadLatestSnapshot(int channelId) async {
    try {
      final res = await apiService.getLatestTelemetry(channelId);
      final rawFields = res['fields'] as Map<String, dynamic>? ?? {};
      if (activeChannel?.id == channelId) {
        latestValues = Map<String, dynamic>.from(rawFields);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading snapshot: $e');
    }
  }

  Future<void> refreshTelemetry(int channelId) async {
    await Future.wait([
      loadLatestSnapshot(channelId),
      loadHistoricalData(channelId),
    ]);
    final knownKeys = fields.map((f) => f.key).toSet();
    final hasNewField = latestValues.keys.any(
      (k) => k != 'ts' && k != 'time' && k != 'timestamp' && !knownKeys.contains(k),
    );
    if (hasNewField && activeChannel?.id == channelId) {
      await loadFields(channelId);
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
      final useTls = config.mqttPort == 8883 || (kIsWeb && config.mqttHost.contains('iimarky123.io.vn'));
      await mqttService.connect(
        host: config.mqttHost,
        port: config.mqttPort,
        username: username,
        password: password,
        channelId: activeChannel!.id,
        useTls: useTls,
      );
    } catch (e) {
      debugPrint('Failed to start live stream: $e');
    }
  }

  void stopLiveStream() {
    _cancelPendingSync();
    mqttService.disconnect();
  }

  void _cancelPendingSync() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    _pendingResync = false;
  }

  void _onMqttDataArrived() {
    if (activeChannel == null || !isLiveStreaming) return;
    if (_isSyncInFlight) {
      _pendingResync = true;
      return;
    }
    _scheduleDebouncedSync();
  }

  void _scheduleDebouncedSync() {
    if (_syncDebounceTimer != null && _syncDebounceTimer!.isActive) return;
    _syncDebounceTimer = Timer(const Duration(milliseconds: 600), _executeSyncFromApi);
  }

  Future<void> _executeSyncFromApi() async {
    final channelId = activeChannel?.id;
    if (channelId == null || !isLiveStreaming) return;

    if (_isSyncInFlight) {
      _pendingResync = true;
      return;
    }

    _isSyncInFlight = true;
    try {
      await refreshTelemetry(channelId);
    } finally {
      _isSyncInFlight = false;
      if (_pendingResync && activeChannel?.id == channelId && isLiveStreaming) {
        _pendingResync = false;
        _scheduleDebouncedSync();
      }
    }
  }

  @override
  void dispose() {
    _cancelPendingSync();
    _mqttNotifySub?.cancel();
    _mqttStateSub?.cancel();
    mqttService.dispose();
    super.dispose();
  }
}
