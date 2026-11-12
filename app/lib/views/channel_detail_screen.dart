import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/channel.dart';
import '../models/telemetry.dart';
import '../providers/channel_provider.dart';
import '../services/mqtt_service.dart';
import 'api_tutorial_screen.dart';

class ChannelDetailScreen extends StatefulWidget {
  final Channel channel;

  const ChannelDetailScreen({super.key, required this.channel});

  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddDeviceDialog() {
    final nameCtrl = TextEditingController(text: 'ESP32_Node_1');
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
                  hintText: 'e.g. Field Sensor Node',
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          exportedData!,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.amber),
            SizedBox(width: 8),
            Text('Device Credentials'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy these credentials now. The MQTT password is only shown once and cannot be retrieved later.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _CopyableField(label: 'MQTT Username', value: dev.mqttUsername),
            const SizedBox(height: 12),
            _CopyableField(label: 'MQTT Password', value: dev.mqttPassword ?? 'N/A'),
            const SizedBox(height: 12),
            _CopyableField(label: 'Topic', value: 'channels/${widget.channel.id}/data'),
          ],
        ),
        actions: [
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
            child: const Text('I Have Saved Them'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.school_outlined, color: Colors.cyanAccent),
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
              if (val == 'clear') _showClearDataDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20, color: Colors.cyanAccent),
                    SizedBox(width: 10),
                    Text('Download / Export Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Clear All Telemetry Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Telemetry'),
            Tab(icon: Icon(Icons.memory), text: 'Devices'),
            Tab(icon: Icon(Icons.key), text: 'API Keys'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Telemetry Dashboard
          _buildTelemetryTab(provider),
          // Tab 2: Hardware Devices
          _buildDevicesTab(provider),
          // Tab 3: API Keys
          _buildApiKeysTab(provider),
        ],
      ),
    );
  }

  Widget _buildTelemetryTab(ChannelProvider provider) {
    final mqttState = provider.mqttService.currentState;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          provider.loadFields(widget.channel.id),
          provider.loadHistoricalData(widget.channel.id, resolution: provider.currentResolution),
          provider.loadLatestSnapshot(widget.channel.id),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live status bar
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _StatusIndicator(state: mqttState),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      mqttState == BrokerState.connected
                          ? 'Streaming Live Data (QoS 1)'
                          : mqttState == BrokerState.connecting
                              ? 'Connecting to Broker...'
                              : 'Offline / Historical View',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      provider.isLiveStreaming ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: provider.isLiveStreaming ? Colors.orange : Colors.green,
                    ),
                    tooltip: provider.isLiveStreaming ? 'Pause Stream' : 'Resume Stream',
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
          ),
          const SizedBox(height: 16),

          // Resolution Picker Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Telemetry Fields',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: provider.currentResolution,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto Resolution')),
                  DropdownMenuItem(value: 'raw', child: Text('Raw Points')),
                  DropdownMenuItem(value: '1m', child: Text('1-min Averages')),
                  DropdownMenuItem(value: '1h', child: Text('1-hour Averages')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.loadHistoricalData(widget.channel.id, resolution: val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

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

          // Time-series Charts for each numeric field
          if (provider.chartPoints.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No telemetry points recorded yet for this channel.'),
              ),
            )
          else
            ...provider.chartPoints.entries.map((entry) {
              final fieldKey = entry.key;
              final points = entry.value;
              final fieldMeta = provider.fields.firstWhere(
                (f) => f.key == fieldKey,
                orElse: () => ChannelField(
                  id: 0,
                  channelId: widget.channel.id,
                  key: fieldKey,
                  valueType: 'number',
                  firstSeenAt: DateTime.now(),
                ),
              );

              return _TimeSeriesChartCard(
                fieldLabel: fieldMeta.displayName,
                unit: fieldMeta.unit,
                points: points,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDevicesTab(ChannelProvider provider) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.teal.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: const Icon(Icons.school, color: Colors.tealAccent),
              title: const Text('MQTT Device Tutorials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
            ...provider.devices.map((dev) {
              Color scopeColor;
              String scopeLabel;
              if (dev.scope == 'pubsub') {
                scopeColor = Colors.purpleAccent;
                scopeLabel = 'PUB & SUB';
              } else if (dev.scope == 'subscribe') {
                scopeColor = Colors.blueAccent;
                scopeLabel = 'SUB ONLY';
              } else {
                scopeColor = Colors.greenAccent;
                scopeLabel = 'PUB ONLY';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: dev.isActive ? Colors.cyan.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                        child: Icon(Icons.memory, color: dev.isActive ? Colors.cyanAccent : Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: scopeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: scopeColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    scopeLabel,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: scopeColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('MQTT User: ${dev.mqttUsername}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Switch(
                        value: dev.isActive,
                        activeThumbColor: Colors.greenAccent,
                        onChanged: (val) async {
                          await provider.apiService.updateDevice(widget.channel.id, dev.id, isActive: val);
                          await provider.loadDevices(widget.channel.id);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit Access Control',
                        onPressed: () => _showEditDeviceDialog(dev),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          await provider.apiService.deleteDevice(widget.channel.id, dev.id);
                          await provider.loadDevices(widget.channel.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
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
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.cyan.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: const Icon(Icons.integration_instructions, color: Colors.cyanAccent),
              title: const Text('HTTP REST API Tutorials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
            ...provider.apiKeys.map((k) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: k.scope == 'write' ? Colors.green.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                      child: Icon(k.scope == 'write' ? Icons.upload : Icons.download, color: k.scope == 'write' ? Colors.green : Colors.blue),
                    ),
                    title: Text('${k.scope.toUpperCase()} KEY (${k.prefix}***)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Created ${DateFormat.yMMMd().format(k.createdAt)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        await provider.apiService.deleteApiKey(widget.channel.id, k.id);
                        await provider.loadApiKeys(widget.channel.id);
                      },
                    ),
                  ),
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

  const _StatusIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = state == BrokerState.connected
        ? Colors.green
        : state == BrokerState.connecting
            ? Colors.orange
            : Colors.grey;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    final valStr = value is double ? value.toStringAsFixed(2) : value.toString();

    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            keyName,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  const _TimeSeriesChartCard({
    required this.fieldLabel,
    this.unit,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].value));
    }

    final double minVal = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final double maxVal = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final double latestVal = points.last.value;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fieldLabel + (unit != null ? ' ($unit)' : ''),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Now: ${latestVal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Min: ${minVal.toStringAsFixed(2)}  •  Max: ${maxVal.toStringAsFixed(2)}  •  Samples: ${points.length}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blueAccent,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blueAccent.withValues(alpha: 0.12),
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
