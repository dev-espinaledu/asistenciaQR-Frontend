import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/secure_storage.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _todos = [];
  List<dynamic> _filtrados = [];
  bool _isLoading = true;
  DateTime? _fechaFiltro;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final token = await SecureStorage.getToken();
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/asistencia/historial"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 401) {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _todos = data;
          _filtrados = data;
        });
      }
    } catch (e) {
      _showError("Error al cargar historial");
    }
    setState(() => _isLoading = false);
  }

  void _filtrarPorFecha(DateTime? fecha) {
    setState(() {
      _fechaFiltro = fecha;
      if (fecha == null) {
        _filtrados = _todos;
      } else {
        final fechaStr =
            "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
        _filtrados = _todos.where((r) {
          return r['fecha'].toString().substring(0, 10) == fechaStr;
        }).toList();
      }
    });
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    _filtrarPorFecha(picked);
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

  String _formatFechaLegible(String fecha) {
    final date = DateTime.tryParse(fecha.substring(0, 10));
    if (date == null) return fecha;
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    const dias = [
      '', 'Lunes', 'Martes', 'Miércoles',
      'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    return "${dias[date.weekday]}, ${date.day} de ${meses[date.month]} ${date.year}";
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Historial de Asistencias"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Botón filtro por fecha
          IconButton(
            icon: Icon(
              _fechaFiltro != null ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: _seleccionarFecha,
            tooltip: "Filtrar por fecha",
          ),
          // Limpiar filtro
          if (_fechaFiltro != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _filtrarPorFecha(null),
              tooltip: "Quitar filtro",
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _fechaFiltro != null
                            ? "No hay registros para esa fecha"
                            : "No hay registros aún",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtrados.length,
                    itemBuilder: (context, index) {
                      final item = _filtrados[index];
                      final estado = item['estado'] as String;
                      final color = _colorEstado(estado);
                      final entrada = item['hora_entrada']
                              ?.toString()
                              .substring(0, 8) ??
                          '--';
                      final salida = item['hora_salida']
                              ?.toString()
                              .substring(0, 8) ??
                          '--';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: color.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fecha + estado
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatFechaLegible(item['fecha']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(_iconoEstado(estado),
                                            size: 13, color: color),
                                        const SizedBox(width: 4),
                                        Text(
                                          estado,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Entrada y salida
                              Row(
                                children: [
                                  Expanded(
                                    child: _horaTile(
                                      Icons.login,
                                      "Entrada",
                                      entrada,
                                      Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _horaTile(
                                      Icons.logout,
                                      "Salida",
                                      salida,
                                      salida == '--'
                                          ? Colors.grey
                                          : Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _horaTile(
      IconData icono, String label, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                valor,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}