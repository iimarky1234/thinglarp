import 'package:flutter/material.dart';
import '../config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiUrlController;
  late final TextEditingController _mqttHostController;
  late final TextEditingController _mqttPortController;

  @override
  void initState() {
    super.initState();
    final config = AppConfig();
    _apiUrlController = TextEditingController(text: config.apiUrl);
    _mqttHostController = TextEditingController(text: config.mqttHost);
    _mqttPortController = TextEditingController(text: config.mqttPort.toString());
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _mqttHostController.dispose();
    _mqttPortController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_mqttPortController.text.trim()) ?? 1883;
    await AppConfig().save(
      newApiUrl: _apiUrlController.text.trim(),
      newMqttHost: _mqttHostController.text.trim(),
      newMqttPort: port,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Configuration')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Backend Endpoints',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure your server URL and MQTT broker endpoints. Default is set to localhost for testing.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'http://localhost:8000 or https://api.yourdomain.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.http),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mqttHostController,
              decoration: const InputDecoration(
                labelText: 'MQTT Host',
                hintText: 'localhost or mqtt.yourdomain.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cloud_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mqttPortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'MQTT Port',
                hintText: '1883 (TCP) or 8883 (TLS)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
