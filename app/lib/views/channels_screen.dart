import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import 'channel_detail_screen.dart';
import 'settings_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChannelProvider>().loadChannels();
    });
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Channel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Channel Name',
                  hintText: 'e.g. Garden Station',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Public Channel'),
                subtitle: const Text('Allow anyone to read telemetry'),
                value: isPublic,
                onChanged: (val) {
                  setDialogState(() {
                    isPublic = val;
                  });
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
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);
                  final provider = context.read<ChannelProvider>();
                  final channel = await provider.createChannel(name, descCtrl.text.trim(), isPublic);
                  navigator.pop();
                  if (channel != null) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Channel "${channel.name}" created!')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final channelProv = context.watch<ChannelProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Channels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: channelProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : channelProv.channels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sensors_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No Channels Yet',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Create your first IoT channel to start receiving data.'),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('New Channel'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => channelProv.loadChannels(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: channelProv.channels.length,
                    itemBuilder: (context, index) {
                      final ch = channelProv.channels[index];
                      final dateStr = DateFormat.yMMMd().format(ch.createdAt);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                            child: const Icon(Icons.sensors, color: Colors.blueAccent),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ch.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              if (ch.isPublic)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'PUBLIC',
                                    style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(ch.description ?? 'No description', maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('Created $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            channelProv.selectChannel(ch);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChannelDetailScreen(channel: ch),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Channel'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
