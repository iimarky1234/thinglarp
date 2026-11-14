import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String defaultApiUrl = 'http://localhost:8000';
  static const String defaultMqttHost = 'localhost';
  static const int defaultMqttPort = 1883;

  static const String cloudApiUrl = 'https://api.iimarky123.io.vn';
  static const String cloudMqttHost = 'mqtt.iimarky123.io.vn';
  static const int cloudMqttPort = 8883;

  static const String defaultWebBaseUrl = 'https://thinglarp.iimarky123.io.vn/app';

  /// Uses ThingLarp Cloud endpoints by default on mobile APKs and hosted web builds,
  /// while keeping localhost defaults for local desktop and dev runs.
  static bool get useCloudDefaultsByPlatform {
    if (kIsWeb) {
      return Uri.base.host.contains('iimarky123.io.vn');
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static String get recommendedApiUrl =>
      useCloudDefaultsByPlatform ? cloudApiUrl : defaultApiUrl;
  static String get recommendedMqttHost =>
      useCloudDefaultsByPlatform ? cloudMqttHost : defaultMqttHost;
  static int get recommendedMqttPort =>
      useCloudDefaultsByPlatform ? cloudMqttPort : defaultMqttPort;

  String apiUrl = recommendedApiUrl;
  String mqttHost = recommendedMqttHost;
  int mqttPort = recommendedMqttPort;

  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  String get webAppUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('null')) {
        return '$origin/app';
      }
    }
    return defaultWebBaseUrl;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    apiUrl = prefs.getString('api_url') ?? recommendedApiUrl;
    mqttHost = prefs.getString('mqtt_host') ?? recommendedMqttHost;
    mqttPort = prefs.getInt('mqtt_port') ?? recommendedMqttPort;
  }

  Future<void> save({required String newApiUrl, required String newMqttHost, required int newMqttPort}) async {
    apiUrl = newApiUrl;
    mqttHost = newMqttHost;
    mqttPort = newMqttPort;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', newApiUrl);
    await prefs.setString('mqtt_host', newMqttHost);
    await prefs.setInt('mqtt_port', newMqttPort);
  }
}

