import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/secure_storage.dart';

class AdminHorariosScreen extends StatefulWidget {
  const AdminHorariosScreen({super.key});

  @override
  State<AdminHorariosScreen> createState() => _AdminHorariosScreenState();
}

class _AdminHorariosScreenState extends State<AdminHorariosScreen> {
  List<dynamic> _usuarios = [];
  dynamic _usuarioSeleccionado;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _diasSemana = [
    '', 'Lunes', 'Martes', 'Miércoles',
    'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  final List<Map<String, dynamic>> _horarios = List.generate(7, (i) => {
    "dia_semana": i + 1,
    "hora_entrada": "07:00",
    "hora_salida": "13:00",
    "tolerancia_minutos": 5,
    "habilitado": i < 5,
  });

  late List<TextEditingController> _entradaControllers;
  late List<TextEditingController> _salidaControllers;
  late List<TextEditingController> _toleranciaControllers;
  late List<bool> _habilitados;

  // ── Horario general ──
  int _diaGeneralSeleccionado = 1;
  final TextEditingController _entradaGeneralController =
      TextEditingController(text: "07:00");
  final TextEditingController _salidaGeneralController =
      TextEditingController(text: "13:00");
  final TextEditingController _toleranciaGeneralController =
      TextEditingController(text: "5");

  @override
  void initState() {
    super.initState();
    _entradaControllers = List.generate(
        7, (i) => TextEditingController(text: _horarios[i]['hora_entrada']));
    _salidaControllers = List.generate(
        7, (i) => TextEditingController(text: _horarios[i]['hora_salida']));
    _toleranciaControllers = List.generate(
        7, (i) => TextEditingController(
            text: _horarios[i]['tolerancia_minutos'].toString()));
    _habilitados = List.generate(7, (i) => i < 5);
    _fetchUsuarios();
  }

  @override
  void dispose() {
    for (int i = 0; i < 7; i++) {
      _entradaControllers[i].dispose();
      _salidaControllers[i].dispose();
      _toleranciaControllers[i].dispose();
    }
    _entradaGeneralController.dispose();
    _salidaGeneralController.dispose();
    _toleranciaGeneralController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsuarios() async {
    setState(() {
      _isLoading = true;
      _usuarioSeleccionado = null;
    });
    try {
      final token = await SecureStorage.getToken();
      final response = await http.get(
        Uri.parse("http://192.168.101.17:3000/usuarios"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        setState(() => _usuarios = jsonDecode(response.body));
      }
    } catch (e) {
      _showError("Error de conexión");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchHorarios(int idUsuario) async {
    try {
      final token = await SecureStorage.getToken();
      final response = await http.get(
        Uri.parse("http://192.168.101.17:3000/usuarios/$idUsuario/horarios"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> horarios = jsonDecode(response.body);
        for (final h in horarios) {
          final index = (h['dia_semana'] as int) - 1;
          if (index >= 0 && index < 7) {
            setState(() {
              _entradaControllers[index].text =
                  h['hora_entrada'].toString().substring(0, 5);
              _salidaControllers[index].text =
                  h['hora_salida'].toString().substring(0, 5);
              _toleranciaControllers[index].text =
                  h['tolerancia_minutos'].toString();
              _habilitados[index] = h['habilitado'] as bool;
            });
          }
        }
      }
    } catch (e) {
      _showError("Error al cargar horarios");
    }
  }

  Future<void> _guardarHorarios() async {
    final List<Map<String, dynamic>> horarios = List.generate(7, (i) => {
      "dia_semana": i + 1,
      "hora_entrada": _entradaControllers[i].text,
      "hora_salida": _salidaControllers[i].text,
      "tolerancia_minutos":
          int.tryParse(_toleranciaControllers[i].text) ?? 5,
      "habilitado": _habilitados[i],
    });

    setState(() => _isSaving = true);
    try {
      final token = await SecureStorage.getToken();
      final response = await http.put(
        Uri.parse(
            "http://192.168.101.17:3000/usuarios/${_usuarioSeleccionado['id_usuario']}/horarios"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"horarios": horarios}),
      );
      if (response.statusCode == 200) {
        _showSuccess("Horarios guardados correctamente");
      } else {
        final data = jsonDecode(response.body);
        _showError(data["error"] ?? "Error al guardar");
      }
    } catch (e) {
      _showError("Error de conexión");
    }
    setState(() => _isSaving = false);
  }

  Future<void> _seleccionarHora(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final inicial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: inicial,
    );
    if (picked != null) {
      controller.text =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
    }
  }

  // ── Diálogo horario general ──
  Future<void> _mostrarDialogoHorarioGeneral() async {
    _diaGeneralSeleccionado = 1;
    _entradaGeneralController.text = "07:00";
    _salidaGeneralController.text = "13:00";
    _toleranciaGeneralController.text = "5";

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.people, color: Colors.indigo),
              SizedBox(width: 8),
              Text("Horario general"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Se aplicará a todos los docentes y administrativos activos, solo para el día seleccionado.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Selector de día
                DropdownButtonFormField<int>(
                  initialValue: _diaGeneralSeleccionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Día de la semana",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: List.generate(7, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(_diasSemana[i + 1]),
                  )),
                  onChanged: (v) =>
                      setDialogState(() => _diaGeneralSeleccionado = v!),
                ),

                const SizedBox(height: 12),

                // Hora entrada
                TextFormField(
                  controller: _entradaGeneralController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Hora de entrada",
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 7, minute: 0),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        _entradaGeneralController.text =
                            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                      });
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Hora salida
                TextFormField(
                  controller: _salidaGeneralController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Hora de salida",
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 13, minute: 0),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        _salidaGeneralController.text =
                            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                      });
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Tolerancia
                TextFormField(
                  controller: _toleranciaGeneralController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Tolerancia (minutos)",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text("Aplicar a todos"),
              onPressed: () {
                Navigator.pop(context);
                _confirmarHorarioGeneral();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarHorarioGeneral() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("¿Estás seguro?"),
        content: Text(
          "Se actualizará el horario del ${_diasSemana[_diaGeneralSeleccionado]} "
          "para todos los docentes y administrativos activos. "
          "Los demás días no se verán afectados.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, aplicar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _aplicarHorarioGeneral();
  }

  Future<void> _aplicarHorarioGeneral() async {
    try {
      final token = await SecureStorage.getToken();
      final response = await http.post(
        Uri.parse("http://192.168.101.17:3000/usuarios/horario-general"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "diaSemana": _diaGeneralSeleccionado,
          "horaEntrada": _entradaGeneralController.text,
          "horaSalida": _salidaGeneralController.text,
          "tolerancia":
              int.tryParse(_toleranciaGeneralController.text) ?? 5,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showSuccess(
            "Horario aplicado a ${data['actualizados']} usuario(s)");

        // Recargar horarios del usuario seleccionado si hay uno
        if (_usuarioSeleccionado != null) {
          _fetchHorarios(_usuarioSeleccionado['id_usuario']);
        }
      } else {
        final data = jsonDecode(response.body);
        _showError(data["error"] ?? "Error al aplicar horario");
      }
    } catch (e) {
      _showError("Error de conexión");
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
        title: const Text("Gestión de Horarios"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Botón horario general
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: "Horario general",
            onPressed: _mostrarDialogoHorarioGeneral,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsuarios,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<dynamic>(
                    initialValue: _usuarioSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Seleccionar usuario",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _usuarios.map((u) {
                      return DropdownMenuItem(
                        value: u,
                        child: Text(
                          "${u['correo']} (${u['rol']})",
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _usuarioSeleccionado = value);
                      if (value != null) {
                        _fetchHorarios(value['id_usuario']);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  if (_usuarioSeleccionado != null) ...[
                    const Text(
                      "Horarios por día",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: ListView.builder(
                        itemCount: 7,
                        itemBuilder: (context, i) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: _habilitados[i]
                                ? null
                                : Colors.grey.shade100,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _diasSemana[i + 1],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: _habilitados[i]
                                              ? Colors.indigo
                                              : Colors.grey,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            _habilitados[i]
                                                ? "Habilitado"
                                                : "Deshabilitado",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _habilitados[i]
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                          ),
                                          Switch(
                                            value: _habilitados[i],
                                            activeThumbColor: Colors.indigo,
                                            onChanged: (value) {
                                              setState(() =>
                                                  _habilitados[i] = value);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (_habilitados[i]) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller:
                                                _entradaControllers[i],
                                            readOnly: true,
                                            decoration:
                                                const InputDecoration(
                                              labelText: "Entrada",
                                              border: OutlineInputBorder(),
                                              suffixIcon:
                                                  Icon(Icons.access_time),
                                            ),
                                            onTap: () => _seleccionarHora(
                                                _entradaControllers[i]),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            controller:
                                                _salidaControllers[i],
                                            readOnly: true,
                                            decoration:
                                                const InputDecoration(
                                              labelText: "Salida",
                                              border: OutlineInputBorder(),
                                              suffixIcon:
                                                  Icon(Icons.access_time),
                                            ),
                                            onTap: () => _seleccionarHora(
                                                _salidaControllers[i]),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextFormField(
                                            controller:
                                                _toleranciaControllers[i],
                                            keyboardType:
                                                TextInputType.number,
                                            decoration:
                                                const InputDecoration(
                                              labelText: "Tolerancia (min)",
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: _isSaving
                            ? const CircularProgressIndicator()
                            : const Text("Guardar horarios"),
                        onPressed: _isSaving ? null : _guardarHorarios,
                      ),
                    ),
                  ] else ...[
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Selecciona un usuario para editar sus horarios",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}