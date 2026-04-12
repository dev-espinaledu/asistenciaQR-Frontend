import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminEstadisticasScreen extends StatefulWidget {
  const AdminEstadisticasScreen({super.key});

  @override
  State<AdminEstadisticasScreen> createState() =>
      _AdminEstadisticasScreenState();
}

class _AdminEstadisticasScreenState extends State<AdminEstadisticasScreen> {
  List<dynamic> _usuarios = [];
  dynamic _usuarioSeleccionado;
  Map<String, dynamic>? _estadisticas;
  bool _isLoadingUsuarios = true;
  bool _isLoadingEstadisticas = false;
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchUsuarios();
  }

  Future<void> _fetchUsuarios() async {
    setState(() => _isLoadingUsuarios = true);
    try {
      final response = await ApiService.get("/usuarios");
      if (response.statusCode == 200) {
        final todos = jsonDecode(response.body) as List;
        setState(() {
          _usuarios = todos
              .where((u) =>
                  u['rol'] == 'DOCENTE' ||
                  u['rol'] == 'ADMINISTRATIVO' ||
                  u['rol'] == 'SERVICIOS_GENERALES' ||
                  u['rol'] == 'PRACTICANTE')
              .toList();
        });
      }
    } catch (e) {
      _showError("Error al cargar usuarios");
    }
    setState(() => _isLoadingUsuarios = false);
  }

  Future<void> _fetchEstadisticas() async {
    if (_usuarioSeleccionado == null) return;
    setState(() {
      _isLoadingEstadisticas = true;
      _estadisticas = null;
    });
    try {
      final id = _usuarioSeleccionado['id_usuario'];
      final response = await ApiService.get(
        "/asistencia/estadisticas/$id?mes=$_mesSeleccionado&anio=$_anioSeleccionado",
      );
      if (response.statusCode == 200) {
        setState(() => _estadisticas = jsonDecode(response.body));
      }
    } catch (e) {
      _showError("Error al cargar estadísticas");
    }
    setState(() => _isLoadingEstadisticas = false);
  }

  String _nombreMes(int mes) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[mes];
  }

  void _mostrarSelectorMes() {
    int mesTemp = _mesSeleccionado;
    int anioTemp = _anioSeleccionado;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Seleccionar período",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 8),

              const Text("Año",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setSheetState(() => anioTemp--),
                  ),
                  Text(
                    "$anioTemp",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: anioTemp < DateTime.now().year
                        ? () => setSheetState(() => anioTemp++)
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Text("Mes",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (i) {
                  final m = i + 1;
                  final seleccionado = mesTemp == m;
                  final esFuturo = anioTemp == DateTime.now().year &&
                      m > DateTime.now().month;
                  return ChoiceChip(
                    label: Text(_nombreMes(m).substring(0, 3)),
                    selected: seleccionado,
                    selectedColor: Colors.indigo.shade100,
                    disabledColor: Colors.grey.shade100,
                    onSelected: esFuturo
                        ? null
                        : (_) => setSheetState(() => mesTemp = m),
                  );
                }),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _mesSeleccionado = mesTemp;
                      _anioSeleccionado = anioTemp;
                      _estadisticas = null;
                    });
                    _fetchEstadisticas();
                    Navigator.pop(context);
                  },
                  child: const Text("Aplicar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _statChip(String label, int valor, Color color, IconData icono) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              "$valor",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Estadísticas por usuario"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_usuarioSeleccionado != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchEstadisticas,
            ),
        ],
      ),
      body: _isLoadingUsuarios
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Selector de usuario ──
                  DropdownButtonFormField<dynamic>(
                    initialValue: _usuarioSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Seleccionar usuario",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text("Selecciona un usuario")),
                      ..._usuarios.map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(
                              "${u['correo']} (${u['rol']})",
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _usuarioSeleccionado = v;
                        _estadisticas = null;
                      });
                      if (v != null) _fetchEstadisticas();
                    },
                  ),

                  const SizedBox(height: 16),

                  if (_usuarioSeleccionado == null)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "Selecciona un usuario para ver sus estadísticas",
                              style: TextStyle(color: Colors.grey.shade500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título + selector período
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.bar_chart,
                                            color: Colors.indigo),
                                        SizedBox(width: 8),
                                        Text(
                                          "Estadísticas",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.calendar_month,
                                          size: 16),
                                      label: Text(
                                        "${_nombreMes(_mesSeleccionado)} $_anioSeleccionado",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: _mostrarSelectorMes,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                if (_isLoadingEstadisticas)
                                  const Center(
                                      child: CircularProgressIndicator())
                                else if (_estadisticas == null)
                                  const Center(
                                    child: Text(
                                      "No hay datos disponibles",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else ...[
                                  // Total
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Días asistidos"),
                                      Text(
                                        "${_estadisticas!['total'] ?? 0}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Barra puntualidad
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Puntualidad"),
                                      Text(
                                        "${_estadisticas!['porcentajePuntualidad'] ?? 0}%",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: ((_estadisticas![
                                                      'porcentajePuntualidad'] ??
                                                  0) as int) /
                                          100,
                                      minHeight: 10,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Colors.indigo),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Chips estados
                                  Row(
                                    children: [
                                      _statChip(
                                        "Puntual",
                                        (_estadisticas!['puntual'] ?? 0) as int,
                                        Colors.green,
                                        Icons.check_circle,
                                      ),
                                      const SizedBox(width: 8),
                                      _statChip(
                                        "Tarde",
                                        (_estadisticas!['tarde'] ?? 0) as int,
                                        Colors.orange,
                                        Icons.schedule,
                                      ),
                                      const SizedBox(width: 8),
                                      _statChip(
                                        "Sin salida",
                                        (_estadisticas!['sinSalida'] ?? 0)
                                            as int,
                                        Colors.red,
                                        Icons.warning,
                                      ),
                                      const SizedBox(width: 8),
                                      _statChip(
                                        "Ausente",
                                        (_estadisticas!['ausente'] ?? 0) as int,
                                        Colors.purple,
                                        Icons.person_off,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}