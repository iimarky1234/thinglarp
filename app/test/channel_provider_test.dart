import 'package:flutter_test/flutter_test.dart';
import 'package:thinglarp_app/models/channel.dart';
import 'package:thinglarp_app/models/telemetry.dart';
import 'package:thinglarp_app/providers/channel_provider.dart';
import 'package:thinglarp_app/services/api_service.dart';

class _FakeApiService extends ApiService {
  int getTelemetryCalls = 0;
  int getLatestCalls = 0;
  int getFieldsCalls = 0;
  int? lastLimit;
  bool? lastAllTime;
  String? lastResolution;
  Map<String, dynamic> latestPayload = {'temp': 25.0};
  List<ChannelField> channelFields = [
    ChannelField(
      id: 1,
      channelId: 1,
      key: 'temp',
      valueType: 'number',
      firstSeenAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  @override
  Future<ChannelDataResponse> getTelemetry(
    int channelId, {
    String resolution = 'auto',
    String? fields,
    DateTime? start,
    DateTime? end,
    int? limit,
    bool allTime = false,
  }) async {
    getTelemetryCalls++;
    lastLimit = limit;
    lastAllTime = allTime;
    lastResolution = resolution;
    return ChannelDataResponse(
      channelId: channelId,
      resolution: resolution,
      fields: {
        'temp': [
          TelemetryPoint(time: DateTime.utc(2026, 1, 1, 0, 1), value: 24.5),
          TelemetryPoint(time: DateTime.utc(2026, 1, 1, 0, 2), value: 25.0),
        ],
      },
    );
  }

  @override
  Future<Map<String, dynamic>> getLatestTelemetry(int channelId) async {
    getLatestCalls++;
    return {'channel_id': channelId, 'fields': latestPayload};
  }

  @override
  Future<List<ChannelField>> getFields(int channelId) async {
    getFieldsCalls++;
    return channelFields;
  }

  @override
  Future<List<Device>> getDevices(int channelId) async => [];

  @override
  Future<List<ApiKeyItem>> getApiKeys(int channelId) async => [];

  @override
  Future<Map<String, dynamic>> requestMqttSession() async {
    throw Exception('Skip real broker connection in unit test');
  }
}

void main() {
  test('ChannelProvider passes pointLimit and allTime options to API', () async {
    final fakeApi = _FakeApiService();
    final provider = ChannelProvider(apiService: fakeApi);
    final channel = Channel(
      id: 1,
      name: 'Test',
      isPublic: false,
      maxFields: 500,
      createdAt: DateTime.utc(2026, 1, 1),
      ownerId: 1,
    );

    await provider.selectChannel(channel);
    expect(provider.pointLimit, 100);
    expect(provider.timeWindow, '1h');
    expect(fakeApi.lastLimit, 100);
    expect(fakeApi.lastAllTime, false);

    // Clamp limit above maxPointLimit (10,000) and test All Time
    await provider.loadHistoricalData(
      1,
      limit: 25000,
      window: 'all',
      resolution: 'raw',
    );
    expect(provider.pointLimit, 10000);
    expect(provider.timeWindow, 'all');
    expect(fakeApi.lastLimit, 10000);
    expect(fakeApi.lastAllTime, true);
    expect(fakeApi.lastResolution, 'raw');

    provider.dispose();
  });

  test('ChannelProvider refreshTelemetry reloads fields when new key arrives', () async {
    final fakeApi = _FakeApiService();
    final provider = ChannelProvider(apiService: fakeApi);
    final channel = Channel(
      id: 1,
      name: 'Test',
      isPublic: true,
      maxFields: 500,
      createdAt: DateTime.utc(2026, 1, 1),
      ownerId: 1,
    );

    await provider.selectChannel(channel, isReadOnly: true);
    expect(fakeApi.getFieldsCalls, 1);

    // Simulate API returning a newly discovered field key in latest snapshot
    fakeApi.latestPayload = {'temp': 26.1, 'humidity': 55.0};
    await provider.refreshTelemetry(1);

    expect(fakeApi.getLatestCalls, 2);
    expect(fakeApi.getTelemetryCalls, 2);
    expect(fakeApi.getFieldsCalls, 2);

    provider.dispose();
  });
}
