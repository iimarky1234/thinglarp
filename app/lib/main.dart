import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'providers/auth_provider.dart';
import 'providers/channel_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'views/channels_screen.dart';
import 'views/login_screen.dart';
import 'views/public_channel_viewer_screen.dart';

int? extractDeepLinkChannelId() {
  // 1. Check query parameters (?channel=42)
  final queryParam = Uri.base.queryParameters['channel'];
  if (queryParam != null && int.tryParse(queryParam) != null) {
    return int.parse(queryParam);
  }

  // 2. Check hash fragment (#/channel/42 or #/channels/42)
  final fragment = Uri.base.fragment;
  if (fragment.isNotEmpty) {
    final match = RegExp(r'channels?/(\d+)').firstMatch(fragment);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
  }

  // 3. Check path (/app/channel/42 or /channel/42)
  final path = Uri.base.path;
  final match = RegExp(r'channels?/(\d+)').firstMatch(path);
  if (match != null) {
    return int.tryParse(match.group(1)!);
  }

  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved endpoints from SharedPreferences
  await AppConfig().load();

  final initialChannelId = extractDeepLinkChannelId();

  final apiService = ApiService();
  final authProvider = AuthProvider(apiService: apiService);
  final themeProvider = ThemeProvider();
  await Future.wait([
    authProvider.init(),
    themeProvider.init(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(
          create: (_) => ChannelProvider(apiService: apiService),
        ),
      ],
      child: ThingLarpApp(initialChannelId: initialChannelId),
    ),
  );
}

class ThingLarpApp extends StatelessWidget {
  final int? initialChannelId;

  const ThingLarpApp({super.key, this.initialChannelId});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = ThemeProvider.maybeOf(context);

    Widget homeScreen;
    if (initialChannelId != null) {
      homeScreen = PublicChannelViewerScreen(channelId: initialChannelId!);
    } else if (auth.isAuthenticated) {
      homeScreen = const ChannelsScreen();
    } else {
      homeScreen = const LoginScreen();
    }

    return MaterialApp(
      title: 'ThingLarp',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider?.themeMode ?? ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colors = context.appColors;
        final overlayStyle = (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colors.surfaceCanvas,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: homeScreen,
    );
  }
}

