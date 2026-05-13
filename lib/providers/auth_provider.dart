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
    
    if (_token != null) {
      try {
        final res = await _apiService.get('/auth/me');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          _user = data['data']['user'];
        } else {
          await logout();
        }
      } catch (e) {
        await logout();
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
    notifyListeners();
  }
}
