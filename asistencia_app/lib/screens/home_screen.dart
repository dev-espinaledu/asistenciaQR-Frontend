import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _rol;
  String _nombreCompleto = '';
  String _correo = '';
  Map<String, dynamic>? _asistenciaHoy;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    await Future.wait([_cargarRol(), _cargarPerfil(), _cargarAsistenciaHoy()]);
    setState(() => _isLoading = false);
  }

  Future<void> _cargarRol() async {
    final rol = await SecureStorage.getRol();
    setState(() => _rol = rol);
  }

  Future<void> _cargarPerfil() async {
    try {
      final response = await ApiService.get("/usuarios/perfil");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nombreCompleto = "${data['nombres']} ${data['apellidos']}";
          _correo = data['correo'];
        });
      }
    } catch (e) {
      // silencioso
    }
  }

  Future<void> _cargarAsistenciaHoy() async {
    try {
      final response = await ApiService.get("/asistencia/historial");
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final now = DateTime.now().toLocal();
        final hoy =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final registroHoy = data.where((r) {
          return r['fecha'].toString().substring(0, 10) == hoy;
        }).toList();
        setState(() {
          _asistenciaHoy = registroHoy.isNotEmpty ? registroHoy.first : null;
        });
      }
    } catch (e) {
      // silencioso
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'PUNTUAL': return Colors.green;
      case 'TARDE': return Colors.orange;
      case 'SIN_SALIDA': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'PUNTUAL': return Icons.check_circle;
      case 'TARDE': return Icons.schedule;
      case 'SIN_SALIDA': return Icons.warning;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Inicio"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Bienvenida ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.indigo, Color(0xFF5C6BC0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Text(
                            _nombreCompleto.isNotEmpty
                                ? _nombreCompleto[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Bienvenido,",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                _nombreCompleto,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _correo,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Resumen de hoy
                  const Text(
                    "Hoy",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  _asistenciaHoy == null
                      ? Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: const Padding(
                            padding: EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey),
                                SizedBox(width: 12),
                                Text(
                                  "Aún no has registrado asistencia hoy",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Asistencia registrada",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _colorEstado(
                                                _asistenciaHoy!['estado'])
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _iconoEstado(
                                                _asistenciaHoy!['estado']),
                                            size: 14,
                                            color: _colorEstado(
                                                _asistenciaHoy!['estado']),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _asistenciaHoy!['estado'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _colorEstado(
                                                  _asistenciaHoy!['estado']),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _infoTile(
                                        Icons.login,
                                        "Entrada",
                                        _asistenciaHoy!['hora_entrada']
                                                ?.toString()
                                                .substring(0, 8) ??
                                            '--',
                                        Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _infoTile(
                                        Icons.logout,
                                        "Salida",
                                        _asistenciaHoy!['hora_salida']
                                                ?.toString()
                                                .substring(0, 8) ??
                                            '--',
                                        Colors.indigo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                  const SizedBox(height: 24),

                  // Acciones
                  const Text(
                    "Acciones",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  if (_rol != 'ADMIN') ...[
                    _accionCard(
                      icono: Icons.qr_code_scanner,
                      titulo: "Escanear QR",
                      subtitulo: "Registra tu entrada o salida",
                      color: Colors.indigo,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScannerScreen()),
                        );
                        _cargarAsistenciaHoy();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  _accionCard(
                    icono: Icons.history,
                    titulo: "Ver Historial",
                    subtitulo: "Consulta tus registros de asistencia",
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _accionCard(
                    icono: Icons.person_outline,
                    titulo: "Mi perfil",
                    subtitulo: "Cambia tu contraseña",
                    color: Colors.indigo,
                    onTap: () => Navigator.pushNamed(context, '/perfil'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoTile(
      IconData icono, String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: color,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _accionCard({
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icono, color: color),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}