import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ApiService {
  static void Function()? onUnauthenticated;

  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401 && onUnauthenticated != null) {
      onUnauthenticated!();
    }
  }
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}$endpoint'), headers: headers);
    _checkUnauthorized(res);
    return res;
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
    _checkUnauthorized(res);
    return res;
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
    _checkUnauthorized(res);
    return res;
  }
}
