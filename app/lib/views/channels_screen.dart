import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/channel.dart';
import '../providers/auth_provider.dart';
import '../providers/channel_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'admin_users_screen.dart';
import 'api_tutorial_screen.dart';
import 'channel_detail_screen.dart';
import 'settings_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _visibilityFilter = 'all'; // 'all', 'public', 'private'

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<ChannelProvider>().loadChannels();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPublic = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 22),
                  SizedBox(width: 10),
                  Text('Create Channel'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Channel Name',
                          hintText: 'e.g., Greenhouse Sensors',
                          prefixIcon: Icon(Icons.sensors_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Channel name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Hardware notes or location',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: SwitchListTile(
                          title: const Text(
                            'Public Telemetry Access',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Anyone with the share URL can view read-only graphs',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                          value: isPublic,
                          activeThumbColor: colors.success,
                          onChanged: (v) => setStateDialog(() => isPublic = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    await context.read<ChannelProvider>().createChannel(
                          nameController.text.trim(),
                          descController.text.trim().isEmpty
                              ? null
                              : descController.text.trim(),
                          isPublic,
                        );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareChannel(BuildContext context, Channel ch) async {
    final colors = context.appColors;
    final url = '${AppConfig().webAppUrl}/#/channel/${ch.id}';
    if (ch.isPublic) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Public share link copied:\n$url'),
          action: SnackBarAction(
            label: 'OK',
            textColor: colors.accentCyan,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.public_rounded, color: colors.warning),
            const SizedBox(width: 10),
            const Text('Channel is Private'),
          ],
        ),
        content: Text(
          'Only you can view "${ch.name}" right now. Make it public so anyone with the link can view its live telemetry?',
          style: TextStyle(color: colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Private'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Make Public & Copy Link'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final updated = await context
          .read<ChannelProvider>()
          .updateChannel(ch.id, isPublic: true);
      if (updated != null && context.mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Channel is now public. Link copied:\n$url')),
          );
        }
      }
    }
  }

  List<Channel> _filterChannels(List<Channel> channels) {
    return channels.where((ch) {
      if (_visibilityFilter == 'public' && !ch.isPublic) return false;
      if (_visibilityFilter == 'private' && ch.isPublic) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return ch.name.toLowerCase().contains(q) ||
          (ch.description?.toLowerCase().contains(q) ?? false) ||
          '#${ch.id}'.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final channelProvider = context.watch<ChannelProvider>();
    final colors = context.appColors;
    final allChannels = channelProvider.channels;
    final filteredChannels = _filterChannels(allChannels);
    final publicCount = allChannels.where((c) => c.isPublic).length;
    final privateCount = allChannels.length - publicCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const AppBrandMark(size: 32),
            const SizedBox(width: 10),
            const Text('ThingLarp'),
          ],
        ),
        actions: [
          const AppThemeToggleButton(),
          const SizedBox(width: 6),
          if (auth.currentUser?.isAdmin == true) ...[
            Tooltip(
              message: 'Admin Control Center',
              child: IconButton(
                icon: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: colors.warning,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                ),
              ),
            ),
          ],
          Tooltip(
            message: 'API & Firmware Quickstart',
            child: IconButton(
              icon: Icon(Icons.menu_book_rounded, color: colors.accentCyan),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApiTutorialScreen()),
              ),
            ),
          ),
          Tooltip(
            message: 'Settings',
            child: IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
          Tooltip(
            message: 'Sign Out',
            child: IconButton(
              icon: Icon(Icons.logout_rounded, color: colors.textSecondary),
              onPressed: () => auth.logout(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => channelProvider.loadChannels(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final contentPadding = isWide
                ? const EdgeInsets.fromLTRB(28, 18, 28, 96)
                : const EdgeInsets.fromLTRB(16, 12, 16, 96);

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: contentPadding,
              child: ResponsiveCenter(
                maxWidth: 1180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWorkspaceHeader(
                      context,
                      username: auth.currentUser?.username ?? 'Workspace',
                      isAdmin: auth.currentUser?.isAdmin == true,
                      totalCount: allChannels.length,
                      publicCount: publicCount,
                      privateCount: privateCount,
                      isWide: isWide,
                    ),
                    const SizedBox(height: 18),
                    _buildFilterBar(colors, isWide),
                    const SizedBox(height: 18),
                    if (channelProvider.isLoading && allChannels.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (allChannels.isEmpty)
                      _buildEmptyState(
                        colors,
                        title: 'No channels yet',
                        subtitle:
                            'Create your first telemetry channel to provision IoT devices and stream sensor data.',
                        showCreateButton: true,
                      )
                    else if (filteredChannels.isEmpty)
                      _buildEmptyState(
                        colors,
                        title: 'No matching channels',
                        subtitle:
                            'Try clearing your search query or changing the visibility filter.',
                        showCreateButton: false,
                      )
                    else
                      _buildChannelsGrid(filteredChannels, constraints.maxWidth),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Channel'),
      ),
    );
  }

  Widget _buildWorkspaceHeader(
    BuildContext context, {
    required String username,
    required bool isAdmin,
    required int totalCount,
    required int publicCount,
    required int privateCount,
    required bool isWide,
  }) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(isWide ? 24 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.heroStart, colors.heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Telemetry Channels',
                    style: TextStyle(
                      fontSize: isWide ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 10),
                    AppStatusPill(
                      label: 'Admin',
                      color: colors.warning,
                      icon: Icons.verified_user_outlined,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Signed in as $username • Real-time MQTT notification + API telemetry',
                style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _HeaderStatChip(
                label: '$totalCount Total',
                icon: Icons.sensors_rounded,
                color: colors.primary,
              ),
              _HeaderStatChip(
                label: '$publicCount Public',
                icon: Icons.public_rounded,
                color: colors.success,
              ),
              _HeaderStatChip(
                label: '$privateCount Private',
                icon: Icons.lock_outline_rounded,
                color: colors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppColors colors, bool isWide) {
    final searchField = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
      decoration: InputDecoration(
        hintText: 'Search channels by name, description, or #ID...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        isDense: true,
      ),
    );

    final filterPills = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterPill(
            label: 'All',
            selected: _visibilityFilter == 'all',
            onTap: () => setState(() => _visibilityFilter = 'all'),
          ),
          _FilterPill(
            label: 'Public',
            selected: _visibilityFilter == 'public',
            onTap: () => setState(() => _visibilityFilter = 'public'),
          ),
          _FilterPill(
            label: 'Private',
            selected: _visibilityFilter == 'private',
            onTap: () => setState(() => _visibilityFilter = 'private'),
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 12),
          filterPills,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        searchField,
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: filterPills),
      ],
    );
  }

  Widget _buildEmptyState(
    AppColors colors, {
    required String title,
    required String subtitle,
    required bool showCreateButton,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sensors_off_rounded, size: 36, color: colors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
          ),
          if (showCreateButton) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Channel'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelsGrid(List<Channel> channels, double availableWidth) {
    const double spacing = 14;
    final cappedWidth = availableWidth > 1180 ? 1180.0 : availableWidth - 48;
    int columns = 1;
    if (availableWidth >= 1040) {
      columns = 3;
    } else if (availableWidth >= 680) {
      columns = 2;
    }
    final cardWidth = columns == 1
        ? double.infinity
        : (cappedWidth - spacing * (columns - 1)) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: channels.map((ch) {
        final widget = _ChannelCard(
          channel: ch,
          onOpen: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChannelDetailScreen(channel: ch),
              ),
            );
            if (mounted) {
              context.read<ChannelProvider>().loadChannels();
            }
          },
          onShare: () => _shareChannel(context, ch),
        );
        if (columns == 1) return widget;
        return SizedBox(width: cardWidth, child: widget);
      }).toList(),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  const _ChannelCard({
    required this.channel,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateStr = DateFormat('MMM d, yyyy').format(channel.createdAt.toLocal());

    return AppSurfaceCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CH #${channel.id}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppStatusPill(
                label: channel.isPublic ? 'Public' : 'Private',
                color: channel.isPublic ? colors.success : colors.textSecondary,
                showDot: channel.isPublic,
                icon: channel.isPublic ? null : Icons.lock_outline_rounded,
              ),
              const Spacer(),
              Tooltip(
                message: 'Copy Share Link',
                child: InkWell(
                  onTap: onShare,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      Icons.share_outlined,
                      size: 16,
                      color: colors.accentCyan,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: Text(
              (channel.description != null && channel.description!.isNotEmpty)
                  ? channel.description!
                  : 'Telemetry channel ready for device data streams.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: (channel.description != null &&
                        channel.description!.isNotEmpty)
                    ? colors.textSecondary
                    : colors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: colors.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                dateStr,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.tune_rounded,
                size: 13,
                color: colors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '${channel.maxFields} fields',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const Spacer(),
              Text(
                'Open',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: colors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _HeaderStatChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
