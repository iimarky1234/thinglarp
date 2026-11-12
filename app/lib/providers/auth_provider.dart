import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService apiService;
  User? currentUser;
  bool isLoading = false;
  String? errorMessage;

  AuthProvider({required this.apiService});

  bool get isAuthenticated => apiService.accessToken != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('access_token');
    if (savedToken != null) {
      apiService.accessToken = savedToken;
      try {
        currentUser = await apiService.getCurrentUser();
      } catch (e) {
        // Token expired or invalid
        await logout();
      }
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final tokens = await apiService.login(username, password);
      currentUser = await apiService.getCurrentUser();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', tokens.accessToken);
      await prefs.setString('refresh_token', tokens.refreshToken);

      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await apiService.register(username, password);
      // Automatically log in on successful registration
      return await login(username, password);
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    apiService.accessToken = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }
}
