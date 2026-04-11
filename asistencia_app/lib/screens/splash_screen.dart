import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/secure_storage.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

    Future<void> _checkAuth() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (loggedIn) {
      final rol = await SecureStorage.getRol();
      if (!mounted) return;

      if (rol == "ADMIN" || rol == "SUB_ADMIN") {
        Navigator.pushReplacementNamed(context, "/admin");
      } else if (rol == "PORTERO") {
        Navigator.pushReplacementNamed(context, "/portero");
      } else if (rol == "DOCENTE" || rol == "ADMINISTRATIVO" || rol == "SERVICIOS_GENERALES" || rol == "PRACTICANTE") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        await AuthService.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}