import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinglarp_app/main.dart';
import 'package:thinglarp_app/providers/auth_provider.dart';
import 'package:thinglarp_app/providers/channel_provider.dart';
import 'package:thinglarp_app/services/api_service.dart';

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
    expect(find.text('ThingLarp IoT'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
