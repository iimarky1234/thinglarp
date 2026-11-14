import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinglarp_app/config.dart';
import 'package:thinglarp_app/main.dart';
import 'package:thinglarp_app/models/channel.dart';
import 'package:thinglarp_app/models/telemetry.dart';
import 'package:thinglarp_app/providers/auth_provider.dart';
import 'package:thinglarp_app/providers/channel_provider.dart';
import 'package:thinglarp_app/providers/theme_provider.dart';
import 'package:thinglarp_app/services/api_service.dart';
import 'package:thinglarp_app/views/channel_detail_screen.dart';
import 'package:thinglarp_app/views/channels_screen.dart';
import 'package:thinglarp_app/views/login_screen.dart';
import 'package:thinglarp_app/views/public_channel_viewer_screen.dart';
import 'package:thinglarp_app/views/settings_screen.dart';
import 'package:thinglarp_app/widgets/app_ui.dart';

class _WidgetFakeApiService extends ApiService {
  bool returnEmptyWindow = false;
  int getTelemetryCount = 0;
  List<Channel>? customChannels;
  List<Device> sampleDevices = [];
  List<ApiKeyItem> sampleApiKeys = [];

  final Channel sampleChannel = Channel(
    id: 2,
    ownerId: 1,
    name: 'TestPub',
    description: 'Greenhouse telemetry',
    isPublic: true,
    maxFields: 500,
    createdAt: DateTime.utc(2026, 11, 13),
  );

  @override
  Future<List<Channel>> getChannels() async => customChannels ?? [sampleChannel];

  @override
  Future<Channel> getChannel(int channelId) async => sampleChannel;

  @override
  Future<List<ChannelField>> getFields(int channelId) async => [
        ChannelField(
          id: 11,
          channelId: channelId,
          key: 'temperature',
          label: 'Temperature',
          unit: '°C',
          valueType: 'number',
          widgetType: 'line',
          firstSeenAt: DateTime.utc(2026, 11, 13),
        ),
      ];

  @override
  Future<List<Device>> getDevices(int channelId) async => sampleDevices;

  @override
  Future<List<ApiKeyItem>> getApiKeys(int channelId) async => sampleApiKeys;

