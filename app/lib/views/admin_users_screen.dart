import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = false;
  bool _registrationEnabled = true;
  bool _isUpdatingRegistration = false;
  List<AdminUser> _users = [];
  AdminStats? _stats;
  String _searchQuery = '';
  final _searchController = TextEditingController();

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
    final api = context.read<AuthProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final results = await Future.wait([
        api.getAdminUsers(),
        api.getAdminStats(),
        api.getRegistrationStatus(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<AdminUser>;
          _stats = results[1] as AdminStats;
          _registrationEnabled = results[2] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Error loading users: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _toggleRegistration(bool enable) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AuthProvider>().apiService;
    setState(() => _isUpdatingRegistration = true);

    try {
      final updated = await api.setRegistrationStatus(enable);
      if (mounted) {
        setState(() {
          _registrationEnabled = updated;
          _isUpdatingRegistration = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              updated
                  ? 'Public registration is now OPEN.'
                  : 'Public registration is now LOCKED. New users cannot self-register.',
            ),
            backgroundColor: updated ? Colors.teal : Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingRegistration = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update registration status: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<AdminUser> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) => u.username.toLowerCase().contains(q) || u.id.toString() == q).toList();
  }

  void _showCreateUserDialog() {
    final userController = TextEditingController();
    final passController = TextEditingController();
    bool makeAdmin = false;
    final formKey = GlobalKey<FormState>();
    final api = context.read<AuthProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New User'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: userController,
                  decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Min 3 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Grant Administrator Privileges'),
                  value: makeAdmin,
                  onChanged: (v) => setDialogState(() => makeAdmin = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await api.createAdminUser(userController.text.trim(), passController.text, isAdmin: makeAdmin);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('User created successfully!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to create: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(AdminUser user) {
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final api = context.read<AuthProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password for @${user.username}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await api.updateAdminUser(user.id, password: passController.text);
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(AdminUser user) async {
    final api = context.read<AuthProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.updateAdminUser(user.id, isActive: !user.isActive);
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleAdmin(AdminUser user) async {
    final api = context.read<AuthProvider>().apiService;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.updateAdminUser(user.id, isAdmin: !user.isAdmin);
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update role: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AuthProvider>().apiService;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete User @${user.username}?'),
        content: Text(
          'This will permanently delete the user account and all owned channels (${user.channelCount}) and devices (${user.deviceCount}). This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await api.deleteAdminUser(user.id);
        _loadData();
        messenger.showSnackBar(
          const SnackBar(content: Text('User deleted.'), backgroundColor: Colors.orange),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Administration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('New User'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    if (_stats != null) ...[
                      _buildStatsCards(isDark),
                      const SizedBox(height: 16),
                    ],

                    // Registration Lock / Access Control Card
                    _buildRegistrationLockCard(isDark),
                    const SizedBox(height: 20),

                    // Search & Title
                    Row(
                      children: [
                        Text(
                          'Registered Users (${_filteredUsers.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search username...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // User Cards List
                    if (_filteredUsers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: const Text('No users found matching query', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredUsers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final u = _filteredUsers[idx];
                          final isSelf = currentUser?.id == u.id;
                          return _buildUserCard(u, isSelf, isDark);
                        },
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRegistrationLockCard(bool isDark) {
    final isLocked = !_registrationEnabled;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLocked ? Colors.redAccent.withValues(alpha: 0.5) : Colors.green.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      color: isLocked
          ? (isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade50)
          : (isDark ? Colors.green.withValues(alpha: 0.08) : Colors.green.shade50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.redAccent.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLocked ? Icons.lock_outline : Icons.lock_open_outlined,
                color: isLocked ? Colors.redAccent : Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Public Registration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLocked ? Colors.redAccent : Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isLocked ? 'LOCKED' : 'OPEN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLocked
                        ? 'New users cannot self-register from login screen. Only admins can create accounts.'
                        : 'Anyone with server access can create a new account from the login screen.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _isUpdatingRegistration
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch.adaptive(
                    value: _registrationEnabled,
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.green.withValues(alpha: 0.5),
                    inactiveThumbColor: Colors.redAccent,
                    inactiveTrackColor: Colors.redAccent.withValues(alpha: 0.3),
                    onChanged: (val) => _toggleRegistration(val),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 36) / 4;
        return Row(
          children: [
            _buildStatCard('Total Users', _stats!.totalUsers.toString(), Icons.people, Colors.blueAccent, isDark, cardWidth),
            const SizedBox(width: 12),
            _buildStatCard('Active Users', _stats!.activeUsers.toString(), Icons.check_circle, Colors.green, isDark, cardWidth),
            const SizedBox(width: 12),
            _buildStatCard('Channels', _stats!.totalChannels.toString(), Icons.sensors, Colors.purpleAccent, isDark, cardWidth),
            const SizedBox(width: 12),
            _buildStatCard('Devices', _stats!.totalDevices.toString(), Icons.memory, Colors.amberAccent, isDark, cardWidth),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildUserCard(AdminUser user, bool isSelf, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isAdmin
              ? Colors.amber.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          width: user.isAdmin ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            backgroundColor: user.isAdmin ? Colors.amber.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
            foregroundColor: user.isAdmin ? Colors.amber : Colors.blueAccent,
            child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U'),
          ),
          const SizedBox(width: 14),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('YOU', style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const SizedBox(width: 8),
                    if (user.isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 0.8),
                        ),
                        child: const Text('ADMIN', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: user.isActive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.isActive ? 'ACTIVE' : 'DEACTIVATED',
                        style: TextStyle(
                          fontSize: 10,
                          color: user.isActive ? Colors.green : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'ID: ${user.id} • Channels: ${user.channelCount} • Devices: ${user.deviceCount} • Joined: ${dateFormat.format(user.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Actions Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              if (action == 'toggle_active') _toggleActive(user);
              if (action == 'toggle_admin') _toggleAdmin(user);
              if (action == 'reset_password') _showResetPasswordDialog(user);
              if (action == 'delete') _confirmDelete(user);
            },
            itemBuilder: (ctx) => [
              if (!isSelf)
                PopupMenuItem(
                  value: 'toggle_active',
                  child: Row(
                    children: [
                      Icon(user.isActive ? Icons.block : Icons.check_circle_outline, size: 18),
                      const SizedBox(width: 8),
                      Text(user.isActive ? 'Deactivate User' : 'Activate User'),
                    ],
                  ),
                ),
              if (!isSelf)
                PopupMenuItem(
                  value: 'toggle_admin',
                  child: Row(
                    children: [
                      Icon(user.isAdmin ? Icons.person : Icons.security, size: 18),
                      const SizedBox(width: 8),
                      Text(user.isAdmin ? 'Revoke Admin' : 'Make Administrator'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'reset_password',
                child: Row(
                  children: const [
                    Icon(Icons.lock_reset, size: 18),
                    SizedBox(width: 8),
                    Text('Reset Password'),
                  ],
                ),
              ),
              if (!isSelf)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: const [
                      Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Delete User', style: TextStyle(color: Colors.redAccent)),
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
