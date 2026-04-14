import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminRegistroManualScreen extends StatefulWidget {
  const AdminRegistroManualScreen({super.key});

  @override
  State<AdminRegistroManualScreen> createState() =>
      _AdminRegistroManualScreenState();
}

class _AdminRegistroManualScreenState
    extends State<AdminRegistroManualScreen> {
  List<dynamic> _usuarios = [];
  dynamic _usuarioSeleccionado;
  DateTime _fechaSeleccionada = DateTime.now();
  TimeOfDay? _horaEntrada;
  TimeOfDay? _horaSalida;
  String _estadoSeleccionado = 'PUNTUAL';
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _estados = ['PUNTUAL', 'TARDE', 'AUSENTE'];

  @override
  void initState() {
    super.initState();
    _fetchUsuarios();
  }

  Future<void> _fetchUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get("/usuarios");
      if (response.statusCode == 200) {
        final todos = jsonDecode(response.body) as List;
        setState(() {
          _usuarios = todos.where((u) =>
            u['rol'] == 'DOCENTE' ||
            u['rol'] == 'ADMINISTRATIVO' ||
            u['rol'] == 'SERVICIOS_GENERALES' ||
            u['rol'] == 'PRACTICANTE'
          ).toList();
        });
      }
    } catch (e) {
      _showError("Error al cargar usuarios");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fechaSeleccionada = picked);
  }

  Future<void> _seleccionarHora(bool esEntrada) async {
    final inicial = esEntrada
        ? (_horaEntrada ?? const TimeOfDay(hour: 7, minute: 0))
        : (_horaSalida ?? const TimeOfDay(hour: 13, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: inicial,
    );
    if (picked != null) {
      setState(() {
        if (esEntrada) {
          _horaEntrada = picked;
        } else {
          _horaSalida = picked;
        }
      });
    }
  }

  String _formatHora(TimeOfDay? hora) {
    if (hora == null) return '--';
    return "${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}:00";
  }

  String _formatFecha(DateTime fecha) {
    return "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'PUNTUAL': return Colors.green;
      case 'TARDE': return Colors.orange;
      case 'AUSENTE': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Future<void> _guardar() async {
    if (_usuarioSeleccionado == null) {
      _showError("Selecciona un usuario");
      return;
    }
    if (_estadoSeleccionado != 'AUSENTE' && _horaEntrada == null) {
      _showError("Ingresa la hora de entrada");
      return;
    }

    setState(() => _isSaving = true);
    try {
      final body = {
        "idUsuario": _usuarioSeleccionado['id_usuario'],
        "fecha": _formatFecha(_fechaSeleccionada),
        "estado": _estadoSeleccionado,
        if (_horaEntrada != null) "horaEntrada": _formatHora(_horaEntrada),
        if (_horaSalida != null) "horaSalida": _formatHora(_horaSalida),
      };

      final response = await ApiService.post("/asistencia/manual", body);

      if (response.statusCode == 200) {
        _showSuccess("Asistencia registrada correctamente");
        setState(() {
          _usuarioSeleccionado = null;
          _fechaSeleccionada = DateTime.now();
          _horaEntrada = null;
          _horaSalida = null;
          _estadoSeleccionado = 'PUNTUAL';
        });
      } else {
        final data = jsonDecode(response.body);
        _showError(data["error"] ?? "Error al registrar");
      }
    } catch (e) {
      _showError("Error de conexión");
    }
    setState(() => _isSaving = false);
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Registro Manual"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_calendar, color: Colors.indigo),
                            SizedBox(width: 8),
                            Text(
                              "Datos de asistencia",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "El registro manual sobreescribe cualquier asistencia existente para esa fecha.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Divider(height: 24),

                        // Usuario
                        DropdownButtonFormField<dynamic>(
                          initialValue: _usuarioSeleccionado,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: "Usuario",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text("Selecciona un usuario")),
                            ..._usuarios.map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(
                                    "${u['correo']} (${u['rol']})",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) =>
                              setState(() => _usuarioSeleccionado = v),
                        ),

                        const SizedBox(height: 12),

                        // Fecha
                        InkWell(
                          onTap: _seleccionarFecha,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: "Fecha",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(_formatFecha(_fechaSeleccionada)),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Estado
                        DropdownButtonFormField<String>(
                          initialValue: _estadoSeleccionado,
                          decoration: const InputDecoration(
                            labelText: "Estado",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag),
                          ),
                          items: _estados.map((e) {
                            final label = e == 'PUNTUAL'
                                ? 'Puntual'
                                : e == 'TARDE'
                                    ? 'Tarde'
                                      : 'Ausente';
                            return DropdownMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _colorEstado(e),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(label),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _estadoSeleccionado = v!),
                        ),

                        const SizedBox(height: 12),

                        // (ocultar si es AUSENTE)
                        if (_estadoSeleccionado != 'AUSENTE') ...[
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _seleccionarHora(true),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: "Hora entrada",
                                      border: const OutlineInputBorder(),
                                      prefixIcon:
                                          const Icon(Icons.login),
                                      suffixIcon:
                                          const Icon(Icons.access_time),
                                      filled: _horaEntrada != null,
                                      fillColor: _horaEntrada != null
                                          ? Colors.green.shade50
                                          : null,
                                    ),
                                    child: Text(
                                      _horaEntrada != null
                                          ? "${_horaEntrada!.hour.toString().padLeft(2, '0')}:${_horaEntrada!.minute.toString().padLeft(2, '0')}"
                                          : "Seleccionar",
                                      style: TextStyle(
                                        color: _horaEntrada != null
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _seleccionarHora(false),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: "Hora salida",
                                      border: const OutlineInputBorder(),
                                      prefixIcon:
                                          const Icon(Icons.logout),
                                      suffixIcon:
                                          const Icon(Icons.access_time),
                                      filled: _horaSalida != null,
                                      fillColor: _horaSalida != null
                                          ? Colors.indigo.shade50
                                          : null,
                                    ),
                                    child: Text(
                                      _horaSalida != null
                                          ? "${_horaSalida!.hour.toString().padLeft(2, '0')}:${_horaSalida!.minute.toString().padLeft(2, '0')}"
                                          : "Seleccionar",
                                      style: TextStyle(
                                        color: _horaSalida != null
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "La hora de salida es opcional.",
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Registrar asistencia"),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSaving ? null : _guardar,
                  ),
                ),
              ],
            ),
    );
  }
}