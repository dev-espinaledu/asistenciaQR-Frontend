import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/secure_storage.dart';

class AdminHistorialScreen extends StatefulWidget {
  const AdminHistorialScreen({super.key});

  @override
  State<AdminHistorialScreen> createState() => _AdminHistorialScreenState();
}

class _AdminHistorialScreenState extends State<AdminHistorialScreen> {
  List<dynamic> _registros = [];
  List<dynamic> _filtrados = [];
  List<dynamic> _usuariosParaEliminar = [];
  bool _isLoading = true;
  String _rol = '';
  final TextEditingController _searchController = TextEditingController();
  dynamic _usuarioEliminar;
  DateTime? _fechaEliminar;

  DateTime? _fechaFiltro;
  String? _estadoFiltro;

  @override
  void initState() {
    super.initState();
    _cargarRol();
    _fetchHistorial();
    _searchController.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarRol() async {
    final rol = await SecureStorage.getRol();
    setState(() => _rol = rol ?? '');
  }

  Future<void> _fetchHistorial() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get("/asistencia/todos");
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _registros = jsonDecode(response.body);
          _filtrados = _registros;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showError("Error de conexión");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _filtrar() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtrados = _registros.where((item) {
        final nombre =
            "${item['nombres']} ${item['apellidos']}".toLowerCase();
        final coincideNombre = nombre.contains(query);
        final coincideFecha = _fechaFiltro == null ||
            item['fecha'].toString().substring(0, 10) ==
                "${_fechaFiltro!.year}-${_fechaFiltro!.month.toString().padLeft(2, '0')}-${_fechaFiltro!.day.toString().padLeft(2, '0')}";
        final coincideEstado =
            _estadoFiltro == null || item['estado'] == _estadoFiltro;
        return coincideNombre && coincideFecha && coincideEstado;
      }).toList();
    });
  }

  void _mostrarFiltros() {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Filtros",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text("Limpiar"),
                    onPressed: () {
                      setState(() {
                        _fechaFiltro = null;
                        _estadoFiltro = null;
                      });
                      _filtrar();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              const Text("Fecha",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaFiltro ?? DateTime.now(),
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _fechaFiltro = picked);
                    setSheetState(() {});
                    _filtrar();
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _fechaFiltro != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setState(() => _fechaFiltro = null);
                              setSheetState(() {});
                              _filtrar();
                            },
                          )
                        : const Icon(Icons.calendar_today, size: 16),
                  ),
                  child: Text(
                    _fechaFiltro != null
                        ? "${_fechaFiltro!.year}-${_fechaFiltro!.month.toString().padLeft(2, '0')}-${_fechaFiltro!.day.toString().padLeft(2, '0')}"
                        : "Todas las fechas",
                    style: TextStyle(
                      color:
                          _fechaFiltro != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text("Estado",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  null, 'PUNTUAL', 'TARDE', 'SIN_SALIDA', 'AUSENTE'
                ].map((estado) {
                  final label = estado == null
                      ? 'Todos'
                      : estado == 'PUNTUAL'
                          ? 'Puntual'
                          : estado == 'TARDE'
                              ? 'Tarde'
                              : estado == 'SIN_SALIDA'
                                  ? 'Sin salida'
                                  : 'Ausente';
                  final color = estado == null
                      ? Colors.indigo
                      : estado == 'PUNTUAL'
                          ? Colors.green
                          : estado == 'TARDE'
                              ? Colors.orange
                              : estado == 'SIN_SALIDA'
                                  ? Colors.red
                                  : Colors.purple;
                  final seleccionado = _estadoFiltro == estado;
                  return ChoiceChip(
                    label: Text(label),
                    selected: seleccionado,
                    selectedColor: color.withValues(alpha: 0.2),
                    onSelected: (_) {
                      setState(() => _estadoFiltro = estado);
                      setSheetState(() {});
                      _filtrar();
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Aplicar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cargarUsuariosParaEliminar() async {
    try {
      final response = await ApiService.get("/usuarios");
      if (response.statusCode == 200) {
        final todos = jsonDecode(response.body) as List;
        _usuariosParaEliminar = todos.where((u) =>
          u['rol'] == 'DOCENTE' ||
          u['rol'] == 'ADMINISTRATIVO' ||
          u['rol'] == 'SERVICIOS_GENERALES' ||
          u['rol'] == 'PRACTICANTE'
        ).toList();
      }
    } catch (e) {
      _showError("Error al cargar usuarios");
    }
  }

  Future<void> _mostrarDialogoEliminar() async {
    await _cargarUsuariosParaEliminar();
    _usuarioEliminar = null;
    _fechaEliminar = null;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.red),
              SizedBox(width: 8),
              Text("Eliminar registros"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Selecciona los filtros. Si no seleccionas ninguno, se eliminarán TODOS los registros.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final seleccionado = await showDialog<dynamic>(
                    context: context,
                    builder: (_) => SimpleDialog(
                      title: const Text("Seleccionar usuario"),
                      children: [
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text("Todos los usuarios"),
                        ),
                        ..._usuariosParaEliminar.map((u) =>
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, u),
                              child: Text(u['correo'] ?? ''),
                            )),
                      ],
                    ),
                  );
                  setDialogState(() => _usuarioEliminar = seleccionado);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Usuario (opcional)",
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _usuarioEliminar != null
                        ? _usuarioEliminar['correo']
                        : "Todos los usuarios",
                    style: TextStyle(
                      color: _usuarioEliminar != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => _fechaEliminar = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Fecha (opcional)",
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.calendar_today, size: 16),
                  ),
                  child: Text(
                    _fechaEliminar != null
                        ? "${_fechaEliminar!.year}-${_fechaEliminar!.month.toString().padLeft(2, '0')}-${_fechaEliminar!.day.toString().padLeft(2, '0')}"
                        : "Todas las fechas",
                    style: TextStyle(
                      color: _fechaEliminar != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              if (_fechaEliminar != null)
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text("Quitar filtro de fecha"),
                  onPressed: () =>
                      setDialogState(() => _fechaEliminar = null),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text("Eliminar"),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _confirmarEliminar();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("¿Estás seguro?"),
        content: Text(
          _usuarioEliminar == null && _fechaEliminar == null
              ? "Se eliminarán TODOS los registros de asistencia. Esta acción no se puede deshacer."
              : "Se eliminarán los registros seleccionados. Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, eliminar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _eliminarRegistros();
  }

  Future<void> _eliminarRegistros() async {
    try {
      String path = "/asistencia/eliminar";
      final params = <String>[];

      if (_usuarioEliminar != null) {
        params.add("idUsuario=${_usuarioEliminar['id_usuario']}");
      }
      if (_fechaEliminar != null) {
        final f = _fechaEliminar!;
        final fechaStr =
            "${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}";
        params.add("fecha=$fechaStr");
      }

      if (params.isNotEmpty) path += "?${params.join('&')}";

      final response = await ApiService.delete(path);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showSuccess("${data['eliminados']} registro(s) eliminado(s)");
        _fetchHistorial();
      } else {
        _showError("Error al eliminar registros");
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial General"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Solo ADMIN puede eliminar
          if (_rol == 'ADMIN')
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Eliminar registros",
              onPressed: _mostrarDialogoEliminar,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistorial,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: "Buscar por nombre...",
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.filter_list),
                            tooltip: "Filtros",
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.indigo.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _mostrarFiltros,
                          ),
                          if (_fechaFiltro != null || _estadoFiltro != null)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _filtrados.isEmpty
                      ? const Center(child: Text("No hay registros"))
                      : RefreshIndicator(
                          onRefresh: _fetchHistorial,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.indigo.shade50,
                                ),
                                columns: const [
                                  DataColumn(label: Text("Nombre")),
                                  DataColumn(label: Text("Fecha")),
                                  DataColumn(label: Text("Entrada")),
                                  DataColumn(label: Text("Salida")),
                                  DataColumn(label: Text("Estado")),
                                ],
                                rows: _filtrados.map((item) {
                                  final fecha = item['fecha']
                                      .toString()
                                      .substring(0, 10);
                                  return DataRow(cells: [
                                    DataCell(Text(
                                        "${item['nombres']} ${item['apellidos']}")),
                                    DataCell(Text(fecha)),
                                    DataCell(
                                        Text(item['hora_entrada'] ?? '--')),
                                    DataCell(
                                        Text(item['hora_salida'] ?? '--')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _colorEstado(item['estado'])
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item['estado'],
                                          style: TextStyle(
                                            color:
                                                _colorEstado(item['estado']),
                                            fontWeight: FontWeight.bold,
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
                ),
              ],
            ),
    );
  }
}