import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'channel_detail_screen.dart';
import 'login_screen.dart';

class PublicChannelViewerScreen extends StatefulWidget {
  final int channelId;

  const PublicChannelViewerScreen({super.key, required this.channelId});

  @override
  State<PublicChannelViewerScreen> createState() =>
      _PublicChannelViewerScreenState();
}

class _PublicChannelViewerScreenState extends State<PublicChannelViewerScreen> {
  bool _isLoading = true;
  String? _error;
  Channel? _channel;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPublicChannel);
  }

  Future<void> _loadPublicChannel() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prov = context.read<ChannelProvider>();
      final auth = context.read<AuthProvider>();
      final ch = await prov.apiService.getChannel(widget.channelId);
      final isOwner = auth.currentUser != null && auth.currentUser!.id == ch.ownerId;
      await prov.selectChannel(ch, isReadOnly: !isOwner);

      if (!mounted) return;
      setState(() {
        _channel = ch;
        _isOwner = isOwner;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Channel...'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: AppThemeToggleButton(),
            ),
          ],
        ),
        body: Center(
          child: AppSurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppBrandMark(size: 46),
                const SizedBox(height: 18),
                CircularProgressIndicator(color: colors.primary),
                const SizedBox(height: 16),
                Text(
                  'Connecting to shared channel #${widget.channelId}...',
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null || _channel == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Channel Unavailable'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: AppThemeToggleButton(),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AppSurfaceCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 40,
                        color: colors.warning,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Access Denied or Unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ??
                          'This channel may be private, deleted, or requires signing in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _loadPublicChannel,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Sign In'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ChannelDetailScreen(
      channel: _channel!,
      isReadOnly: !_isOwner,
    );
  }
}
