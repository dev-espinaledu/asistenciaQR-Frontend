import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/history_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/admin/admin_qr_screen.dart';
import 'screens/admin/admin_historial_screen.dart';
import 'screens/admin/admin_horarios_screen.dart';
import 'screens/admin/admin_usuarios_screen.dart';
import 'screens/admin/admin_reportes_screen.dart';
import 'screens/profile_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ApiService.navigatorKey,
      title: 'AsistenciApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/perfil': (context) => const ProfileScreen(),
        '/scanner': (context) => const ScannerScreen(),
        '/historial': (context) => const HistoryScreen(),
        '/admin': (context) => const AdminPanelScreen(),
        '/admin/qr': (context) => const AdminQrScreen(),
        '/admin/historial': (context) => const AdminHistorialScreen(),
        '/admin/horarios': (context) => const AdminHorariosScreen(),
        '/admin/usuarios': (context) => const AdminUsuariosScreen(),
        '/admin/reportes': (context) => const AdminReportesScreen(),
      },
    );
  }
}