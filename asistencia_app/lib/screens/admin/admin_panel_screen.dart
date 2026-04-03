import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _totalUsuarios = 0;
  int _asistenciasHoy = 0;
  int _sinSalidaHoy = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchResumen();
  }

  Future<void> _fetchResumen() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get("/asistencia/resumen");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalUsuarios = data['totalUsuarios'] as int;
          _asistenciasHoy = data['asistenciasHoy'] as int;
          _sinSalidaHoy = data['sinSalidaHoy'] as int;
        });
      } else {
        _showError("Error al cargar resumen");
      }
    } catch (e) {
      _showError("Error de conexión");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _statCard({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icono, color: color),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Panel Administrativo"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchResumen),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchResumen,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    "Resumen del día",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard(
                        titulo: "Usuarios",
                        valor: "$_totalUsuarios",
                        icono: Icons.people,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        titulo: "Asistencias hoy",
                        valor: "$_asistenciasHoy",
                        icono: Icons.check_circle,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        titulo: "Sin salida",
                        valor: "$_sinSalidaHoy",
                        icono: Icons.warning,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Acciones",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "Generar QR de Asistencia",
                    subtitulo: "Genera un código QR válido por 30 minutos",
                    icono: Icons.qr_code_2,
                    color: Colors.indigo,
                    onTap: () => Navigator.pushNamed(context, "/admin/qr"),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "Historial General",
                    subtitulo: "Consulta y corrige registros de asistencia",
                    icono: Icons.history,
                    color: Colors.green,
                    onTap: () =>
                        Navigator.pushNamed(context, "/admin/historial"),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "Gestionar Horarios",
                    subtitulo: "Edita horarios por usuario y día",
                    icono: Icons.calendar_month,
                    color: Colors.orange,
                    onTap: () =>
                        Navigator.pushNamed(context, "/admin/horarios"),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "Gestionar Usuarios",
                    subtitulo: "Crear, editar y eliminar usuarios",
                    icono: Icons.people,
                    color: Colors.purple,
                    onTap: () =>
                        Navigator.pushNamed(context, "/admin/usuarios"),
                  ),
                  _menuButton(
                    titulo: "Reportes",
                    subtitulo: "Filtra asistencias por usuario, fecha y estado",
                    icono: Icons.bar_chart,
                    color: Colors.teal,
                    onTap: () => Navigator.pushNamed(context, "/admin/reportes"),
                  ),
                ],
              ),
            ),
    );
  }
}