  @override
  Future<Map<String, dynamic>> getLatestTelemetry(int channelId) async => {
        'channel_id': channelId,
        'fields': {'temperature': 26.4},
      };

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
    getTelemetryCount++;
    if (returnEmptyWindow && !allTime) {
      return ChannelDataResponse(
        channelId: channelId,
        resolution: resolution,
        fields: {'temperature': []},
      );
    }
    return ChannelDataResponse(
      channelId: channelId,
      resolution: resolution,
      fields: {
        'temperature': [
          TelemetryPoint(time: DateTime.utc(2026, 11, 13, 10, 0), value: 24.8),
          TelemetryPoint(time: DateTime.utc(2026, 11, 13, 10, 5), value: 26.4),
        ],
      },
    );
  }

  @override
  Future<Map<String, dynamic>> requestMqttSession() async {
    throw Exception('Skip broker in widget test');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders LoginScreen when not authenticated', (WidgetTester tester) async {
    final apiService = ApiService();
    final authProvider = AuthProvider(apiService: apiService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(
            create: (_) => ChannelProvider(apiService: apiService),
          ),
        ],
        child: const ThingLarpApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify LoginScreen is shown with title and input fields
    expect(find.text('ThingLarp'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  test('ThemeProvider persists theme mode and toggles brightness cleanly', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final provider = ThemeProvider();
    await provider.init();
    expect(provider.themeMode, ThemeMode.dark);
    expect(provider.isDarkMode, isTrue);

    await provider.toggleBrightness(Brightness.dark);
    expect(provider.themeMode, ThemeMode.light);
    expect(provider.isLightMode, isTrue);

    final reloaded = ThemeProvider();
    await reloaded.init();
    expect(reloaded.themeMode, ThemeMode.light);

    await reloaded.setThemeMode(ThemeMode.system);
    expect(reloaded.isSystemMode, isTrue);
  });

  testWidgets('Theme toggle button and SettingsScreen switch between Light and Dark mode', (WidgetTester tester) async {
    final apiService = ApiService();
    final authProvider = AuthProvider(apiService: apiService);
    final themeProvider = ThemeProvider(initialMode: ThemeMode.light);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider(
            create: (_) => ChannelProvider(apiService: apiService),
          ),
        ],
        child: const ThingLarpApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Initially light mode
    var loginContext = tester.element(find.byType(LoginScreen));
    expect(Theme.of(loginContext).brightness, Brightness.light);
    expect(find.text('Dark'), findsOneWidget);

    // Quick toggle from Light -> Dark
    await tester.tap(find.byType(AppThemeToggleButton));
    await tester.pumpAndSettle();

    loginContext = tester.element(find.byType(LoginScreen));
    expect(Theme.of(loginContext).brightness, Brightness.dark);
    expect(themeProvider.themeMode, ThemeMode.dark);
    expect(find.text('Light'), findsOneWidget);

    // Navigate to SettingsScreen and switch explicitly via Appearance tile
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.text('Clean daylight'));
    await tester.pumpAndSettle();

    expect(themeProvider.themeMode, ThemeMode.light);
  });

  testWidgets('Opening channel from ChannelsScreen loads historical telemetry', (WidgetTester tester) async {
    final fakeApi = _WidgetFakeApiService();
    final authProvider = AuthProvider(apiService: fakeApi);
    final channelProvider = ChannelProvider(apiService: fakeApi);
    final themeProvider = ThemeProvider(initialMode: ThemeMode.dark);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: channelProvider),
          ChangeNotifierProvider.value(value: themeProvider),
        ],
        child: const MaterialApp(home: ChannelsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('TestPub'), findsOneWidget);

    await tester.tap(find.text('TestPub'));
    await tester.pumpAndSettle();

    expect(fakeApi.getTelemetryCount, greaterThanOrEqualTo(1));
    expect(channelProvider.activeChannel?.id, 2);
    expect(find.text('Temperature (°C)'), findsOneWidget);
    expect(find.textContaining('Samples: 2'), findsOneWidget);

    // Verify empty-window fallback CTA works
    fakeApi.returnEmptyWindow = true;
    await channelProvider.loadHistoricalData(2, window: '15m');
    await tester.pumpAndSettle();
    expect(find.text('Show All Time'), findsOneWidget);

    await tester.tap(find.text('Show All Time'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Samples: 2'), findsOneWidget);
  });

  testWidgets('PublicChannelViewerScreen loads read-only historical view', (WidgetTester tester) async {
    final fakeApi = _WidgetFakeApiService();
    final authProvider = AuthProvider(apiService: fakeApi);
    final channelProvider = ChannelProvider(apiService: fakeApi);
    final themeProvider = ThemeProvider(initialMode: ThemeMode.light);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: channelProvider),
          ChangeNotifierProvider.value(value: themeProvider),
        ],
        child: const MaterialApp(
          home: PublicChannelViewerScreen(channelId: 2),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(fakeApi.getTelemetryCount, greaterThanOrEqualTo(1));
    expect(find.text('VIEW ONLY'), findsOneWidget);
    expect(find.text('Temperature (°C)'), findsOneWidget);
    expect(find.textContaining('Samples: 2'), findsOneWidget);
  });

  testWidgets('Android platform defaults to ThingLarp Cloud and SettingsScreen renders cleanly at 360x800', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      expect(AppConfig.useCloudDefaultsByPlatform, isTrue);
      expect(AppConfig.recommendedApiUrl, AppConfig.cloudApiUrl);
      expect(AppConfig.recommendedMqttHost, AppConfig.cloudMqttHost);
      expect(AppConfig.recommendedMqttPort, AppConfig.cloudMqttPort);

      final apiService = ApiService();
      final authProvider = AuthProvider(apiService: apiService);
      final themeProvider = ThemeProvider(initialMode: ThemeMode.dark);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider(
              create: (_) => ChannelProvider(apiService: apiService),
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ThingLarp Cloud'), findsOneWidget);
      expect(find.text('Localhost Dev'), findsOneWidget);

      await tester.ensureVisible(find.text('Localhost Dev'));
      await tester.tap(find.text('Localhost Dev'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<EditableText>(find.byType(EditableText)).map((e) => e.controller.text),
        containsAll(['http://localhost:8000', 'localhost', '1883']),
      );

      await tester.ensureVisible(find.text('ThingLarp Cloud'));
      await tester.tap(find.text('ThingLarp Cloud'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<EditableText>(find.byType(EditableText)).map((e) => e.controller.text),
        containsAll(['https://api.iimarky123.io.vn', 'mqtt.iimarky123.io.vn', '8883']),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ChannelsScreen adapts to 360x800 phone viewport and opens Create Channel modal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final fakeApi = _WidgetFakeApiService();
      fakeApi.customChannels = [
        fakeApi.sampleChannel,
        Channel(
          id: 9,
          ownerId: 1,
          name: 'Greenhouse Rooftop Sensor Cluster #42 Long Title',
          description: 'Automated microclimate monitoring station on rooftop wing B',
          isPublic: false,
          maxFields: 500,
          createdAt: DateTime.utc(2026, 11, 14),
        ),
      ];
      final authProvider = AuthProvider(apiService: fakeApi);
      final channelProvider = ChannelProvider(apiService: fakeApi);
      final themeProvider = ThemeProvider(initialMode: ThemeMode.light);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: channelProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(home: ChannelsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TestPub'), findsOneWidget);
      expect(find.textContaining('Greenhouse Rooftop'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);

      // Open Create Channel responsive bottom sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveModalScaffold), findsOneWidget);
      expect(find.text('New Channel'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ChannelDetailScreen renders phone NavigationBar, Devices, API Keys, and Export modal cleanly at 360x800', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final fakeApi = _WidgetFakeApiService();
      fakeApi.sampleDevices = [
        Device(
          id: 1,
          channelId: 2,
          name: 'ESP32 Greenhouse Roof Climate Controller Alpha',
          mqttUsername: 'dev_2_esp32_greenhouse_controller_alpha',
          mqttPassword: 'super_secret_mqtt_password_2026',
          scope: 'pubsub',
          isActive: true,
          createdAt: DateTime.utc(2026, 11, 13),
        ),
      ];
      fakeApi.sampleApiKeys = [
        ApiKeyItem(
          id: 10,
          channelId: 2,
          prefix: 'tl_live_9876',
          apiKey: 'tl_live_9876543210abcdef1234567890',
          scope: 'write',
          createdAt: DateTime.utc(2026, 11, 13),
        ),
      ];

      final authProvider = AuthProvider(apiService: fakeApi);
      final channelProvider = ChannelProvider(apiService: fakeApi);
      final themeProvider = ThemeProvider(initialMode: ThemeMode.dark);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: channelProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: ChannelDetailScreen(channel: fakeApi.sampleChannel),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bottom NavigationBar replaces cramped top TabBar on compact phones
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Telemetry'), findsOneWidget);
      expect(find.text('Devices'), findsOneWidget);
      expect(find.text('API Keys'), findsOneWidget);

      // Switch to Devices tab and verify stacked phone layout + full-width credentials
      await tester.tap(find.text('Devices'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ESP32 Greenhouse Roof Climate Controller Alpha'));
      expect(find.text('ESP32 Greenhouse Roof Climate Controller Alpha'), findsOneWidget);
      await tester.ensureVisible(find.text('dev_2_esp32_greenhouse_controller_alpha'));
      expect(find.text('dev_2_esp32_greenhouse_controller_alpha'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(find.text('super_secret_mqtt_password_2026'), findsOneWidget);

      // Switch to API Keys tab
      await tester.tap(find.text('API Keys'));
      await tester.pumpAndSettle();
      expect(find.text('WRITE API KEY'), findsOneWidget);

      // Open phone overflow menu and launch Export bottom sheet
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download / Export Data'));
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveModalScaffold), findsOneWidget);
      expect(find.text('24 Hours'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
