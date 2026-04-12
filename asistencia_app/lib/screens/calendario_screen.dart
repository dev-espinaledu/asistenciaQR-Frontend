import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  List<dynamic> _diasNoLaborables = [];
  DateTime _focusedDay = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDiasNoLaborables();
  }

  Future<void> _fetchDiasNoLaborables() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get("/dias-no-laborables");
      if (response.statusCode == 200) {
        setState(() => _diasNoLaborables = jsonDecode(response.body));
      }
    } catch (e) {
      // silencioso
    }
    setState(() => _isLoading = false);
  }

  Set<DateTime> get _diasMarcados {
    return _diasNoLaborables.map((d) {
      final fecha = DateTime.parse(d['fecha']);
      return DateTime(fecha.year, fecha.month, fecha.day);
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Días no laborables"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDiasNoLaborables,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Info ──
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Los días marcados en rojo son días no laborables. No se registra asistencia esos días.",
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Calendario ──
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar(
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
                      // Solo lectura — no permite seleccionar
                      selectedDayPredicate: (day) {
                        final d = DateTime(day.year, day.month, day.day);
                        return _diasMarcados.contains(d);
                      },
                      onDaySelected: null, // deshabilitar selección
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Lista de días no laborables ──
                if (_diasNoLaborables.isNotEmpty) ...[
                  const Text(
                    "Días marcados",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._diasNoLaborables.map((d) {
                    final fecha = DateTime.parse(d['fecha']);
                    final fechaStr =
                        "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
                    final esGeneral = d['tipo'] == 'GENERAL';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade50,
                          child: const Icon(Icons.event_busy,
                              color: Colors.red, size: 20),
                        ),
                        title: Text(fechaStr),
                        subtitle: Text(
                          esGeneral ? "Todos los usuarios" : "Usuario específico",
                          style: TextStyle(
                            fontSize: 12,
                            color: esGeneral
                                ? Colors.indigo
                                : Colors.orange,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: esGeneral
                                ? Colors.indigo.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            esGeneral ? "General" : "Personal",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: esGeneral
                                  ? Colors.indigo
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ] else
                  const Center(
                    child: Text(
                      "No hay días no laborables registrados",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
    );
  }
}