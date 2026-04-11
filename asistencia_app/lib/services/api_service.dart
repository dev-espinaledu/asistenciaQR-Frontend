import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'secure_storage.dart';
import 'auth_service.dart';

class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<Map<String, String>> _headers() async {
    final token = await SecureStorage.getToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Future<http.Response> get(String path) async {
    final response = await http.get(
      Uri.parse("${AppConfig.baseUrl}$path"),
      headers: await _headers(),
    );
    _verificarToken(response);
    return response;
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse("${AppConfig.baseUrl}$path"),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _verificarToken(response);
    return response;
  }

  static Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse("${AppConfig.baseUrl}$path"),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _verificarToken(response);
    return response;
  }

  static Future<http.Response> patch(String path) async {
    final response = await http.patch(
      Uri.parse("${AppConfig.baseUrl}$path"),
      headers: await _headers(),
    );
    _verificarToken(response);
    return response;
  }

  static Future<http.Response> delete(String path) async {
    final response = await http.delete(
      Uri.parse("${AppConfig.baseUrl}$path"),
      headers: await _headers(),
    );
    _verificarToken(response);
    return response;
  }

  static Future<String?> getRol() async {
  return await SecureStorage.getRol();
}

  // Si el servidor devuelve 401, cerrar sesión y redirigir al login
  static void _verificarToken(http.Response response) {
    if (response.statusCode == 401) {
      _cerrarSesionYRedirigir();
    }
  }

  static Future<void> _cerrarSesionYRedirigir() async {
    await AuthService.logout();
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }
}