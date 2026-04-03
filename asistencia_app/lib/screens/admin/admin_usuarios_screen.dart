import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  List<dynamic> _usuarios = [];
  List<dynamic> _filtrados = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsuarios();
    _searchController.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get("/usuarios");
      if (response.statusCode == 200) {
        setState(() {
          _usuarios = jsonDecode(response.body);
          _filtrados = _usuarios;
        });
      }
    } catch (e) {
      _showError("Error de conexión");
    }
    setState(() => _isLoading = false);
  }

  void _filtrar() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtrados = _usuarios.where((u) {
        final correo = u['correo'].toString().toLowerCase();
        return correo.contains(query);
      }).toList();
    });
  }

  Future<void> _cambiarEstado(int id) async {
    try {
      await ApiService.patch("/usuarios/$id/estado");
      _fetchUsuarios();
    } catch (e) {
      _showError("Error de conexión");
    }
  }

  Future<void> _eliminar(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Eliminar usuario"),
        content: const Text(
            "¿Estás seguro de que deseas eliminar este usuario? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.delete("/usuarios/$id");
      if (response.statusCode == 200) {
        _showSuccess("Usuario eliminado correctamente");
        _fetchUsuarios();
      } else {
        _showError("Error al eliminar usuario");
      }
    } catch (e) {
      _showError("Error de conexión");
    }
  }

  Future<void> _mostrarFormulario({dynamic usuario}) async {
    final correoController =
        TextEditingController(text: usuario?['correo'] ?? '');
    final passwordController = TextEditingController();
    final nuevaPasswordController = TextEditingController();
    final nombresController =
        TextEditingController(text: usuario?['nombres'] ?? '');
    final apellidosController =
        TextEditingController(text: usuario?['apellidos'] ?? '');
    final documentoController =
        TextEditingController(text: usuario?['documento'] ?? '');
    final telefonoController =
        TextEditingController(text: usuario?['telefono'] ?? '');
    String rolSeleccionado = usuario?['rol'] ?? 'DOCENTE';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(usuario == null ? "Crear usuario" : "Editar usuario"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombresController,
                  decoration: const InputDecoration(labelText: "Nombres"),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Requerido" : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: apellidosController,
                  decoration: const InputDecoration(labelText: "Apellidos"),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Requerido" : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: documentoController,
                  decoration: const InputDecoration(labelText: "Documento"),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Requerido" : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: telefonoController,
                  decoration:
                      const InputDecoration(labelText: "Teléfono (opcional)"),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: correoController,
                  decoration:
                      const InputDecoration(labelText: "Correo electrónico"),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Requerido" : null,
                ),
                const SizedBox(height: 8),

                if (usuario == null)
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Contraseña"),
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Requerido";
                      if (v.length < 6) return "Debe tener al menos 6 caracteres";
                      return null;
                    },
                  ),

                if (usuario != null) ...[
                  TextFormField(
                    controller: nuevaPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Nueva contraseña (opcional)",
                      hintText: "Dejar vacío para no cambiar",
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 6) {
                        return "Debe tener al menos 6 caracteres";
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: rolSeleccionado,
                  decoration: const InputDecoration(labelText: "Rol"),
                  items: const [
                    DropdownMenuItem(
                        value: 'DOCENTE', child: Text("Docente")),
                    DropdownMenuItem(
                        value: 'ADMINISTRATIVO',
                        child: Text("Administrativo")),
                    DropdownMenuItem(
                        value: 'ADMIN', child: Text("Administrador")),
                  ],
                  onChanged: (v) => rolSeleccionado = v!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);

              if (usuario == null) {
                await _crearUsuario(
                  correo: correoController.text,
                  password: passwordController.text,
                  rol: rolSeleccionado,
                  nombres: nombresController.text,
                  apellidos: apellidosController.text,
                  documento: documentoController.text,
                  telefono: telefonoController.text,
                );
              } else {
                await _editarUsuario(
                  id: usuario['id_usuario'],
                  correo: correoController.text,
                  rol: rolSeleccionado,
                  nuevaPassword: nuevaPasswordController.text.isEmpty
                      ? null
                      : nuevaPasswordController.text,
                );
              }
            },
            child: Text(usuario == null ? "Crear" : "Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _crearUsuario({
    required String correo,
    required String password,
    required String rol,
    required String nombres,
    required String apellidos,
    required String documento,
    required String telefono,
  }) async {
    try {
      final response = await ApiService.post(
        "/usuarios",
        {
          "correo": correo,
          "password": password,
          "rol": rol,
          "nombres": nombres,
          "apellidos": apellidos,
          "documento": documento,
          "telefono": telefono,
          "horarios": List.generate(5, (i) => {
                "dia_semana": i + 1,
                "hora_entrada": "07:00",
                "hora_salida": "13:00",
                "tolerancia_minutos": 10,
              }),
        },
      );

      if (response.statusCode == 201) {
        _showSuccess("Usuario creado correctamente");
        _fetchUsuarios();
      } else {
        final data = jsonDecode(response.body);
        _showError(data["error"] ?? "Error al crear usuario");
      }
    } catch (e) {
      _showError("Error de conexión");
    }
  }

  Future<void> _editarUsuario({
    required int id,
    required String correo,
    required String rol,
    String? nuevaPassword,
  }) async {
    try {
      final response = await ApiService.put(
        "/usuarios/$id",
        {
          "correo": correo,
          "rol": rol,
        },
      );

      if (nuevaPassword != null && response.statusCode == 200) {
        final passResponse = await ApiService.put(
          "/usuarios/$id/password",
          {"password": nuevaPassword},
        );

        if (passResponse.statusCode != 200) {
          _showError("Error al actualizar contraseña");
          return;
        }
      }

      if (response.statusCode == 200) {
        _showSuccess("Usuario actualizado correctamente");
        _fetchUsuarios();
      } else {
        final data = jsonDecode(response.body);
        _showError(data["error"] ?? "Error al actualizar");
      }
    } catch (e) {
      _showError("Error de conexión");
    }
  }

  Future<dynamic> _fetchDetalle(int id) async {
    try {
      final response = await ApiService.get("/usuarios/$id");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      _showError("Error de conexión");
    }
    return null;
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
        title: const Text("Gestión de Usuarios"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsuarios,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text("Nuevo usuario"),
        onPressed: () => _mostrarFormulario(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Buscar por correo...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtrados.isEmpty
                      ? const Center(child: Text("No hay usuarios"))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filtrados.length,
                          itemBuilder: (context, index) {
                            final u = _filtrados[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: u['estado'] == true
                                      ? Colors.indigo.shade100
                                      : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.person,
                                    color: u['estado'] == true
                                        ? Colors.indigo
                                        : Colors.grey,
                                  ),
                                ),
                                title: Text(u['correo']),
                                subtitle: Row(
                                  children: [
                                    Chip(
                                      label: Text(
                                        u['rol'],
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(
                                        u['estado'] == true
                                            ? "Activo"
                                            : "Inactivo",
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: u['estado'] == true
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'editar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit),
                                          SizedBox(width: 8),
                                          Text("Editar"),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'estado',
                                      child: Row(
                                        children: [
                                          Icon(u['estado'] == true
                                              ? Icons.block
                                              : Icons.check_circle),
                                          const SizedBox(width: 8),
                                          Text(u['estado'] == true
                                              ? "Desactivar"
                                              : "Activar"),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'eliminar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              color: Colors.red),
                                          SizedBox(width: 8),
                                          Text("Eliminar",
                                              style: TextStyle(
                                                  color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) async {
                                    if (value == 'editar') {
                                      final detalle =
                                          await _fetchDetalle(u['id_usuario']);
                                      if (detalle != null) {
                                        _mostrarFormulario(usuario: detalle);
                                      }
                                    } else if (value == 'estado') {
                                      _cambiarEstado(u['id_usuario']);
                                    } else if (value == 'eliminar') {
                                      _eliminar(u['id_usuario']);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}