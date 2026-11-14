import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = true;
  bool _togglingReg = false;
  bool _registrationEnabled = true;
  List<AdminUser> _users = [];
  AdminStats? _stats;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<AuthProvider>().apiService;
      final results = await Future.wait([
        api.getAdminUsers(),
        api.getAdminStats(),
        api.getRegistrationStatus(),
      ]);

      if (!mounted) return;
      setState(() {
        _users = results[0] as List<AdminUser>;
        _stats = results[1] as AdminStats;
        _registrationEnabled = results[2] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: context.appColors.danger,
        ),
      );
    }
  }

  Future<void> _toggleRegistration(bool enable) async {
    setState(() => _togglingReg = true);
    try {
      final api = context.read<AuthProvider>().apiService;
      final updated = await api.setRegistrationStatus(enable);
      if (!mounted) return;
      setState(() {
        _registrationEnabled = updated;
        _togglingReg = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? 'Public sign-ups OPENED. Anyone can register.'
                : 'Public sign-ups LOCKED. Only admins can create accounts.',
          ),
          backgroundColor:
              updated ? context.appColors.success : context.appColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _togglingReg = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change registration mode: $e'),
          backgroundColor: context.appColors.danger,
        ),
      );
    }
  }

  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isAdmin = false;

    showResponsiveModal(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => ResponsiveModalScaffold(
          title: 'Create User Account',
          icon: Icons.person_add_outlined,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                try {
                  final api = context.read<AuthProvider>().apiService;
                  await api.createAdminUser(
                    usernameCtrl.text.trim(),
                    passwordCtrl.text,
                    isAdmin: isAdmin,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('User created successfully!'),
                      backgroundColor: context.appColors.success,
                    ),
                  );
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create: $e'),
                      backgroundColor: context.appColors.danger,
                    ),
                  );
                }
              },
              child: const Text('Create User'),
            ),
          ],
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'At least 3 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Initial Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'At least 6 characters' : null,
                ),
                const SizedBox(height: 12),
                Material(
                  color: ctx.appColors.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: ctx.appColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    title: const Text(
                      'Administrator Privileges',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Full access to user and system settings',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: isAdmin,
                    activeThumbColor: ctx.appColors.warning,
                    onChanged: (v) => setStateDlg(() => isAdmin = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetPasswordDialog(AdminUser user) {
    final formKey = GlobalKey<FormState>();
    final pwdCtrl = TextEditingController();

    showResponsiveModal(
      context: context,
      builder: (ctx) => ResponsiveModalScaffold(
        title: 'Reset Password • ${user.username}',
        icon: Icons.lock_reset_rounded,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                final api = context.read<AuthProvider>().apiService;
                await api.updateAdminUser(user.id, password: pwdCtrl.text);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Password updated successfully!'),
                    backgroundColor: context.appColors.success,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: $e'),
                    backgroundColor: context.appColors.danger,
                  ),
                );
              }
            },
            child: const Text('Update Password'),
          ),
        ],
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: pwdCtrl,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(AdminUser user) async {
    try {
      final api = context.read<AuthProvider>().apiService;
      await api.updateAdminUser(user.id, isActive: !user.isActive);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: context.appColors.danger,
        ),
      );
    }
  }

  Future<void> _toggleAdmin(AdminUser user) async {
    try {
      final api = context.read<AuthProvider>().apiService;
      await api.updateAdminUser(user.id, isAdmin: !user.isAdmin);
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: context.appColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final colors = context.appColors;
    final confirmed = await showResponsiveModal<bool>(
      context: context,
      builder: (ctx) => ResponsiveModalScaffold(
        title: 'Delete User',
        icon: Icons.warning_amber_rounded,
        iconColor: colors.danger,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete User'),
          ),
        ],
        child: Text(
          'Permanently delete user "${user.username}" along with their channels and devices?',
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final api = context.read<AuthProvider>().apiService;
        await api.deleteAdminUser(user.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User deleted.'),
            backgroundColor: context.appColors.warning,
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: context.appColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final colors = context.appColors;

    final filteredUsers = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      return u.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control Center'),
        actions: [
          const AppThemeToggleButton(),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Refresh Data',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New User'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        context.isCompactPhone ? 12 : 20,
                        16,
                        context.isCompactPhone ? 12 : 20,
                        96,
                      ),
                      child: ResponsiveCenter(
                      maxWidth: 1120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRegistrationControlCard(colors),
                          const SizedBox(height: 18),
                          if (_stats != null) ...[
                            _buildStatsGrid(colors, constraints.maxWidth),
                            const SizedBox(height: 22),
                          ],
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search users by username...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) =>
                                setState(() => _searchQuery = val.trim()),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Text(
                                'Accounts (${filteredUsers.length})',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (filteredUsers.isEmpty)
                            AppSurfaceCard(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'No users found matching query',
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ),
                            )
                          else
                            ...filteredUsers.map((u) {
                              final isSelf = currentUser?.id == u.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildUserCard(u, isSelf, colors),
                              );
                            }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
    );
  }

  Widget _buildRegistrationControlCard(AppColors colors) {
    final isLocked = !_registrationEnabled;
    final stateColor = isLocked ? colors.danger : colors.success;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: stateColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stateColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isLocked ? Icons.lock_person_rounded : Icons.public_rounded,
              color: stateColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Public Sign-Ups',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: colors.textPrimary,
                      ),
                    ),
                    AppStatusPill(
                      label: isLocked ? 'LOCKED' : 'OPEN',
                      color: stateColor,
                      showDot: !isLocked,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  isLocked
                      ? 'Registration is disabled. Only administrators can add new accounts.'
                      : 'Public sign-ups are enabled on the sign-in page.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _togglingReg
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch.adaptive(
                  value: _registrationEnabled,
                  activeThumbColor: colors.success,
                  onChanged: _toggleRegistration,
                ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AppColors colors, double maxWidth) {
    final effectiveWidth = (maxWidth - 40).clamp(280.0, 1120.0);
    final int cols = effectiveWidth >= 780 ? 4 : 2;
    const double spacing = 12;
    final cardWidth = (effectiveWidth - spacing * (cols - 1)) / cols;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        _buildStatCard(
          colors,
          'Total Users',
          _stats!.totalUsers.toString(),
          Icons.people_outline_rounded,
          colors.primary,
          cardWidth,
        ),
        _buildStatCard(
          colors,
          'Active Users',
          _stats!.activeUsers.toString(),
          Icons.check_circle_outline_rounded,
          colors.success,
          cardWidth,
        ),
        _buildStatCard(
          colors,
          'Channels',
          _stats!.totalChannels.toString(),
          Icons.sensors_rounded,
          colors.accentCyan,
          cardWidth,
        ),
        _buildStatCard(
          colors,
          'Devices',
          _stats!.totalDevices.toString(),
          Icons.memory_rounded,
          colors.warning,
          cardWidth,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    AppColors colors,
    String label,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(AdminUser user, bool isSelf, AppColors colors) {
    final dateStr = DateFormat('MMM d, yyyy').format(user.createdAt.toLocal());
    final avatarColor = user.isAdmin ? colors.warning : colors.primary;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      borderColor:
          user.isAdmin ? colors.warning.withValues(alpha: 0.45) : colors.border,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarColor.withValues(alpha: 0.14),
            foregroundColor: avatarColor,
            child: Icon(
              user.isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_outline_rounded,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      user.username,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isSelf)
                      AppStatusPill(label: 'YOU', color: colors.primary),
                    if (user.isAdmin)
                      AppStatusPill(label: 'ADMIN', color: colors.warning),
                    AppStatusPill(
                      label: user.isActive ? 'ACTIVE' : 'DISABLED',
                      color: user.isActive ? colors.success : colors.danger,
                      showDot: user.isActive,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${user.channelCount} channels • ${user.deviceCount} devices • Joined $dateStr',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
            onSelected: (val) {
              if (val == 'pwd') _showResetPasswordDialog(user);
              if (val == 'active') _toggleActive(user);
              if (val == 'admin') _toggleAdmin(user);
              if (val == 'delete') _confirmDelete(user);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'pwd',
                child: Row(
                  children: [
                    Icon(Icons.lock_reset_rounded, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reset Password',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSelf)
                PopupMenuItem(
                  value: 'active',
                  child: Row(
                    children: [
                      Icon(
                        user.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user.isActive ? 'Deactivate Account' : 'Reactivate Account',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isSelf)
                PopupMenuItem(
                  value: 'admin',
                  child: Row(
                    children: [
                      Icon(
                        user.isAdmin
                            ? Icons.person_outline_rounded
                            : Icons.admin_panel_settings_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user.isAdmin ? 'Remove Admin' : 'Make Admin',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isSelf)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: colors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Delete User',
                          style: TextStyle(color: colors.danger),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
