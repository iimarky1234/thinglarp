import 'package:flutter/material.dart';
import '../config.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiController;
  late final TextEditingController _mqttHostController;
  late final TextEditingController _mqttPortController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cfg = AppConfig();
    _apiController = TextEditingController(text: cfg.apiUrl);
    _mqttHostController = TextEditingController(text: cfg.mqttHost);
    _mqttPortController = TextEditingController(text: cfg.mqttPort.toString());
  }

  @override
  void dispose() {
    _apiController.dispose();
    _mqttHostController.dispose();
    _mqttPortController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await AppConfig().save(
      newApiUrl: _apiController.text.trim(),
      newMqttHost: _mqttHostController.text.trim(),
      newMqttPort: int.parse(_mqttPortController.text.trim()),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _applyPreset({
    required String apiUrl,
    required String mqttHost,
    required int mqttPort,
  }) {
    setState(() {
      _apiController.text = apiUrl;
      _mqttHostController.text = mqttHost;
      _mqttPortController.text = mqttPort.toString();
    });
  }

  void _resetDefaults() {
    _applyPreset(
      apiUrl: AppConfig.recommendedApiUrl,
      mqttHost: AppConfig.recommendedMqttHost,
      mqttPort: AppConfig.recommendedMqttPort,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final themeProvider = ThemeProvider.maybeOf(context);
    final currentMode = themeProvider?.themeMode ?? ThemeMode.system;
    final resolvedBrightness = Theme.of(context).brightness;
    final isPhone = context.isCompactPhone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppThemeToggleButton(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            isPhone ? 16 : 20,
            16,
            isPhone ? 16 : 20,
            28,
          ),
          child: ResponsiveCenter(
            maxWidth: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSurfaceCard(
                  padding: EdgeInsets.all(isPhone ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: colors.primarySoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.palette_outlined,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appearance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                'Choose Light, Dark, or match your system theme',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppStatusPill(
                          label: resolvedBrightness == Brightness.dark
                              ? 'Dark Active'
                              : 'Light Active',
                          color: colors.accentCyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeOptionTile(
                            label: 'System',
                            subtitle: 'Follow device',
                            icon: Icons.brightness_auto_rounded,
                            selected: currentMode == ThemeMode.system,
                            previewBg: colors.surfaceElevated,
                            previewAccent: colors.primary,
                            onTap: () => themeProvider?.setThemeMode(
                              ThemeMode.system,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ThemeOptionTile(
                            label: 'Light',
                            subtitle: 'Clean daylight',
                            icon: Icons.light_mode_rounded,
                            selected: currentMode == ThemeMode.light,
                            previewBg: const Color(0xFFF3F6FB),
                            previewAccent: const Color(0xFF2563EB),
                            onTap: () => themeProvider?.setThemeMode(
                              ThemeMode.light,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ThemeOptionTile(
                            label: 'Dark',
                            subtitle: 'Slate night',
                            icon: Icons.dark_mode_rounded,
                            selected: currentMode == ThemeMode.dark,
                            previewBg: const Color(0xFF0B1120),
                            previewAccent: const Color(0xFF38BDF8),
                            onTap: () => themeProvider?.setThemeMode(
                              ThemeMode.dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppSurfaceCard(
                padding: EdgeInsets.all(isPhone ? 16 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: colors.accentTeal.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.dns_outlined,
                              color: colors.accentTeal,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Server Endpoints',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Configure REST API & MQTT live notification broker',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _resetDefaults,
                            icon: const Icon(Icons.restart_alt_rounded, size: 17),
                            label: const Text('Defaults'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: Icon(
                              Icons.cloud_outlined,
                              size: 16,
                              color: colors.primary,
                            ),
                            label: const Text('ThingLarp Cloud'),
                            onPressed: () => _applyPreset(
                              apiUrl: AppConfig.cloudApiUrl,
                              mqttHost: AppConfig.cloudMqttHost,
                              mqttPort: AppConfig.cloudMqttPort,
                            ),
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.computer_rounded,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                            label: const Text('Localhost Dev'),
                            onPressed: () => _applyPreset(
                              apiUrl: AppConfig.defaultApiUrl,
                              mqttHost: AppConfig.defaultMqttHost,
                              mqttPort: AppConfig.defaultMqttPort,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _apiController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'REST API Base URL',
                          hintText: 'https://api.iimarky123.io.vn',
                          prefixIcon: Icon(Icons.http_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'API URL is required';
                          }
                          if (!v.trim().startsWith('http')) {
                            return 'URL must start with http:// or https://';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      if (isPhone) ...[
                        TextFormField(
                          controller: _mqttHostController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'MQTT Broker Host',
                            hintText: 'mqtt.iimarky123.io.vn',
                            prefixIcon: Icon(Icons.router_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Host required'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _mqttPortController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'MQTT Port (8883 TLS / 1883)',
                            hintText: '8883',
                            prefixIcon: Icon(Icons.numbers_rounded),
                          ),
                          validator: (v) {
                            final port = int.tryParse((v ?? '').trim());
                            if (port == null || port < 1 || port > 65535) {
                              return 'Enter valid port (1–65535)';
                            }
                            return null;
                          },
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _mqttHostController,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'MQTT Broker Host',
                                  hintText: 'mqtt.iimarky123.io.vn',
                                  prefixIcon: Icon(Icons.router_outlined),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Host required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _mqttPortController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Port',
                                  hintText: '8883',
                                  prefixIcon: Icon(Icons.numbers_rounded),
                                ),
                                validator: (v) {
                                  final port = int.tryParse((v ?? '').trim());
                                  if (port == null || port < 1 || port > 65535) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveSettings,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save Endpoint Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color previewBg;
  final Color previewAccent;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.previewBg,
    required this.previewAccent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? colors.primarySoft.withValues(alpha: 0.45) : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 22,
                  decoration: BoxDecoration(
                    color: previewBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.borderStrong),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: previewAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: selected ? colors.primary : colors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? colors.primary : colors.textSecondary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
