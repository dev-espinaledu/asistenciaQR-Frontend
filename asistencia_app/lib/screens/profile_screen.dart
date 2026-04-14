import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _estadisticas;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _mostrarCambioPassword = false;
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;

  final _formKey = GlobalKey<FormState>();
  final _passwordActualController = TextEditingController();
  final _passwordNuevaController = TextEditingController();
  final _passwordConfirmarController = TextEditingController();

  bool _obscureActual = true;
  bool _obscureNueva = true;
  bool _obscureConfirmar = true;

  @override
  void initState() {
    super.initState();
    _fetchPerfil();
    _fetchEstadisticas();
  }

  @override
  void dispose() {
    _passwordActualController.dispose();
    _passwordNuevaController.dispose();
    _passwordConfirmarController.dispose();
    super.dispose();
  }

  Future<void> _fetchPerfil() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get("/usuarios/perfil");
      if (response.statusCode == 200) {
        setState(() => _perfil = jsonDecode(response.body));
      }
    } catch (e) {
      _showError("Error al cargar perfil");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchEstadisticas() async {
    try {
      final response = await ApiService.get(
        "/asistencia/estadisticas?mes=$_mesSeleccionado&anio=$_anioSeleccionado",
      );
      if (response.statusCode == 200) {
        setState(() => _estadisticas = jsonDecode(response.body));
      }
    } catch (e) {
      // silencioso
    }
  }

  Future<void> _cambiarPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final response = await ApiService.put(
        "/usuarios/mi-password",
        {
          "passwordActual": _passwordActualController.text,
          "passwordNueva": _passwordNuevaController.text,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccess("Contraseña actualizada correctamente");
        _passwordActualController.clear();
        _passwordNuevaController.clear();
        _passwordConfirmarController.clear();
        setState(() => _mostrarCambioPassword = false);
      } else {
        _showError(data["error"] ?? "Error al actualizar contraseña");
      }
    } catch (e) {
      _showError("Error de conexión");
    }

    setState(() => _isSaving = false);
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
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
        title: const Text("Mi perfil"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchPerfil();
              _fetchEstadisticas();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Tarjeta de información
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.indigo.shade100,
                          child: Text(
                            _perfil?['nombres']
                                    ?.toString()
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                '?',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "${_perfil?['nombres'] ?? ''} ${_perfil?['apellidos'] ?? ''}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _perfil?['correo'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _perfil?['rol'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.indigo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Tarjeta estadísticas
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bar_chart, color: Colors.indigo),
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
                              icon: const Icon(Icons.calendar_month, size: 16),
                              label: Text(
                                "${_nombreMes(_mesSeleccionado)} $_anioSeleccionado",
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: _mostrarSelectorMes,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_estadisticas == null)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                (_estadisticas!['sinSalida'] ?? 0) as int,
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

                const SizedBox(height: 24),

                // Tarjeta cambiar contraseña
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      // Botón que expande/colapsa
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade50,
                          child: const Icon(Icons.lock_outline,
                              color: Colors.indigo),
                        ),
                        title: const Text(
                          "Cambiar contraseña",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                            "Actualiza tu contraseña de acceso"),
                        trailing: Icon(
                          _mostrarCambioPassword
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.indigo,
                        ),
                        onTap: () => setState(() =>
                            _mostrarCambioPassword = !_mostrarCambioPassword),
                      ),

                      // Formulario expandible
                      if (_mostrarCambioPassword) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Contraseña actual
                                TextFormField(
                                  controller: _passwordActualController,
                                  obscureText: _obscureActual,
                                  decoration: InputDecoration(
                                    labelText: "Contraseña actual",
                                    prefixIcon:
                                        const Icon(Icons.lock_outline),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureActual
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined),
                                      onPressed: () => setState(() =>
                                          _obscureActual = !_obscureActual),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return "Requerido";
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 12),

                                // Nueva contraseña
                                TextFormField(
                                  controller: _passwordNuevaController,
                                  obscureText: _obscureNueva,
                                  decoration: InputDecoration(
                                    labelText: "Nueva contraseña",
                                    prefixIcon:
                                        const Icon(Icons.lock_reset),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureNueva
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined),
                                      onPressed: () => setState(() =>
                                          _obscureNueva = !_obscureNueva),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return "Requerido";
                                    }
                                    if (v.length < 6) {
                                      return "Debe tener al menos 6 caracteres";
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 12),

                                // Confirmar contraseña
                                TextFormField(
                                  controller: _passwordConfirmarController,
                                  obscureText: _obscureConfirmar,
                                  decoration: InputDecoration(
                                    labelText: "Confirmar nueva contraseña",
                                    prefixIcon:
                                        const Icon(Icons.lock_reset),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureConfirmar
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined),
                                      onPressed: () => setState(() =>
                                          _obscureConfirmar =
                                              !_obscureConfirmar),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return "Requerido";
                                    }
                                    if (v != _passwordNuevaController.text) {
                                      return "Las contraseñas no coinciden";
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 20),

                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: FilledButton.icon(
                                    icon: const Icon(Icons.save),
                                    label: _isSaving
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text("Actualizar contraseña"),
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed:
                                        _isSaving ? null : _cambiarPassword,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
    );
  }
}