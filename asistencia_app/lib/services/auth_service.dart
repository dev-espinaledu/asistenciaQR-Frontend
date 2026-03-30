import 'dart:convert';
import 'secure_storage.dart';

class AuthService {

  static Future<bool> isLoggedIn() async {
    final token = await SecureStorage.getToken();
    if (token == null) return false;

    if (_isTokenExpired(token)) {
      await logout();
      return false;
    }

    return true;
  }

  static Future<void> logout() async {
    await SecureStorage.deleteToken();
    await SecureStorage.deleteRol();
  }

  static bool _isTokenExpired(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return true;

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );

    final data = jsonDecode(payload);
    final exp = data['exp'];

    if (exp == null) return true;

    final expiryDate =
        DateTime.fromMillisecondsSinceEpoch(exp * 1000);

    return DateTime.now().isAfter(expiryDate);
  }
}