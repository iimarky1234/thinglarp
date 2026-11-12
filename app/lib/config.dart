import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String defaultApiUrl = 'http://localhost:8000';
  static const String defaultMqttHost = 'localhost';
  static const int defaultMqttPort = 1883;
  static const String defaultWebBaseUrl = 'https://thinglarp.iimarky123.io.vn/app';

  String apiUrl = defaultApiUrl;
  String mqttHost = defaultMqttHost;
  int mqttPort = defaultMqttPort;

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
    String fallbackApiUrl = defaultApiUrl;
    String fallbackMqttHost = defaultMqttHost;
    int fallbackMqttPort = defaultMqttPort;

    if (kIsWeb) {
      if (Uri.base.host.contains('iimarky123.io.vn')) {
        fallbackApiUrl = 'https://api.iimarky123.io.vn';
        fallbackMqttHost = 'mqtt.iimarky123.io.vn';
        fallbackMqttPort = 8883;
      }
    }

    apiUrl = prefs.getString('api_url') ?? fallbackApiUrl;
    mqttHost = prefs.getString('mqtt_host') ?? fallbackMqttHost;
    mqttPort = prefs.getInt('mqtt_port') ?? fallbackMqttPort;
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

