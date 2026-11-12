import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String defaultApiUrl = 'http://localhost:8000';
  static const String defaultMqttHost = 'localhost';
  static const int defaultMqttPort = 1883;

  String apiUrl = defaultApiUrl;
  String mqttHost = defaultMqttHost;
  int mqttPort = defaultMqttPort;

  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    apiUrl = prefs.getString('api_url') ?? defaultApiUrl;
    mqttHost = prefs.getString('mqtt_host') ?? defaultMqttHost;
    mqttPort = prefs.getInt('mqtt_port') ?? defaultMqttPort;
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
