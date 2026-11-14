import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinglarp_app/main.dart';
import 'package:thinglarp_app/providers/auth_provider.dart';
import 'package:thinglarp_app/providers/channel_provider.dart';
import 'package:thinglarp_app/providers/theme_provider.dart';
import 'package:thinglarp_app/services/api_service.dart';
import 'package:thinglarp_app/views/login_screen.dart';
import 'package:thinglarp_app/widgets/app_ui.dart';

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
}
