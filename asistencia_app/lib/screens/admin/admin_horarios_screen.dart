import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';

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

  List<dynamic> _diasNoLaborables = [];
  DateTime _focusedDay = DateTime.now();

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
    _fetchDiasNoLaborables();
  }

  @override
  void dispose() {
    for (int i = 0; i < 7; i++) {
      _entradaControllers[i].dispose();
      _salidaControllers[i].dispose();
      _toleranciaControllers[i].dispose();
    }
    super.dispose();
  }

  Future<void> _fetchUsuarios() async {
    setState(() {
      _isLoading = true;
      _usuarioSeleccionado = null;
    });
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
      _showError("Error de conexión");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchDiasNoLaborables({int? idUsuario}) async {
    try {
      final path = idUsuario != null
          ? "/dias-no-laborables?idUsuario=$idUsuario"
          : "/dias-no-laborables";
      final response = await ApiService.get(path);
      if (response.statusCode == 200) {
        setState(() => _diasNoLaborables = jsonDecode(response.body));
      }
    } catch (e) {
      // silencioso
    }
  }

  Future<void> _fetchHorarios(int idUsuario) async {
    try {
      final response = await ApiService.get("/usuarios/$idUsuario/horarios");
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
    final List<Map<String, dynamic>> horarios = List.generate(
      7,
      (i) => {
        "dia_semana": i + 1,
        "hora_entrada": _entradaControllers[i].text,
        "hora_salida": _salidaControllers[i].text,
        "tolerancia_minutos": int.tryParse(_toleranciaControllers[i].text) ?? 5,
        "habilitado": _habilitados[i],
      },
    );

    setState(() => _isSaving = true);
    try {
      final response = await ApiService.put(
        "/usuarios/${_usuarioSeleccionado['id_usuario']}/horarios",
        {"horarios": horarios},
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
    final picked = await showTimePicker(context: context, initialTime: inicial);
    if (picked != null) {
      controller.text =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
    }
  }

  // ── Nuevo horario general con días de la semana ──
  void _mostrarHorarioGeneral() {
    final List<bool> diasSeleccionados = List.generate(7, (i) => false);
    final List<String> rolesDisponibles = [
      'DOCENTE', 'ADMINISTRATIVO', 'SERVICIOS_GENERALES', 'PRACTICANTE'
    ];
    final List<bool> rolesSeleccionados = List.generate(4, (_) => true);
    TimeOfDay horaEntrada = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay horaSalida = const TimeOfDay(hour: 13, minute: 0);
    int tolerancia = 5;
    bool isApplying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Título ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Horario general",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Text(
                    "Se aplicará a los roles y días seleccionados.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 24),

                  // ── Roles ──
                  const Text(
                    "Aplicar a roles",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(rolesDisponibles.length, (i) {
                      final label = rolesDisponibles[i] == 'DOCENTE'
                          ? 'Docentes'
                          : rolesDisponibles[i] == 'ADMINISTRATIVO'
                              ? 'Administrativos'
                              : rolesDisponibles[i] == 'SERVICIOS_GENERALES'
                                  ? 'Servicios Generales'
                                  : 'Practicantes';
                      return FilterChip(
                        label: Text(label),
                        selected: rolesSeleccionados[i],
                        selectedColor: Colors.teal.shade100,
                        checkmarkColor: Colors.teal,
                        onSelected: (v) =>
                            setSheetState(() => rolesSeleccionados[i] = v),
                      );
                    }),
                  ),

                  // Atajos roles
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text("Todos los roles"),
                        onPressed: () => setSheetState(() {
                          for (int i = 0; i < rolesSeleccionados.length; i++) {
                            rolesSeleccionados[i] = true;
                          }
                        }),
                      ),
                      ActionChip(
                        label: const Text("Ninguno"),
                        onPressed: () => setSheetState(() {
                          for (int i = 0; i < rolesSeleccionados.length; i++) {
                            rolesSeleccionados[i] = false;
                          }
                        }),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // ── Días de la semana ──
                  const Text(
                    "Días de la semana",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      return FilterChip(
                        label: Text(_diasSemana[i + 1].substring(0, 2)),
                        selected: diasSeleccionados[i],
                        selectedColor: Colors.indigo.shade100,
                        checkmarkColor: Colors.indigo,
                        onSelected: (v) =>
                            setSheetState(() => diasSeleccionados[i] = v),
                      );
                    }),
                  ),

                  // Atajos días
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text("Lun - Vie"),
                        onPressed: () => setSheetState(() {
                          for (int i = 0; i < 7; i++) {
                            diasSeleccionados[i] = i < 5;
                          }
                        }),
                      ),
                      ActionChip(
                        label: const Text("Todos"),
                        onPressed: () => setSheetState(() {
                          for (int i = 0; i < 7; i++) {
                            diasSeleccionados[i] = true;
                          }
                        }),
                      ),
                      ActionChip(
                        label: const Text("Ninguno"),
                        onPressed: () => setSheetState(() {
                          for (int i = 0; i < 7; i++) {
                            diasSeleccionados[i] = false;
                          }
                        }),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // ── Hora entrada ──
                  const Text(
                    "Hora de entrada",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: horaEntrada,
                      );
                      if (picked != null) {
                        setSheetState(() => horaEntrada = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        "${horaEntrada.hour.toString().padLeft(2, '0')}:${horaEntrada.minute.toString().padLeft(2, '0')}",
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Hora salida ──
                  const Text(
                    "Hora de salida",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: horaSalida,
                      );
                      if (picked != null) {
                        setSheetState(() => horaSalida = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        "${horaSalida.hour.toString().padLeft(2, '0')}:${horaSalida.minute.toString().padLeft(2, '0')}",
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Tolerancia ──
                  const Text(
                    "Tolerancia (minutos)",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: tolerancia.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => tolerancia = int.tryParse(v) ?? 5,
                  ),

                  const SizedBox(height: 24),

                  // ── Botón aplicar ──
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: isApplying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                          isApplying ? "Aplicando..." : "Aplicar a todos"),
                      onPressed: isApplying ||
                              !diasSeleccionados.contains(true) ||
                              !rolesSeleccionados.contains(true)
                          ? null
                          : () async {
                              final diasNombres = List.generate(7, (i) => i)
                                  .where((i) => diasSeleccionados[i])
                                  .map((i) => _diasSemana[i + 1])
                                  .join(', ');

                              final rolesNombres = List.generate(
                                      rolesDisponibles.length, (i) => i)
                                  .where((i) => rolesSeleccionados[i])
                                  .map((i) {
                                    final r = rolesDisponibles[i];
                                    return r == 'DOCENTE'
                                        ? 'Docentes'
                                        : r == 'ADMINISTRATIVO'
                                            ? 'Administrativos'
                                            : r == 'SERVICIOS_GENERALES'
                                                ? 'Servicios Generales'
                                                : 'Practicantes';
                                  })
                                  .join(', ');

                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16)),
                                  title: const Text("¿Estás seguro?"),
                                  content: Text(
                                    "Se actualizará el horario de $diasNombres para: $rolesNombres.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("Cancelar"),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("Sí, aplicar"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm != true) return;

                              setSheetState(() => isApplying = true);

                              // Roles seleccionados
                              final roles = List.generate(
                                      rolesDisponibles.length, (i) => i)
                                  .where((i) => rolesSeleccionados[i])
                                  .map((i) => rolesDisponibles[i])
                                  .toList();

                              int aplicados = 0;
                              for (int i = 0; i < 7; i++) {
                                if (!diasSeleccionados[i]) continue;
                                try {
                                  final response = await ApiService.post(
                                    "/usuarios/horario-general",
                                    {
                                      "diaSemana": i + 1,
                                      "horaEntrada":
                                          "${horaEntrada.hour.toString().padLeft(2, '0')}:${horaEntrada.minute.toString().padLeft(2, '0')}",
                                      "horaSalida":
                                          "${horaSalida.hour.toString().padLeft(2, '0')}:${horaSalida.minute.toString().padLeft(2, '0')}",
                                      "tolerancia": tolerancia,
                                      "roles": roles,
                                    },
                                  );
                                  if (response.statusCode == 200) {
                                    final data = jsonDecode(response.body);
                                    aplicados = data['actualizados'] ?? 0;
                                  }
                                } catch (e) {
                                  // continuar con el siguiente día
                                }
                              }

                              setSheetState(() => isApplying = false);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _showSuccess(
                                  "Horario aplicado a $aplicados usuario(s)");
                              if (_usuarioSeleccionado != null) {
                                _fetchHorarios(
                                    _usuarioSeleccionado['id_usuario']);
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Calendario de días no laborables ──
  void _mostrarCalendario() {
    String tipoSeleccionado = 'GENERAL';
    dynamic usuarioCalendario;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Set<DateTime> diasMarcados = _diasNoLaborables
              .where((d) {
                if (tipoSeleccionado == 'GENERAL') {
                  return d['tipo'] == 'GENERAL';
                } else {
                  return d['tipo'] == 'GENERAL' ||
                      (d['tipo'] == 'USUARIO' &&
                          d['id_usuario'] ==
                              usuarioCalendario?['id_usuario']);
                }
              })
              .map((d) {
                final fecha = DateTime.parse(d['fecha']);
                return DateTime(fecha.year, fecha.month, fecha.day);
              })
              .toSet();

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Días no laborables",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Text(
                      "Toca un día para marcarlo o desmarcarlo como no laborable.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    const Text("Aplicar a:",
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text("Todos"),
                          selected: tipoSeleccionado == 'GENERAL',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (_) {
                            setSheetState(() {
                              tipoSeleccionado = 'GENERAL';
                              usuarioCalendario = null;
                            });
                            _fetchDiasNoLaborables()
                                .then((_) => setSheetState(() {}));
                          },
                        ),
                        ChoiceChip(
                          label: const Text("Usuario específico"),
                          selected: tipoSeleccionado == 'USUARIO',
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (_) => setSheetState(
                              () => tipoSeleccionado = 'USUARIO'),
                        ),
                      ],
                    ),

                    if (tipoSeleccionado == 'USUARIO') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<dynamic>(
                        value: usuarioCalendario,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Seleccionar usuario",
                          border: OutlineInputBorder(),
                          isDense: true,
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
                        onChanged: (v) {
                          setSheetState(() => usuarioCalendario = v);
                          if (v != null) {
                            _fetchDiasNoLaborables(
                                    idUsuario: v['id_usuario'])
                                .then((_) => setSheetState(() {}));
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 16),

                    if (tipoSeleccionado == 'GENERAL' ||
                        (tipoSeleccionado == 'USUARIO' &&
                            usuarioCalendario != null))
                      TableCalendar(
                        firstDay: DateTime(2025),
                        lastDay: DateTime(2030),
                        focusedDay: _focusedDay,
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Mes',
                        },
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.indigo.shade200,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        selectedDayPredicate: (day) {
                          final d =
                              DateTime(day.year, day.month, day.day);
                          return diasMarcados.contains(d);
                        },
                        onDaySelected:
                            (selectedDay, focusedDay) async {
                          setState(() => _focusedDay = focusedDay);
                          setSheetState(() => _focusedDay = focusedDay);

                          final fecha = DateTime(selectedDay.year,
                              selectedDay.month, selectedDay.day);
                          final fechaStr =
                              "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";

                          final esGeneral = _diasNoLaborables.any((d) {
                            final df = DateTime.parse(d['fecha']);
                            final dfc =
                                DateTime(df.year, df.month, df.day);
                            return dfc == fecha && d['tipo'] == 'GENERAL';
                          });

                          if (tipoSeleccionado == 'USUARIO' && esGeneral) {
                            _showError(
                                "Este día es no laborable para todos. Cámbialo desde el modo 'Todos'.");
                            return;
                          }

                          final existente = _diasNoLaborables.where((d) {
                            final df = DateTime.parse(d['fecha']);
                            final dfc =
                                DateTime(df.year, df.month, df.day);
                            if (tipoSeleccionado == 'GENERAL') {
                              return dfc == fecha && d['tipo'] == 'GENERAL';
                            } else {
                              return dfc == fecha &&
                                  d['tipo'] == 'USUARIO' &&
                                  d['id_usuario'] ==
                                      usuarioCalendario['id_usuario'];
                            }
                          }).toList();

                          if (existente.isNotEmpty) {
                            final response = await ApiService.delete(
                                "/dias-no-laborables/${existente[0]['id']}");
                            if (response.statusCode == 200) {
                              await _fetchDiasNoLaborables(
                                idUsuario: tipoSeleccionado == 'USUARIO'
                                    ? usuarioCalendario['id_usuario']
                                    : null,
                              );
                              setSheetState(() {});
                              _showSuccess("Día restaurado como laborable");
                            }
                          } else {
                            final body = {
                              "fecha": fechaStr,
                              "tipo": tipoSeleccionado,
                              if (tipoSeleccionado == 'USUARIO')
                                "idUsuario":
                                    usuarioCalendario['id_usuario'],
                            };
                            final response = await ApiService.post(
                                "/dias-no-laborables", body);
                            if (response.statusCode == 201) {
                              await _fetchDiasNoLaborables(
                                idUsuario: tipoSeleccionado == 'USUARIO'
                                    ? usuarioCalendario['id_usuario']
                                    : null,
                              );
                              setSheetState(() {});
                              _showSuccess(
                                  "Día marcado como no laborable");
                            } else {
                              final data = jsonDecode(response.body);
                              _showError(data["error"] ?? "Error");
                            }
                          }
                        },
                        onPageChanged: (focusedDay) {
                          setState(() => _focusedDay = focusedDay);
                          setSheetState(() => _focusedDay = focusedDay);
                        },
                      )
                    else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            "Selecciona un usuario para ver su calendario",
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text("No laborable",
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 16),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade200,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text("Hoy", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: "Horario general",
            onPressed: _mostrarHorarioGeneral,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Días no laborables",
            onPressed: _mostrarCalendario,
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
                                              suffixIcon: Icon(
                                                  Icons.access_time),
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
                                              suffixIcon: Icon(
                                                  Icons.access_time),
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