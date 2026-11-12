class Channel {
  final int id;
  final int ownerId;
  final String name;
  final String? description;
  final bool isPublic;
  final int maxFields;
  final DateTime createdAt;

  Channel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.isPublic,
    required this.maxFields,
    required this.createdAt,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as int,
      ownerId: json['owner_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      maxFields: json['max_fields'] as int? ?? 500,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ChannelField {
  final int id;
  final int channelId;
  final String key;
  final String? label;
  final String? unit;
  final String valueType;
  final DateTime firstSeenAt;

  ChannelField({
    required this.id,
    required this.channelId,
    required this.key,
    this.label,
    this.unit,
    required this.valueType,
    required this.firstSeenAt,
  });

  factory ChannelField.fromJson(Map<String, dynamic> json) {
    return ChannelField(
      id: json['id'] as int,
      channelId: json['channel_id'] as int,
      key: json['key'] as String,
      label: json['label'] as String?,
      unit: json['unit'] as String?,
      valueType: json['value_type'] as String? ?? 'number',
      firstSeenAt: DateTime.parse(json['first_seen_at'] as String),
    );
  }

  String get displayName => label ?? key;
}

class Device {
  final int id;
  final int channelId;
  final String name;
  final String mqttUsername;
  final String? mqttPassword;
  final bool isActive;
  final DateTime createdAt;

  Device({
    required this.id,
    required this.channelId,
    required this.name,
    required this.mqttUsername,
    this.mqttPassword,
    required this.isActive,
    required this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      channelId: json['channel_id'] as int,
      name: json['name'] as String,
      mqttUsername: json['mqtt_username'] as String,
      mqttPassword: json['mqtt_password'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ApiKeyItem {
  final int id;
  final int channelId;
  final String prefix;
  final String? apiKey; // Only present when newly created
  final String scope;
  final DateTime createdAt;

  ApiKeyItem({
    required this.id,
    required this.channelId,
    required this.prefix,
    this.apiKey,
    required this.scope,
    required this.createdAt,
  });

  factory ApiKeyItem.fromJson(Map<String, dynamic> json) {
    return ApiKeyItem(
      id: json['id'] as int,
      channelId: json['channel_id'] as int,
      prefix: json['prefix'] as String,
      apiKey: json['api_key'] as String?,
      scope: json['scope'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
