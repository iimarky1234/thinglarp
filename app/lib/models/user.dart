class User {
  final int id;
  final String username;
  final bool isAdmin;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    this.isAdmin = false,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AdminUser {
  final int id;
  final String username;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;
  final int channelCount;
  final int deviceCount;

  AdminUser({
    required this.id,
    required this.username,
    required this.isActive,
    required this.isAdmin,
    required this.createdAt,
    required this.channelCount,
    required this.deviceCount,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      username: json['username'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      channelCount: json['channel_count'] as int? ?? 0,
      deviceCount: json['device_count'] as int? ?? 0,
    );
  }
}

class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int totalChannels;
  final int totalDevices;
  final int totalPoints;

  AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalChannels,
    required this.totalDevices,
    required this.totalPoints,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['total_users'] as int? ?? 0,
      activeUsers: json['active_users'] as int? ?? 0,
      totalChannels: json['total_channels'] as int? ?? 0,
      totalDevices: json['total_devices'] as int? ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresInMinutes;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresInMinutes,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresInMinutes: json['expires_in_minutes'] as int? ?? 15,
    );
  }
}
