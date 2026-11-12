import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/channel.dart';
import '../models/telemetry.dart';
import '../models/user.dart';

class ApiService {
  final AppConfig config = AppConfig();
  String? accessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  // Auth
  Future<User> register(String username, String password) async {
    final res = await http.post(
      Uri.parse('${config.apiUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 201) {
      return User.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body)['detail'] ?? 'Registration failed';
    throw Exception(err);
  }

  Future<AuthTokens> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('${config.apiUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) {
      final tokens = AuthTokens.fromJson(jsonDecode(res.body));
      accessToken = tokens.accessToken;
      return tokens;
    }
    final err = jsonDecode(res.body)['detail'] ?? 'Login failed';
    throw Exception(err);
  }

  Future<User> getCurrentUser() async {
    final res = await http.get(
      Uri.parse('${config.apiUrl}/auth/me'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return User.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to get user profile');
  }

  // MQTT Session Credentials
  Future<Map<String, dynamic>> requestMqttSession() async {
    final res = await http.post(
      Uri.parse('${config.apiUrl}/mqtt/session'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to request MQTT session: ${res.body}');
  }

  // Channels
  Future<List<Channel>> getChannels() async {
    final res = await http.get(
      Uri.parse('${config.apiUrl}/channels'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => Channel.fromJson(item)).toList();
    }
    throw Exception('Failed to load channels');
  }

  Future<Channel> createChannel(String name, String? description, bool isPublic) async {
    final res = await http.post(
      Uri.parse('${config.apiUrl}/channels'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'description': description,
        'is_public': isPublic,
      }),
    );
    if (res.statusCode == 201) {
      return Channel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create channel');
  }

  Future<void> deleteChannel(int channelId) async {
    final res = await http.delete(
      Uri.parse('${config.apiUrl}/channels/$channelId'),
      headers: _headers,
    );
    if (res.statusCode != 204) {
      throw Exception('Failed to delete channel');
    }
  }

  // Fields
  Future<List<ChannelField>> getFields(int channelId) async {
    final res = await http.get(
      Uri.parse('${config.apiUrl}/channels/$channelId/fields'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => ChannelField.fromJson(item)).toList();
    }
    throw Exception('Failed to load fields');
  }

  Future<ChannelField> updateField(int channelId, int fieldId, String? label, String? unit) async {
    final res = await http.patch(
      Uri.parse('${config.apiUrl}/channels/$channelId/fields/$fieldId'),
      headers: _headers,
      body: jsonEncode({'label': label, 'unit': unit}),
    );
    if (res.statusCode == 200) {
      return ChannelField.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update field');
  }

  // Devices
  Future<List<Device>> getDevices(int channelId) async {
    final res = await http.get(
      Uri.parse('${config.apiUrl}/channels/$channelId/devices'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => Device.fromJson(item)).toList();
    }
    throw Exception('Failed to load devices');
  }

  Future<Device> createDevice(int channelId, String name) async {
    final res = await http.post(
      Uri.parse('${config.apiUrl}/channels/$channelId/devices'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode == 201) {
      return Device.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create device');
  }

  Future<void> deleteDevice(int channelId, int deviceId) async {
    final res = await http.delete(
      Uri.parse('${config.apiUrl}/channels/$channelId/devices/$deviceId'),
      headers: _headers,
    );
    if (res.statusCode != 204) {
      throw Exception('Failed to delete device');
    }
  }

  // API Keys
  Future<List<ApiKeyItem>> getApiKeys(int channelId) async {
    final res = await http.get(
      Uri.parse('${config.apiUrl}/channels/$channelId/keys'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((item) => ApiKeyItem.fromJson(item)).toList();
    }
    throw Exception('Failed to load API keys');
  }

  Future<ApiKeyItem> createApiKey(int channelId, String scope) async {
    final res = await http.post(
      Uri.parse('${config.apiUrl}/channels/$channelId/keys'),
      headers: _headers,
      body: jsonEncode({'scope': scope}),
    );
    if (res.statusCode == 201) {
      return ApiKeyItem.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create API key');
  }

  Future<void> deleteApiKey(int channelId, int keyId) async {
    final res = await http.delete(
      Uri.parse('${config.apiUrl}/channels/$channelId/keys/$keyId'),
      headers: _headers,
    );
    if (res.statusCode != 204) {
      throw Exception('Failed to delete API key');
    }
  }

  // Telemetry Queries
  Future<ChannelDataResponse> getTelemetry(
    int channelId, {
    String resolution = 'auto',
    String? fields,
    DateTime? start,
    DateTime? end,
  }) async {
    final queryParams = <String, String>{
      'resolution': resolution,
      if (start != null) 'start': start.toIso8601String(),
      if (end != null) 'end': end.toIso8601String(),
    };
    if (fields != null) {
      queryParams['fields'] = fields;
    }

    final uri = Uri.parse('${config.apiUrl}/channels/$channelId/data')
        .replace(queryParameters: queryParams);

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return ChannelDataResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to query telemetry');
  }

  Future<Map<String, dynamic>> getLatestTelemetry(int channelId) async {
    final res = await http.get(
      Uri.parse('${config.apiUrl}/channels/$channelId/latest'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get latest telemetry');
  }

  Future<Map<String, dynamic>> postTelemetry({
    required int channelId,
    required Map<String, dynamic> data,
    String? apiKey,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey.isNotEmpty)
        'X-API-Key': apiKey
      else if (accessToken != null)
        'Authorization': 'Bearer $accessToken',
    };
    final res = await http.post(
      Uri.parse('${config.apiUrl}/channels/$channelId/data'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200 || res.statusCode == 202) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body)['detail'] ?? 'Failed to post telemetry';
    throw Exception(err);
  }

  // ---------------------------------------------------------------------------
  // Admin Methods
  // ---------------------------------------------------------------------------
  Future<List<AdminUser>> getAdminUsers() async {
    final res = await http.get(
      Uri.parse('${config.apiUrl}/admin/users'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((x) => AdminUser.fromJson(x as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load users: ${res.body}');
  }

  Future<AdminStats> getAdminStats() async {
    final res = await http.get(
      Uri.parse('${config.apiUrl}/admin/stats'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return AdminStats.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load admin stats: ${res.body}');
  }

  Future<AdminUser> createAdminUser(String username, String password, {bool isAdmin = false}) async {
    final res = await http.post(
      Uri.parse('${config.apiUrl}/admin/users'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'is_admin': isAdmin,
      }),
    );
    if (res.statusCode == 201) {
      return AdminUser.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body)['detail'] ?? 'Failed to create user';
    throw Exception(err);
  }

  Future<AdminUser> updateAdminUser(int userId, {bool? isActive, bool? isAdmin, String? password}) async {
    final body = <String, dynamic>{};
    if (isActive != null) body['is_active'] = isActive;
    if (isAdmin != null) body['is_admin'] = isAdmin;
    if (password != null) body['password'] = password;

    final res = await http.patch(
      Uri.parse('${config.apiUrl}/admin/users/$userId'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return AdminUser.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body)['detail'] ?? 'Failed to update user';
    throw Exception(err);
  }

  Future<void> deleteAdminUser(int userId) async {
    final res = await http.delete(
      Uri.parse('${config.apiUrl}/admin/users/$userId'),
      headers: _headers,
    );
    if (res.statusCode != 204) {
      final err = jsonDecode(res.body)['detail'] ?? 'Failed to delete user';
      throw Exception(err);
    }
  }
}
