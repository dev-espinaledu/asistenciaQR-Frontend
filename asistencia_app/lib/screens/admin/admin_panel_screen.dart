import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/secure_storage.dart';
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
  int _pendientesHoy = 0;
  bool _isLoading = true;
  String _rol = '';

  @override
  void initState() {
    super.initState();
    _cargarRol();
    _fetchResumen();
  }

  Future<void> _cargarRol() async {
    final rol = await SecureStorage.getRol();
    setState(() => _rol = rol ?? '');
  }

  Future<void> _fetchResumen() async {
    try {
      final response = await ApiService.get("/asistencia/resumen");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalUsuarios = data['totalUsuarios'] as int;
          _asistenciasHoy = data['asistenciasHoy'] as int;
          _sinSalidaHoy = data['sinSalidaHoy'] as int;
          _pendientesHoy = data['pendientesHoy'] as int;
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cerrar sesión"),
        content: const Text("¿Estás seguro de que deseas cerrar sesión?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Cerrar sesión"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
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

  Widget _statRow(String titulo, String valor, IconData icono, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icono, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
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
                padding: const EdgeInsets.all(12),
                children: [
                  const Text(
                    "Resumen del día",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _statRow("Empleados", "$_totalUsuarios", Icons.people, Colors.indigo)),
                              const SizedBox(width: 12),
                              Expanded(child: _statRow("Asistencias", "$_asistenciasHoy", Icons.check_circle, Colors.green)),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(child: _statRow("Pendientes", "$_pendientesHoy", Icons.hourglass_empty, Colors.orange)),
                              const SizedBox(width: 12),
                              Expanded(child: _statRow("Sin salida", "$_sinSalidaHoy", Icons.warning, Colors.red)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Acciones",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "QR de Asistencia",
                    subtitulo: _rol == 'ADMIN'
                        ? "Genera un código QR válido"
                        : "Visualiza el código QR activo",
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
                    onTap: () => Navigator.pushNamed(context, "/admin/historial"),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "Gestionar Horarios",
                    subtitulo: "Edita horarios por usuario y día",
                    icono: Icons.calendar_month,
                    color: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, "/admin/horarios"),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "Gestionar Usuarios",
                    subtitulo: _rol == 'ADMIN'
                        ? "Crear, editar y eliminar usuarios"
                        : "Crear y editar usuarios",
                    icono: Icons.people,
                    color: Colors.purple,
                    onTap: () => Navigator.pushNamed(context, "/admin/usuarios"),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "Estadísticas",
                    subtitulo: "Consulta estadísticas por usuario y período",
                    icono: Icons.insights,
                    color: Colors.deepPurple,
                    onTap: () => Navigator.pushNamed(context, "/admin/estadisticas"),
                  ),
                  const SizedBox(height: 12),
                  _menuButton(
                    titulo: "Reportes",
                    subtitulo: "Filtra asistencias por usuario, fecha y estado",
                    icono: Icons.bar_chart,
                    color: Colors.teal,
                    onTap: () => Navigator.pushNamed(context, "/admin/reportes"),
                  ),
                  // Solo ADMIN - sin SizedBox extra para SUB_ADMIN
                  if (_rol == 'ADMIN') ...[
                    const SizedBox(height: 12),
                    _menuButton(
                      titulo: "Registro Manual",
                      subtitulo: "Registra asistencia manualmente por usuario y fecha",
                      icono: Icons.edit_calendar,
                      color: Colors.blueAccent,
                      onTap: () => Navigator.pushNamed(context, "/admin/registro-manual"),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
