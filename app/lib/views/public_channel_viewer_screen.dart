import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import 'channel_detail_screen.dart';
import 'login_screen.dart';

class PublicChannelViewerScreen extends StatefulWidget {
  final int channelId;

  const PublicChannelViewerScreen({super.key, required this.channelId});

  @override
  State<PublicChannelViewerScreen> createState() => _PublicChannelViewerScreenState();
}

class _PublicChannelViewerScreenState extends State<PublicChannelViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Channel? _channel;

  @override
  void initState() {
    super.initState();
    _loadPublicChannel();
  }

  Future<void> _loadPublicChannel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prov = context.read<ChannelProvider>();
    final auth = context.read<AuthProvider>();

    try {
      final channel = await prov.apiService.getChannel(widget.channelId);
      final isOwner = auth.isAuthenticated && auth.currentUser?.id == channel.ownerId;
      await prov.selectChannel(channel, isReadOnly: !isOwner);

      if (mounted) {
        setState(() {
          _channel = channel;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.blueAccent),
              const SizedBox(height: 16),
              Text(
                'Loading Channel #${widget.channelId}...',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_channel != null) {
      final auth = context.watch<AuthProvider>();
      final isOwner = auth.isAuthenticated && auth.currentUser?.id == _channel!.ownerId;
      return ChannelDetailScreen(
        channel: _channel!,
        isReadOnly: !isOwner,
      );
    }

    // Access Denied / Error state
    return Scaffold(
      appBar: AppBar(
        title: Text('Channel #${widget.channelId}'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text(
                'Access Denied or Channel Not Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage != null && !_errorMessage!.contains('403')
                    ? 'Error loading channel: $_errorMessage'
                    : 'Channel #${widget.channelId} is marked as private or does not exist.\nIf you are the owner, please sign in to access it.',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    onPressed: _loadPublicChannel,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
