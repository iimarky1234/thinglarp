import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'providers/auth_provider.dart';
import 'providers/channel_provider.dart';
import 'services/api_service.dart';
import 'views/channels_screen.dart';
import 'views/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved endpoints from SharedPreferences
  await AppConfig().load();

  final apiService = ApiService();
  final authProvider = AuthProvider(apiService: apiService);
  await authProvider.init();

  runApp(
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
}

class ThingLarpApp extends StatelessWidget {
  const ThingLarpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'ThingLarp',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blueAccent,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: auth.isAuthenticated ? const ChannelsScreen() : const LoginScreen(),
    );
  }
}
