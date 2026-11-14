import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/channel.dart';
import '../models/telemetry.dart';
import '../providers/channel_provider.dart';
import '../services/mqtt_service.dart';
import '../config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'api_tutorial_screen.dart';
import 'login_screen.dart';

class ChannelDetailScreen extends StatefulWidget {
  final Channel channel;
  final bool isReadOnly;

  const ChannelDetailScreen({
    super.key,
    required this.channel,
    this.isReadOnly = false,
  });

  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollingTimer;
  ChannelProvider? _channelProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isReadOnly ? 1 : 3, vsync: this);
    final prov = context.read<ChannelProvider>();
    if (prov.activeChannel?.id != widget.channel.id) {
      Future.microtask(() {
        if (!mounted) return;
        final currentProv = context.read<ChannelProvider>();
        if (currentProv.activeChannel?.id != widget.channel.id) {
          currentProv.selectChannel(widget.channel, isReadOnly: widget.isReadOnly);
        }
      });
    }
    if (widget.isReadOnly && !prov.apiService.isAuthenticated) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) {
          context.read<ChannelProvider>().refreshTelemetry(widget.channel.id);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _channelProvider = context.read<ChannelProvider>();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _channelProvider?.clearActiveChannel(widget.channel.id);
    _tabController.dispose();
    super.dispose();
  }

  void _shareChannelLink() async {
    final url = '${AppConfig().webAppUrl}/#/channel/${widget.channel.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;

    if (widget.channel.isPublic) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Public channel link copied: $url'),
          backgroundColor: Colors.teal,
          action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text('Channel is Private'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share link copied to clipboard:\n$url\n'),
              const Text(
                'Note: Anyone who opens this link will receive an Access Denied (403) error because this channel is currently Private.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final prov = context.read<ChannelProvider>();
                try {
                  await prov.updateChannel(widget.channel.id, isPublic: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Channel marked as Public! Anyone with the link can view.'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to make channel public: $e')),
                    );
                  }
                }
              },
              child: const Text('Make Channel Public'),
            ),
          ],
        ),
      );
    }
  }

  void _showAddDeviceDialog() {
    final nameCtrl = TextEditingController();
    String scope = 'publish';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Provision New Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'e.g. ESP32 Node 1',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Access Control / Scope:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'publish', label: Text('Pub'), icon: Icon(Icons.upload, size: 16)),
                  ButtonSegment(value: 'subscribe', label: Text('Sub'), icon: Icon(Icons.download, size: 16)),
                  ButtonSegment(value: 'pubsub', label: Text('Pub/Sub'), icon: Icon(Icons.sync_alt, size: 16)),
                ],
                selected: {scope},
                onSelectionChanged: (newSelection) {
                  setDialogState(() => scope = newSelection.first);
                },
              ),
              const SizedBox(height: 8),
              Text(
                scope == 'publish'
                    ? 'Device can only publish telemetry to this channel.'
                    : scope == 'subscribe'
                        ? 'Device can only subscribe to data and commands.'
                        : 'Full access: device can publish telemetry and receive commands.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final provider = context.read<ChannelProvider>();
                  final dev = await provider.apiService.createDevice(widget.channel.id, name, scope: scope);
                  await provider.loadDevices(widget.channel.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _showCredentialsDialog(dev);
                }
              },
              child: const Text('Generate Credentials'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDeviceDialog(Device dev) {
    final nameCtrl = TextEditingController(text: dev.name);
    String scope = dev.scope;
    bool isActive = dev.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${dev.name} Access Control'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Device Name'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Device Active'),
                subtitle: Text(isActive ? 'Device is allowed to connect over MQTT' : 'Connection suspended/blocked'),
                value: isActive,
                onChanged: (val) {
                  setDialogState(() => isActive = val);
                },
              ),
              const SizedBox(height: 12),
              const Text('Permission Scope:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'publish', label: Text('Pub'), icon: Icon(Icons.upload, size: 16)),
                  ButtonSegment(value: 'subscribe', label: Text('Sub'), icon: Icon(Icons.download, size: 16)),
                  ButtonSegment(value: 'pubsub', label: Text('Pub/Sub'), icon: Icon(Icons.sync_alt, size: 16)),
                ],
                selected: {scope},
                onSelectionChanged: (newSelection) {
                  setDialogState(() => scope = newSelection.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final provider = context.read<ChannelProvider>();
                await provider.apiService.updateDevice(
                  widget.channel.id,
                  dev.id,
                  name: nameCtrl.text.trim(),
                  scope: scope,
                  isActive: isActive,
                );
                await provider.loadDevices(widget.channel.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommandsDialog() {
    final subtopicCtrl = TextEditingController(text: 'commands');
    final payloadCtrl = TextEditingController(
      text: '{\n  "relay": 1,\n  "state": "ON"\n}',
    );
    bool isSending = false;
    String? sendError;
    String? sendSuccess;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.send_to_mobile, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Downlink Device Command'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Publish downstream control actions to IoT devices subscribed to this channel.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subtopicCtrl,
                    decoration: InputDecoration(
                      labelText: 'MQTT Subtopic',
                      hintText: 'commands',
                      prefixText: 'channels/${widget.channel.id}/',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Quick Action Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.power, size: 16, color: Colors.greenAccent),
                        label: const Text('Relay 1 ON', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setDialogState(() {
                            payloadCtrl.text = '{\n  "relay": 1,\n  "state": "ON"\n}';
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.power_off, size: 16, color: Colors.redAccent),
                        label: const Text('Relay 1 OFF', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setDialogState(() {
                            payloadCtrl.text = '{\n  "relay": 1,\n  "state": "OFF"\n}';
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.restart_alt, size: 16, color: Colors.amberAccent),
                        label: const Text('Reboot Node', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setDialogState(() {
                            payloadCtrl.text = '{\n  "cmd": "reboot",\n  "force": true\n}';
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.lightbulb, size: 16, color: Colors.cyanAccent),
                        label: const Text('LED Toggle', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setDialogState(() {
                            payloadCtrl.text = '{\n  "action": "toggle_led",\n  "color": "blue"\n}';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('JSON Command Payload:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: payloadCtrl,
                    maxLines: 6,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '{\n  "key": "value"\n}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (sendError != null) ...[
                    const SizedBox(height: 8),
                    Text(sendError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  if (sendSuccess != null) ...[
                    const SizedBox(height: 8),
                    Text(sendSuccess!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.school_outlined, size: 16),
              label: const Text('Node Code Tutorial'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApiTutorialScreen(
                      channel: widget.channel,
                      initialTabIndex: 3,
                    ),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: isSending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, size: 16),
              label: const Text('Dispatch Command'),
              onPressed: isSending
                  ? null
                  : () async {
                      setDialogState(() {
                        sendError = null;
                        sendSuccess = null;
                      });

                      final rawText = payloadCtrl.text.trim();
                      Map<String, dynamic> parsedJson;
                      try {
                        parsedJson = jsonDecode(rawText) as Map<String, dynamic>;
                      } catch (e) {
                        setDialogState(() {
                          sendError = 'Invalid JSON: $e';
                        });
                        return;
                      }

                      final subtopic = subtopicCtrl.text.trim().isEmpty ? 'commands' : subtopicCtrl.text.trim();

                      setDialogState(() => isSending = true);
                      try {
                        final provider = context.read<ChannelProvider>();
                        final res = await provider.apiService.sendCommand(
                          widget.channel.id,
                          parsedJson,
                          subtopic: subtopic,
                        );
                        setDialogState(() {
                          isSending = false;
                          sendSuccess = 'Dispatched to ${res['topic']} successfully!';
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Dispatched downlink command to ${res['topic']}')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSending = false;
                          sendError = 'Failed to dispatch: $e';
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showImportDialog() {
    final csvCtrl = TextEditingController();
    bool isImporting = false;
    String? statusMsg;
    bool isSuccess = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_upload, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text('Import Historical Data (CSV)'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste CSV data from ThingSpeak or generic IoT platforms. Field columns will be automatically detected and mapped.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: const Text('Load Sample ThingSpeak CSV', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setDialogState(() {
                            final now = DateTime.now().toUtc();
                            final df = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
                            csvCtrl.text =
                                'created_at,entry_id,field1,field2\n'
                                '${df.format(now.subtract(const Duration(minutes: 50)))},1,24.5,60.2\n'
                                '${df.format(now.subtract(const Duration(minutes: 40)))},2,25.1,58.9\n'
                                '${df.format(now.subtract(const Duration(minutes: 30)))},3,23.8,62.1\n'
                                '${df.format(now.subtract(const Duration(minutes: 20)))},4,22.9,64.0\n'
                                '${df.format(now.subtract(const Duration(minutes: 10)))},5,23.2,63.5\n'
                                '${df.format(now)},6,24.0,61.0';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear', style: TextStyle(fontSize: 12)),
                        onPressed: () => setDialogState(() => csvCtrl.clear()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: csvCtrl,
                    maxLines: 8,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'created_at,field1,field2\n2026-11-12T00:00:00Z,23.5,65.0\n...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (statusMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      statusMsg!,
                      style: TextStyle(
                        color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: isImporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload, size: 16),
              label: const Text('Start Import'),
              onPressed: isImporting
                  ? null
                  : () async {
                      final text = csvCtrl.text.trim();
                      if (text.isEmpty) {
                        setDialogState(() {
                          statusMsg = 'Please paste CSV content before importing.';
                          isSuccess = false;
                        });
                        return;
                      }

                      setDialogState(() {
                        isImporting = true;
                        statusMsg = null;
                      });

                      try {
                        final provider = context.read<ChannelProvider>();
                        final res = await provider.apiService.importTelemetryCsv(widget.channel.id, text);
                        final count = res['points_imported'] ?? 0;
                        final fields = (res['fields_discovered'] as List?)?.join(', ') ?? '';

                        await Future.wait([
                          provider.loadFields(widget.channel.id),
                          provider.loadHistoricalData(widget.channel.id, resolution: provider.currentResolution),
                          provider.loadLatestSnapshot(widget.channel.id),
                        ]);

                        setDialogState(() {
                          isImporting = false;
                          isSuccess = true;
                          statusMsg = 'Success! Imported $count points across fields: $fields';
                        });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Successfully imported $count points ($fields)')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isImporting = false;
                          isSuccess = false;
                          statusMsg = 'Import failed: $e';
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    String format = 'csv';
    String range = '24h';
    String resolution = 'raw';
    bool isExporting = false;
    String? exportedData;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text('Export Channel Telemetry'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('File Format:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'csv', label: Text('CSV Spreadsheet'), icon: Icon(Icons.table_chart, size: 16)),
                      ButtonSegment(value: 'json', label: Text('JSON Array'), icon: Icon(Icons.data_object, size: 16)),
                    ],
                    selected: {format},
                    onSelectionChanged: (s) => setDialogState(() => format = s.first),
                  ),
                  const SizedBox(height: 16),
                  const Text('Time Range:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '24h', label: Text('24 Hours')),
                      ButtonSegment(value: '7d', label: Text('7 Days')),
                      ButtonSegment(value: '30d', label: Text('30 Days')),
                      ButtonSegment(value: 'all', label: Text('All Time')),
                    ],
                    selected: {range},
                    onSelectionChanged: (s) => setDialogState(() => range = s.first),
                  ),
                  const SizedBox(height: 16),
                  const Text('Resolution / Aggregation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'raw', label: Text('Raw Points')),
                      ButtonSegment(value: '1m', label: Text('1-Minute Avg')),
                      ButtonSegment(value: '1h', label: Text('1-Hour Avg')),
                    ],
                    selected: {resolution},
                    onSelectionChanged: (s) => setDialogState(() => resolution = s.first),
                  ),
                  if (exportedData != null) ...[
                    const SizedBox(height: 16),
                    const Text('Export Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      height: 120,
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.appColors.codeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.appColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          exportedData!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: context.appColors.codeText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (exportedData != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy to Clipboard'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: exportedData!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exported data copied to clipboard!')),
                  );
                },
              )
            else
              ElevatedButton.icon(
                icon: isExporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_download),
                label: Text(isExporting ? 'Fetching...' : 'Fetch & Export'),
                onPressed: isExporting
                    ? null
                    : () async {
                        setDialogState(() => isExporting = true);
                        try {
                          final now = DateTime.now();
                          DateTime? start;
                          if (range == '24h') start = now.subtract(const Duration(hours: 24));
                          if (range == '7d') start = now.subtract(const Duration(days: 7));
                          if (range == '30d') start = now.subtract(const Duration(days: 30));

                          final provider = context.read<ChannelProvider>();
                          final data = await provider.apiService.exportTelemetry(
                            widget.channel.id,
                            format: format,
                            resolution: resolution,
                            start: start,
                            end: now,
                          );

                          setDialogState(() {
                            isExporting = false;
                            exportedData = data;
                          });
                        } catch (e) {
                          setDialogState(() => isExporting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')),
                            );
                          }
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Clear Telemetry Data'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete all recorded data points and message history for channel "${widget.channel.name}"?\n\n'
          'Channel field definitions will be preserved, but all historical time-series entries will be permanently erased. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<ChannelProvider>();
              try {
                await provider.apiService.clearTelemetry(widget.channel.id);
                await Future.wait([
                  provider.loadFields(widget.channel.id),
                  provider.loadHistoricalData(widget.channel.id, resolution: provider.currentResolution),
                  provider.loadLatestSnapshot(widget.channel.id),
                ]);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All channel telemetry cleared successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to clear data: $e')),
                  );
                }
              }
            },
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
  }

  void _showCredentialsDialog(Device dev) {
    final config = AppConfig();
    Device currentDev = dev;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.vpn_key, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Device Credentials (${currentDev.name})', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'These credentials allow your IoT hardware node to authenticate with the ThingLarp MQTT broker. You can view or copy them anytime.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _CopyableField(label: 'MQTT Broker Host', value: config.mqttHost),
                  const SizedBox(height: 10),
                  _CopyableField(label: 'Port (TLS / Standard)', value: '${config.mqttPort} (MQTTS 8883 / MQTT 1883)'),
                  const SizedBox(height: 10),
                  _CopyableField(label: 'MQTT Username', value: currentDev.mqttUsername),
                  const SizedBox(height: 10),
                  _CopyableField(label: 'MQTT Password', value: currentDev.mqttPassword ?? 'Not saved (Legacy)'),
                  const SizedBox(height: 10),
                  _CopyableField(label: 'Telemetry Publish Topic', value: 'channels/${widget.channel.id}/data'),
                  const SizedBox(height: 10),
                  _CopyableField(label: 'Downlink Subscribe Topic', value: 'channels/${widget.channel.id}/commands'),
                  const SizedBox(height: 10),
                  _CopyableField(label: 'Permission Scope', value: currentDev.scope.toUpperCase()),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16, color: Colors.amberAccent),
              label: const Text('Reset Password'),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('Reset Device Password?'),
                    content: Text('Generate a new MQTT password for "${currentDev.name}"? Any active connection with the old password will be rejected.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Generate New Password'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && ctx.mounted) {
                  try {
                    final provider = ctx.read<ChannelProvider>();
                    final updated = await provider.apiService.resetDevicePassword(widget.channel.id, currentDev.id);
                    await provider.loadDevices(widget.channel.id);
                    setDialogState(() {
                      currentDev = updated;
                    });
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Device password reset successfully!')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to reset password: $e')),
                      );
                    }
                  }
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.code, size: 18),
              label: const Text('MQTT Code Examples'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApiTutorialScreen(
                      channel: widget.channel,
                      initialTabIndex: 3,
                    ),
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApiKeyDetailsDialog(ApiKeyItem key) {
    final config = AppConfig();
    final fullKey = key.apiKey ?? '${key.prefix}***';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              key.scope == 'write' ? Icons.upload : Icons.download,
              color: key.scope == 'write' ? Colors.greenAccent : Colors.blueAccent,
            ),
            const SizedBox(width: 8),
            Text('${key.scope.toUpperCase()} API Key Details'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Use this API key to authenticate HTTP REST requests with the ThingLarp API.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _CopyableField(label: 'API Base URL', value: config.apiUrl),
                const SizedBox(height: 10),
                _CopyableField(label: 'Channel ID', value: widget.channel.id.toString()),
                const SizedBox(height: 10),
                _CopyableField(label: 'API Key (X-API-Key)', value: fullKey),
                const SizedBox(height: 10),
                _CopyableField(label: 'HTTP Auth Header', value: 'X-API-Key: $fullKey'),
                const SizedBox(height: 10),
                _CopyableField(
                  label: key.scope == 'write' ? 'Telemetry Ingest Endpoint' : 'Telemetry Query Endpoint',
                  value: '${config.apiUrl}/channels/${widget.channel.id}/data',
                ),
                const SizedBox(height: 14),
                Text(
                  key.scope == 'write' ? 'Sample Ingest Command (cURL):' : 'Sample Query Command (cURL):',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.appColors.codeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: SelectableText(
                    key.scope == 'write'
                        ? 'curl -X POST "${config.apiUrl}/channels/${widget.channel.id}/data" \\\n  -H "Content-Type: application/json" \\\n  -H "X-API-Key: $fullKey" \\\n  -d \'{"temp": 24.5, "humidity": 60}\''
                        : 'curl -X GET "${config.apiUrl}/channels/${widget.channel.id}/data?resolution=auto" \\\n  -H "X-API-Key: $fullKey"',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: context.appColors.codeText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.code, size: 16),
            label: const Text('View All Tutorials'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ApiTutorialScreen(
                    channel: widget.channel,
                    initialTabIndex: key.scope == 'write' ? 1 : 2,
                  ),
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateApiKeyDialog() {
    String scope = 'write';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generate API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'write',
                    label: Text('Write Key'),
                    icon: Icon(Icons.upload),
                  ),
                  ButtonSegment<String>(
                    value: 'read',
                    label: Text('Read Key'),
                    icon: Icon(Icons.download),
                  ),
                ],
                selected: {scope},
                onSelectionChanged: (newSelection) {
                  setDialogState(() => scope = newSelection.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final provider = context.read<ChannelProvider>();
                final keyItem = await provider.apiService.createApiKey(widget.channel.id, scope);
                await provider.loadApiKeys(widget.channel.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && keyItem.apiKey != null) {
                  _showApiKeyCreatedDialog(keyItem.apiKey!);
                }
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApiKeyCreatedDialog(String keyStr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use this key in your HTTP requests as header:\nX-API-Key: <key>',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _CopyableField(label: 'API Key', value: keyStr),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.code, size: 18),
            label: const Text('View API Code Snippets'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ApiTutorialScreen(
                    channel: widget.channel,
                    initialTabIndex: 1,
                  ),
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChannelProvider>();
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(widget.channel.name, overflow: TextOverflow.ellipsis)),
            if (widget.isReadOnly) ...[
              const SizedBox(width: 8),
              AppStatusPill(label: 'VIEW ONLY', color: colors.primary),
            ],
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: AppThemeToggleButton(),
          ),
          if (widget.isReadOnly) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Telemetry',
              onPressed: () {
                provider.loadFields(widget.channel.id);
                provider.loadHistoricalData(widget.channel.id, resolution: provider.currentResolution);
                provider.loadLatestSnapshot(widget.channel.id);
              },
            ),
            IconButton(
              icon: Icon(Icons.share, color: colors.accentTeal),
              tooltip: 'Share Public Link',
              onPressed: _shareChannelLink,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login, size: 16),
                label: const Text('Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.share, color: colors.accentTeal),
              tooltip: 'Share Public Link',
              onPressed: _shareChannelLink,
            ),
            IconButton(
              icon: Icon(Icons.send_to_mobile, color: colors.warning),
              tooltip: 'Downlink Commands',
              onPressed: _showCommandsDialog,
            ),
            IconButton(
              icon: Icon(Icons.school_outlined, color: colors.accentCyan),
              tooltip: 'API Tutorials & Code Generator',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApiTutorialScreen(channel: widget.channel),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Channel Actions',
              onSelected: (val) {
                if (val == 'export') _showExportDialog();
                if (val == 'import') _showImportDialog();
                if (val == 'clear') _showClearDataDialog();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20, color: colors.accentCyan),
                      const SizedBox(width: 10),
                      const Text('Download / Export Data'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, size: 20, color: colors.accentTeal),
                      const SizedBox(width: 10),
                      const Text('Import Data (CSV)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 20, color: colors.danger),
                      const SizedBox(width: 10),
                      const Text('Clear All Telemetry Data'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: widget.isReadOnly
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard_outlined), text: 'Telemetry'),
                  Tab(icon: Icon(Icons.memory), text: 'Devices'),
                  Tab(icon: Icon(Icons.key), text: 'API Keys'),
                ],
              ),
      ),
      body: widget.isReadOnly
          ? _buildTelemetryTab(provider)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTelemetryTab(provider),
                _buildDevicesTab(provider),
                _buildApiKeysTab(provider),
              ],
            ),
    );
  }

  static const List<int> _presetLimits = [50, 100, 500, 1000, 5000, 10000];

  Future<void> _showCustomLimitDialog(ChannelProvider provider) async {
    final ctrl = TextEditingController(text: provider.pointLimit.toString());
    String? errorText;

    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Custom Data Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the number of newest points per field to display (1 – 10,000):',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Points per field',
                  hintText: 'e.g. 250',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  final parsed = int.tryParse(ctrl.text.trim());
                  if (parsed == null || parsed < 1 || parsed > ChannelProvider.maxPointLimit) {
                    setDialogState(() => errorText = 'Enter a value between 1 and ${ChannelProvider.maxPointLimit}');
                  } else {
                    Navigator.pop(ctx, parsed);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(ctrl.text.trim());
                if (parsed == null || parsed < 1 || parsed > ChannelProvider.maxPointLimit) {
                  setDialogState(() => errorText = 'Enter a value between 1 and ${ChannelProvider.maxPointLimit}');
                } else {
                  Navigator.pop(ctx, parsed);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (chosen != null && mounted) {
      await provider.loadHistoricalData(widget.channel.id, limit: chosen);
    }
  }

  Widget _buildCompactDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
  }) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: colors.primary),
            const SizedBox(width: 6),
          ],
          DropdownButton<T>(
            value: value,
            isDense: true,
            underline: const SizedBox(),
            style: TextStyle(fontSize: 13, color: colors.textPrimary, fontWeight: FontWeight.w500),
            dropdownColor: colors.surfaceCard,
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTab(ChannelProvider provider) {
    final colors = context.appColors;
    final mqttState = provider.mqttService.currentState;
    final isPollingOnly = widget.isReadOnly && !provider.apiService.isAuthenticated;
    final syncTimeStr = provider.lastSyncedAt != null
        ? ' • Updated ${DateFormat('HH:mm:ss').format(provider.lastSyncedAt!.toLocal())}'
        : '';

    final limitOptions = List<int>.from(_presetLimits);
    if (!limitOptions.contains(provider.pointLimit)) {
      limitOptions.add(provider.pointLimit);
      limitOptions.sort();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          provider.loadFields(widget.channel.id),
          provider.refreshTelemetry(widget.channel.id),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live status bar
          AppSurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: 14,
            child: Row(
              children: [
                _StatusIndicator(
                  state: mqttState,
                  isPolling: isPollingOnly,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPollingOnly
                            ? 'Live Telemetry (Auto-Refresh 10s)'
                            : mqttState == BrokerState.connected
                                ? 'Live Sync (MQTT Trigger → API)'
                                : mqttState == BrokerState.connecting
                                    ? 'Connecting to Trigger Socket...'
                                    : 'Offline / Historical View',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (syncTimeStr.isNotEmpty)
                        Text(
                          'Showing up to ${provider.pointLimit} pts$syncTimeStr',
                          style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (isPollingOnly)
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: colors.accentTeal),
                    tooltip: 'Refresh Telemetry',
                    onPressed: () {
                      provider.loadFields(widget.channel.id);
                      provider.refreshTelemetry(widget.channel.id);
                    },
                  )
                else
                  IconButton(
                    icon: Icon(
                      provider.isLiveStreaming
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: provider.isLiveStreaming
                          ? colors.warning
                          : colors.success,
                    ),
                    tooltip: provider.isLiveStreaming
                        ? 'Pause Live Sync'
                        : 'Resume Live Sync',
                    onPressed: () {
                      if (provider.isLiveStreaming) {
                        provider.stopLiveStream();
                      } else {
                        provider.startLiveStream();
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Telemetry Header & Data Amount / Resolution Controls
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Telemetry Fields',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Time Window selector
              _buildCompactDropdown<String>(
                icon: Icons.schedule,
                value: provider.timeWindow,
                items: const [
                  DropdownMenuItem(value: '15m', child: Text('Last 15m')),
                  DropdownMenuItem(value: '1h', child: Text('Last 1h')),
                  DropdownMenuItem(value: '6h', child: Text('Last 6h')),
                  DropdownMenuItem(value: '24h', child: Text('Last 24h')),
                  DropdownMenuItem(value: '7d', child: Text('Last 7d')),
                  DropdownMenuItem(value: '30d', child: Text('Last 30d')),
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.loadHistoricalData(widget.channel.id, window: val);
                  }
                },
              ),
              // Point Limit selector (presets + custom)
              _buildCompactDropdown<int>(
                icon: Icons.format_list_numbered,
                value: provider.pointLimit,
                items: [
                  ...limitOptions.map(
                    (n) => DropdownMenuItem<int>(
                      value: n,
                      child: Text('$n pts'),
                    ),
                  ),
                  const DropdownMenuItem<int>(
                    value: -1,
                    child: Text('Custom...'),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  if (val == -1) {
                    _showCustomLimitDialog(provider);
                  } else {
                    provider.loadHistoricalData(widget.channel.id, limit: val);
                  }
                },
              ),
              // Resolution selector
              _buildCompactDropdown<String>(
                icon: Icons.tune,
                value: provider.currentResolution,
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto Res')),
                  DropdownMenuItem(value: 'raw', child: Text('Raw Points')),
                  DropdownMenuItem(value: '1m', child: Text('1-min Avg')),
                  DropdownMenuItem(value: '1h', child: Text('1-hour Avg')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.loadHistoricalData(widget.channel.id, resolution: val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Snapshot Cards Grid (Dynamic / Unlimited Fields)
          if (provider.latestValues.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: provider.latestValues.entries.map((entry) {
                final fieldMeta = provider.fields.firstWhere(
                  (f) => f.key == entry.key,
                  orElse: () => ChannelField(
                    id: 0,
                    channelId: widget.channel.id,
                    key: entry.key,
                    valueType: 'string',
                    firstSeenAt: DateTime.now(),
                  ),
                );

                return _MetricCard(
                  keyName: fieldMeta.displayName,
                  value: entry.value,
                  unit: fieldMeta.unit,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Error / Loading / Multi-Type Dynamic Widget Cards for each numeric field
          if (provider.telemetryError != null) ...[
            AppSurfaceCard(
              borderColor: colors.danger.withValues(alpha: 0.45),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: colors.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Could not load historical telemetry: ${provider.telemetryError}',
                      style: TextStyle(color: colors.danger, fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => provider.loadHistoricalData(widget.channel.id),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (provider.isLoadingTelemetry &&
              (provider.chartPoints.isEmpty ||
                  provider.chartPoints.values.every((pts) => pts.isEmpty)))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.chartPoints.isEmpty ||
              provider.chartPoints.values.every((pts) => pts.isEmpty))
            AppSurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.timeline_rounded, size: 36, color: colors.textTertiary),
                  const SizedBox(height: 10),
                  Text(
                    provider.timeWindow == 'all'
                        ? 'No telemetry points recorded yet for this channel.'
                        : 'No telemetry points in the selected window (${provider.timeWindow}).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (provider.timeWindow != 'all')
                        ElevatedButton.icon(
                          onPressed: () => provider.loadHistoricalData(
                            widget.channel.id,
                            window: 'all',
                          ),
                          icon: const Icon(Icons.history_rounded, size: 17),
                          label: const Text('Show All Time'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => provider.refreshTelemetry(widget.channel.id),
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            ...provider.chartPoints.entries
                .where((entry) => entry.value.isNotEmpty)
                .map((entry) {
              final fieldKey = entry.key;
              final points = entry.value;
              final fieldMeta = provider.fields.firstWhere(
                (f) => f.key == fieldKey,
                orElse: () => ChannelField(
                  id: 0,
                  channelId: widget.channel.id,
                  key: fieldKey,
                  valueType: 'number',
                  widgetType: 'line',
                  firstSeenAt: DateTime.now(),
                ),
              );

              final menu = _buildWidgetTypeMenu(context, fieldMeta);

              switch (fieldMeta.widgetType) {
                case 'gauge':
                  return _RadialGaugeCard(
                    field: fieldMeta,
                    points: points,
                    menuButton: menu,
                  );
                case 'kpi':
                  return _KpiMetricCard(
                    field: fieldMeta,
                    points: points,
                    menuButton: menu,
                  );
                case 'status':
                  return _StatusIndicatorCard(
                    field: fieldMeta,
                    points: points,
                    menuButton: menu,
                  );
                case 'line':
                default:
                  return _TimeSeriesChartCard(
                    fieldLabel: fieldMeta.displayName,
                    unit: fieldMeta.unit,
                    points: points,
                    menuButton: menu,
                  );
              }
            }),
        ],
      ),
    );
  }

  Widget _buildWidgetTypeMenu(BuildContext context, ChannelField field) {
    if (widget.isReadOnly || field.id <= 0) return const SizedBox();
    final colors = context.appColors;
    return PopupMenuButton<String>(
      icon: Icon(Icons.tune_rounded, size: 18, color: colors.textSecondary),
      tooltip: 'Change Widget Type',
      onSelected: (newType) async {
        try {
          final provider = context.read<ChannelProvider>();
          await provider.updateFieldWidgetType(field.channelId, field.id, newType);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update widget type: $e')),
            );
          }
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'line',
          child: Row(
            children: [
              Icon(Icons.show_chart, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              const Text('Line Chart'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'gauge',
          child: Row(
            children: [
              Icon(Icons.speed, size: 18, color: colors.accentCyan),
              const SizedBox(width: 8),
              const Text('Radial Gauge'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'kpi',
          child: Row(
            children: [
              Icon(Icons.pin_outlined, size: 18, color: colors.warning),
              const SizedBox(width: 8),
              const Text('KPI Metric Card'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'status',
          child: Row(
            children: [
              Icon(Icons.radio_button_checked, size: 18, color: colors.success),
              const SizedBox(width: 8),
              const Text('Status / LED Indicator'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesTab(ChannelProvider provider) {
    final config = AppConfig();
    final colors = context.appColors;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Info Banner
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colors.warning.withValues(alpha: 0.35)),
            ),
            color: colors.warning.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hub, size: 18, color: colors.warning),
                      const SizedBox(width: 8),
                      const Text('MQTT Broker Connection Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _CopyableBadge(label: 'Host', value: config.mqttHost)),
                      const SizedBox(width: 8),
                      Expanded(child: _CopyableBadge(label: 'Port', value: '${config.mqttPort} (MQTTS 8883 / MQTT 1883)')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _CopyableBadge(label: 'Pub Topic', value: 'channels/${widget.channel.id}/data')),
                      const SizedBox(width: 8),
                      Expanded(child: _CopyableBadge(label: 'Sub Topic', value: 'channels/${widget.channel.id}/commands')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: colors.accentTeal.withValues(alpha: 0.09),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colors.accentTeal.withValues(alpha: 0.35)),
            ),
            child: ListTile(
              leading: Icon(Icons.school, color: colors.accentTeal),
              title: const Text('MQTT Device Tutorials & Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('View ESP32 (Arduino / MicroPython) and Python MQTT streaming code examples.', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApiTutorialScreen(channel: widget.channel, initialTabIndex: 3),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (provider.devices.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.memory, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No Devices Provisioned', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Add an ESP32 or sensor node to generate MQTT credentials.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddDeviceDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Device'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...provider.devices.map((dev) => _DeviceItemCard(
                  key: ValueKey(dev.id),
                  device: dev,
                  channelId: widget.channel.id,
                  onEdit: () => _showEditDeviceDialog(dev),
                  onViewCredentials: () => _showCredentialsDialog(dev),
                  onToggleActive: (val) async {
                    await provider.apiService.updateDevice(widget.channel.id, dev.id, isActive: val);
                    await provider.loadDevices(widget.channel.id);
                  },
                  onDelete: () async {
                    await provider.apiService.deleteDevice(widget.channel.id, dev.id);
                    await provider.loadDevices(widget.channel.id);
                  },
                  onResetPassword: () async {
                    try {
                      final updated = await provider.apiService.resetDevicePassword(widget.channel.id, dev.id);
                      await provider.loadDevices(widget.channel.id);
                      if (mounted) {
                        _showCredentialsDialog(updated);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to reset password: $e')),
                        );
                      }
                    }
                  },
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeviceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }

  Widget _buildApiKeysTab(ChannelProvider provider) {
    final config = AppConfig();
    final colors = context.appColors;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Info Banner
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colors.accentCyan.withValues(alpha: 0.35)),
            ),
            color: colors.accentCyan.withValues(alpha: 0.07),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.http, size: 20, color: colors.accentCyan),
                      const SizedBox(width: 8),
                      const Text('HTTP REST API Connection Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _CopyableBadge(label: 'API Base URL', value: config.apiUrl)),
                      const SizedBox(width: 8),
                      Expanded(child: _CopyableBadge(label: 'Channel ID', value: widget.channel.id.toString())),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _CopyableBadge(label: 'Auth Header', value: 'X-API-Key: <key>')),
                      const SizedBox(width: 8),
                      Expanded(child: _CopyableBadge(label: 'Data Route', value: '/channels/${widget.channel.id}/data')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: colors.accentCyan.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colors.accentCyan.withValues(alpha: 0.35)),
            ),
            child: ListTile(
              leading: Icon(Icons.integration_instructions, color: colors.accentCyan),
              title: const Text('HTTP REST API Tutorials & Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('View pre-filled cURL, Python, JavaScript, and ESP32 HTTP POST examples.', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApiTutorialScreen(channel: widget.channel, initialTabIndex: 1),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (provider.apiKeys.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.key_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No API Keys Generated', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Create an API key to ingest data via standard HTTP POST requests.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showCreateApiKeyDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Generate API Key'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...provider.apiKeys.map((k) => _ApiKeyCardItem(
                  key: ValueKey(k.id),
                  apiKeyItem: k,
                  onViewDetails: () => _showApiKeyDetailsDialog(k),
                  onDelete: () async {
                    await provider.apiService.deleteApiKey(widget.channel.id, k.id);
                    await provider.loadApiKeys(widget.channel.id);
                  },
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateApiKeyDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Key'),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widgets
// -----------------------------------------------------------------------------
class _StatusIndicator extends StatelessWidget {
  final BrokerState state;
  final bool isPolling;

  const _StatusIndicator({required this.state, this.isPolling = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isPolling
        ? colors.accentTeal
        : state == BrokerState.connected
            ? colors.success
            : state == BrokerState.connecting
                ? colors.warning
                : colors.textTertiary;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isPolling || state == BrokerState.connected
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)]
            : null,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String keyName;
  final dynamic value;
  final String? unit;

  const _MetricCard({required this.keyName, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final valStr = value is double ? value.toStringAsFixed(2) : value.toString();

    return Container(
      width: 156,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(color: colors.shadow, blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            keyName,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  valStr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeSeriesChartCard extends StatelessWidget {
  final String fieldLabel;
  final String? unit;
  final List<TelemetryPoint> points;
  final Widget? menuButton;

  const _TimeSeriesChartCard({
    required this.fieldLabel,
    this.unit,
    required this.points,
    this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();

    final colors = context.appColors;
    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }

    final double minVal = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final double maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final double latestVal = points.last.value;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fieldLabel + (unit != null ? ' ($unit)' : ''),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                AppStatusPill(
                  label: 'Now ${latestVal.toStringAsFixed(2)}${unit != null ? " $unit" : ""}',
                  color: colors.primary,
                ),
                if (menuButton != null) ...[
                  const SizedBox(width: 6),
                  menuButton!,
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Min: ${minVal.toStringAsFixed(2)}  •  Max: ${maxVal.toStringAsFixed(2)}  •  Samples: ${points.length}',
              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: colors.chartGrid,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (val, meta) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            val.toStringAsFixed(val.abs() >= 100 ? 0 : 1),
                            style: TextStyle(fontSize: 10, color: colors.textTertiary),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => colors.surfaceElevated,
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map(
                            (spot) => LineTooltipItem(
                              spot.y.toStringAsFixed(2),
                              TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: points.length <= 300,
                      color: colors.primary,
                      barWidth: points.length > 1000 ? 1.5 : 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            colors.primary.withValues(alpha: 0.24),
                            colors.primary.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialGaugeCard extends StatelessWidget {
  final ChannelField field;
  final List<TelemetryPoint> points;
  final Widget? menuButton;

  const _RadialGaugeCard({
    required this.field,
    required this.points,
    this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    final double latestVal = points.isNotEmpty ? points.last.value : 0.0;
    final double minVal = points.isNotEmpty
        ? points.map((p) => p.value).reduce((a, b) => a < b ? a : b)
        : 0.0;
    final double maxVal = points.isNotEmpty
        ? points.map((p) => p.value).reduce((a, b) => a > b ? a : b)
        : (latestVal > 0 ? latestVal * 1.5 : 100.0);

    final range = (maxVal - minVal);
    final double pct = range > 0 ? ((latestVal - minVal) / range).clamp(0.0, 1.0) : 0.5;

    final colors = context.appColors;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.speed, size: 20, color: colors.accentCyan),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          field.displayName + (field.unit != null ? ' (${field.unit})' : ''),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ?menuButton,
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              width: 220,
              child: CustomPaint(
                painter: _GaugePainter(
                  percent: pct,
                  valueText: latestVal.toStringAsFixed(1),
                  unitText: field.unit ?? '',
                  minText: minVal.toStringAsFixed(1),
                  maxText: maxVal.toStringAsFixed(1),
                  valueColor: colors.textPrimary,
                  mutedColor: colors.textSecondary,
                  trackColor: colors.gaugeTrack,
                  gradientColors: [colors.accentTeal, colors.accentCyan, colors.primary],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Min: ${minVal.toStringAsFixed(2)}  •  Max: ${maxVal.toStringAsFixed(2)}  •  Samples: ${points.length}',
              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final String valueText;
  final String unitText;
  final String minText;
  final String maxText;
  final Color valueColor;
  final Color mutedColor;
  final Color trackColor;
  final List<Color> gradientColors;

  _GaugePainter({
    required this.percent,
    required this.valueText,
    required this.unitText,
    required this.minText,
    required this.maxText,
    required this.valueColor,
    required this.mutedColor,
    required this.trackColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6);
    final radius = math.min(size.width / 2, size.height * 0.6) - 14;

    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    // Background Arc
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Active Gradient Arc
    final activePaint = Paint()
      ..shader = SweepGradient(
        colors: gradientColors,
        startAngle: 0.0,
        endAngle: math.pi * 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final currentSweep = sweepAngle * percent.clamp(0.01, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentSweep,
      false,
      activePaint,
    );

    // Value Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: valueText,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: valueColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2 - 6),
    );

    // Unit Text
    if (unitText.isNotEmpty) {
      final unitPainter = TextPainter(
        text: TextSpan(
          text: unitText,
          style: TextStyle(fontSize: 12, color: mutedColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      unitPainter.paint(
        canvas,
        Offset(center.dx - unitPainter.width / 2, center.dy + textPainter.height / 2 - 4),
      );
    }

    // Min / Max labels at arc tips
    final minPainter = TextPainter(
      text: TextSpan(text: minText, style: TextStyle(fontSize: 10, color: mutedColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    minPainter.paint(canvas, Offset(center.dx - radius - 10, center.dy + radius * 0.45));

    final maxPainter = TextPainter(
      text: TextSpan(text: maxText, style: TextStyle(fontSize: 10, color: mutedColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    maxPainter.paint(canvas, Offset(center.dx + radius - maxPainter.width + 10, center.dy + radius * 0.45));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.valueText != valueText ||
        oldDelegate.unitText != unitText ||
        oldDelegate.valueColor != valueColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class _KpiMetricCard extends StatelessWidget {
  final ChannelField field;
  final List<TelemetryPoint> points;
  final Widget? menuButton;

  const _KpiMetricCard({
    required this.field,
    required this.points,
    this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final double latestVal = points.isNotEmpty ? points.last.value : 0.0;
    final double minVal = points.isNotEmpty
        ? points.map((p) => p.value).reduce((a, b) => a < b ? a : b)
        : 0.0;
    final double maxVal = points.isNotEmpty
        ? points.map((p) => p.value).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final double avgVal = points.isNotEmpty
        ? points.map((p) => p.value).reduce((a, b) => a + b) / points.length
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.pin_outlined, size: 20, color: colors.warning),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          field.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ?menuButton,
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  latestVal.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: colors.warning,
                    letterSpacing: -1,
                  ),
                ),
                if (field.unit != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    field.unit!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Min', value: minVal.toStringAsFixed(2), color: colors.primary),
                  _StatItem(label: 'Average', value: avgVal.toStringAsFixed(2), color: colors.accentCyan),
                  _StatItem(label: 'Max', value: maxVal.toStringAsFixed(2), color: colors.warning),
                  _StatItem(label: 'Samples', value: points.length.toString(), color: colors.textPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _StatusIndicatorCard extends StatelessWidget {
  final ChannelField field;
  final List<TelemetryPoint> points;
  final Widget? menuButton;

  const _StatusIndicatorCard({
    required this.field,
    required this.points,
    this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final double latestVal = points.isNotEmpty ? points.last.value : 0.0;
    final bool isActive = latestVal > 0.0;
    final stateColor = isActive ? colors.success : colors.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: stateColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 20,
                          color: stateColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          field.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                ?menuButton,
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stateColor.withValues(alpha: 0.14),
                      border: Border.all(
                        color: stateColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: stateColor.withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isActive ? Icons.power : Icons.power_off,
                      size: 42,
                      color: stateColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isActive ? 'STATE: ACTIVE / ON' : 'STATE: INACTIVE / OFF',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: stateColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Raw Value: ${latestVal.toStringAsFixed(2)}${field.unit != null ? " ${field.unit}" : ""}',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Total Samples Recorded: ${points.length}',
              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyableField extends StatelessWidget {
  final String label;
  final String value;

  const _CopyableField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied $label to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CopyableBadge extends StatelessWidget {
  final String label;
  final String value;

  const _CopyableBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied $label: $value')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.appColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: context.appColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.appColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.copy, size: 14, color: context.appColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _DeviceItemCard extends StatefulWidget {
  final Device device;
  final int channelId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewCredentials;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onResetPassword;

  const _DeviceItemCard({
    super.key,
    required this.device,
    required this.channelId,
    required this.onEdit,
    required this.onDelete,
    required this.onViewCredentials,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  @override
  State<_DeviceItemCard> createState() => _DeviceItemCardState();
}

class _DeviceItemCardState extends State<_DeviceItemCard> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dev = widget.device;
    final Color scopeColor;
    final String scopeLabel;
    if (dev.scope == 'pubsub') {
      scopeColor = colors.accentTeal;
      scopeLabel = 'PUB & SUB';
    } else if (dev.scope == 'subscribe') {
      scopeColor = colors.primary;
      scopeLabel = 'SUB ONLY';
    } else {
      scopeColor = colors.success;
      scopeLabel = 'PUB ONLY';
    }

    final hasPassword = dev.mqttPassword != null && dev.mqttPassword!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: dev.isActive
                      ? colors.accentCyan.withValues(alpha: 0.14)
                      : colors.surfaceElevated,
                  child: Icon(
                    Icons.memory,
                    color: dev.isActive ? colors.accentCyan : colors.textTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          dev.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scopeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: scopeColor.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          scopeLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: scopeColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: dev.isActive,
                  activeThumbColor: colors.success,
                  onChanged: widget.onToggleActive,
                ),
                IconButton(
                  icon: Icon(Icons.vpn_key_outlined, size: 20, color: colors.warning),
                  tooltip: 'View Credentials',
                  onPressed: widget.onViewCredentials,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit Access Scope',
                  onPressed: widget.onEdit,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.danger, size: 20),
                  tooltip: 'Delete Device',
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const Divider(height: 16),
            // Username and Password Row
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('User: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Flexible(
                        child: Text(
                          dev.mqttUsername,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: dev.mqttUsername));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied MQTT Username')),
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.copy, size: 14, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Text('Pass: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      if (hasPassword) ...[
                        Flexible(
                          child: Text(
                            _showPassword ? dev.mqttPassword! : '••••••••••••',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _showPassword = !_showPassword),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.grey),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: dev.mqttPassword!));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied MQTT Password')),
                              );
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.copy, size: 14, color: Colors.grey),
                          ),
                        ),
                      ] else ...[
                        const Flexible(
                          child: Text(
                            'Not saved',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: widget.onResetPassword,
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.appColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiKeyCardItem extends StatefulWidget {
  final ApiKeyItem apiKeyItem;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;

  const _ApiKeyCardItem({
    super.key,
    required this.apiKeyItem,
    required this.onViewDetails,
    required this.onDelete,
  });

  @override
  State<_ApiKeyCardItem> createState() => _ApiKeyCardItemState();
}

class _ApiKeyCardItemState extends State<_ApiKeyCardItem> {
  bool _showKey = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final k = widget.apiKeyItem;
    final hasFullKey = k.apiKey != null && k.apiKey!.isNotEmpty;
    final scopeColor = k.scope == 'write' ? colors.success : colors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scopeColor.withValues(alpha: 0.14),
                  child: Icon(
                    k.scope == 'write' ? Icons.upload : Icons.download,
                    color: scopeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${k.scope.toUpperCase()} API KEY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Created ${DateFormat.yMMMd().format(k.createdAt)}',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, size: 20, color: colors.accentCyan),
                  tooltip: 'View API Details & Snippets',
                  onPressed: widget.onViewDetails,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.danger, size: 20),
                  tooltip: 'Revoke Key',
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                const Text('Key: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                if (hasFullKey) ...[
                  Flexible(
                    child: Text(
                      _showKey ? k.apiKey! : ('•' * 28),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _showKey = !_showKey),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(_showKey ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.grey),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: k.apiKey!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied API Key to clipboard')),
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.copy, size: 14, color: Colors.grey),
                    ),
                  ),
                ] else ...[
                  Flexible(
                    child: Text(
                      '${k.prefix}*** (Legacy key)',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
