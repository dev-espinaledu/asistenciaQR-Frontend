import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/secure_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class AdminReportesScreen extends StatefulWidget {
  const AdminReportesScreen({super.key});

  @override
  State<AdminReportesScreen> createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen> {
  List<dynamic> _usuarios = [];
  List<dynamic> _resultados = [];
  dynamic _usuarioSeleccionado;
  String? _estadoSeleccionado;
  DateTime _desde = DateTime.now().subtract(const Duration(days: 7));
  DateTime _hasta = DateTime.now();
  bool _isLoading = false;
  bool _buscado = false;
  String _rol = '';

  final List<String?> _estados = [null, 'PUNTUAL', 'TARDE', 'AUSENTE'];
  final List<String> _estadosLabel = ['Todos', 'Puntual', 'Tarde', 'Ausente'];

  @override
  void initState() {
    super.initState();
    _cargarRol();
    _fetchUsuarios();
  }

  Future<void> _cargarRol() async {
    final rol = await SecureStorage.getRol();
    setState(() => _rol = rol ?? '');
  }

  Future<void> _fetchUsuarios() async {
    try {
      final response = await ApiService.get("/usuarios");
      if (response.statusCode == 200) {
        final todos = jsonDecode(response.body) as List;
        setState(() {
          _usuarios = todos
              .where((u) =>
                  u['rol'] == 'DOCENTE' || u['rol'] == 'ADMINISTRATIVO')
              .toList();
        });
      }
    } catch (e) {
      _showError("Error al cargar usuarios");
    }
  }

  Future<void> _buscarReporte() async {
    setState(() {
      _isLoading = true;
      _buscado = true;
    });

    try {
      final desde = _formatFecha(_desde);
      final hasta = _formatFecha(_hasta);

      String path = "/asistencia/reportes?desde=$desde&hasta=$hasta";

      if (_usuarioSeleccionado != null) {
        path += "&idUsuario=${_usuarioSeleccionado['id_usuario']}";
      }
      if (_estadoSeleccionado != null) {
        path += "&estado=$_estadoSeleccionado";
      }

      final response = await ApiService.get(path);

      if (response.statusCode == 200) {
        setState(() => _resultados = jsonDecode(response.body));
      } else {
        _showError("Error al obtener reporte");
      }
    } catch (e) {
      _showError("Error de conexión");
    }

    setState(() => _isLoading = false);
  }

  String _formatFecha(DateTime fecha) {
    return "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
  }

  Future<void> _seleccionarFecha(bool esDesdeFecha) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esDesdeFecha ? _desde : _hasta,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (esDesdeFecha) {
          _desde = picked;
        } else {
          _hasta = picked;
        }
      });
    }
  }

  Map<String, int> get _totales {
    final map = {'PUNTUAL': 0, 'TARDE': 0, 'SIN_SALIDA': 0, 'AUSENTE': 0};
    for (final r in _resultados) {
      final estado = r['estado'] as String;
      if (map.containsKey(estado)) {
        map[estado] = map[estado]! + 1;
      }
    }
    return map;
  }

  Future<void> _exportarExcel() async {
    if (_resultados.isEmpty) {
      _showError("No hay datos para exportar");
      return;
    }

    try {
      final desde = _formatFecha(_desde);
      final hasta = _formatFecha(_hasta);

      String path = "/asistencia/excel?desde=$desde&hasta=$hasta";

      if (_usuarioSeleccionado != null) {
        path += "&idUsuario=${_usuarioSeleccionado['id_usuario']}";
      }
      if (_estadoSeleccionado != null) {
        path += "&estado=$_estadoSeleccionado";
      }

      final response = await ApiService.get(path);

      if (response.statusCode != 200) {
        _showError("Error al generar el reporte");
        return;
      }

      final nombreArchivo = "reporte_asistencia_${desde}_$hasta.xlsx";

      Directory dir;
      if (Platform.isAndroid) {
        dir = (await getExternalStorageDirectory())!;
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final pathFile = "${dir.path}/$nombreArchivo";
      final file = File(pathFile);
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(pathFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Archivo guardado: $nombreArchivo"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _showError("Error de conexión");
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'PUNTUAL': return Colors.green;
      case 'TARDE': return Colors.orange;
      case 'SIN_SALIDA': return Colors.red;
      case 'AUSENTE': return Colors.purple;
      default: return Colors.grey;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _resumenCard(String label, int valor, Color color, IconData icono) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icono, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                "$valor",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totales = _totales;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reportes de Asistencia"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<dynamic>(
                  value: _usuarioSeleccionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Usuario (opcional)",
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text("Todos los usuarios")),
                    ..._usuarios.map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            "${u['correo']} (${u['rol']})",
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _usuarioSeleccionado = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _seleccionarFecha(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "Desde",
                            border: OutlineInputBorder(),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon:
                                Icon(Icons.calendar_today, size: 16),
                          ),
                          child: Text(_formatFecha(_desde)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _seleccionarFecha(false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: "Hasta",
                            border: OutlineInputBorder(),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon:
                                Icon(Icons.calendar_today, size: 16),
                          ),
                          child: Text(_formatFecha(_hasta)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _estadoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: "Estado",
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: List.generate(
                    _estados.length,
                    (i) => DropdownMenuItem(
                      value: _estados[i],
                      child: Text(_estadosLabel[i]),
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _estadoSeleccionado = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text("Buscar"),
                    onPressed: _isLoading ? null : _buscarReporte,
                  ),
                ),
              ],
            ),
          ),

          if (_buscado && !_isLoading) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  _resumenCard("Puntual", totales['PUNTUAL']!,
                      Colors.green, Icons.check_circle),
                  const SizedBox(width: 8),
                  _resumenCard("Tarde", totales['TARDE']!,
                      Colors.orange, Icons.schedule),
                  const SizedBox(width: 8),
                  _resumenCard("Sin salida", totales['SIN_SALIDA']!,
                      Colors.red, Icons.warning),
                  const SizedBox(width: 8),
                  _resumenCard("Ausente", totales['AUSENTE']!,
                      Colors.purple, Icons.person_off),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${_resultados.length} registros encontrados",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  // ✅ Solo ADMIN puede exportar Excel
                  if (_rol == 'ADMIN')
                    FilledButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text("Excel"),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green),
                      onPressed:
                          _resultados.isEmpty ? null : _exportarExcel,
                    ),
                ],
              ),
            ),
          ],

          if (_isLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (_buscado && _resultados.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No hay registros para los filtros seleccionados",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else if (_resultados.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        Colors.indigo.shade50),
                    columns: const [
                      DataColumn(label: Text("Nombre")),
                      DataColumn(label: Text("Fecha")),
                      DataColumn(label: Text("Entrada")),
                      DataColumn(label: Text("Salida")),
                      DataColumn(label: Text("Estado")),
                    ],
                    rows: _resultados.map((item) {
                      final fecha =
                          item['fecha'].toString().substring(0, 10);
                      return DataRow(cells: [
                        DataCell(Text(
                            "${item['nombres']} ${item['apellidos']}")),
                        DataCell(Text(fecha)),
                        DataCell(Text(item['hora_entrada'] ?? '--')),
                        DataCell(Text(item['hora_salida'] ?? '--')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _colorEstado(item['estado'])
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item['estado'],
                              style: TextStyle(
                                color: _colorEstado(item['estado']),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}