import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _user;
  String? _token;
  bool _isLoading = true;

  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    final savedUser = prefs.getString('user_data');
    
    if (savedUser != null) {
      _user = jsonDecode(savedUser);
    }
    
    if (_token != null) {
      try {
        final res = await _apiService.get('/auth/me');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          _user = data['data']['user'];
          // Update cached user data
          await prefs.setString('user_data', jsonEncode(_user));
        } else if (res.statusCode == 401) {
          // Only logout if explicitly unauthorized
          await logout();
        }
      } catch (e) {
        // On network error, keep existing token and user data for offline access
        debugPrint('Network error during auto-login: $e');
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final res = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['data']['token'];
        _user = data['data']['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setString('user_data', jsonEncode(_user));
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
    notifyListeners();
  }
}
