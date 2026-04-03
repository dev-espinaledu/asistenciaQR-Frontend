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
  bool _isLoading = true;
  bool _isSaving = false;

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
      } else {
        _showError(data["error"] ?? "Error al actualizar contraseña");
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
        title: const Text("Mi perfil"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Tarjeta de información ──
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

                // ── Tarjeta cambiar contraseña ──
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Cambiar contraseña",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Contraseña actual
                          TextFormField(
                            controller: _passwordActualController,
                            obscureText: _obscureActual,
                            decoration: InputDecoration(
                              labelText: "Contraseña actual",
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureActual
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                    () => _obscureActual = !_obscureActual),
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
                              prefixIcon: const Icon(Icons.lock_reset),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureNueva
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                    () => _obscureNueva = !_obscureNueva),
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
                              prefixIcon: const Icon(Icons.lock_reset),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmar
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() =>
                                    _obscureConfirmar = !_obscureConfirmar),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isSaving ? null : _cambiarPassword,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}