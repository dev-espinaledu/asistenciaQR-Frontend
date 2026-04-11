import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _recordarme = false;

  @override
  void initState() {
    super.initState();
    _cargarCorreoGuardado();
  }

  // Cargar correo guardado al iniciar
  Future<void> _cargarCorreoGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final correoGuardado = prefs.getString('ultimo_correo') ?? '';
    final recordarme = prefs.getBool('recordarme') ?? false;

    if (recordarme && correoGuardado.isNotEmpty) {
      setState(() {
        _emailController.text = correoGuardado;
        _recordarme = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${AppConfig.baseUrl}/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "correo": _emailController.text.trim(),
          "password": _passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data["token"];
        await SecureStorage.saveToken(token);

        // Guardar o limpiar correo según "Recordarme"
        final prefs = await SharedPreferences.getInstance();
        if (_recordarme) {
          await prefs.setString('ultimo_correo', _emailController.text.trim());
          await prefs.setBool('recordarme', true);
        } else {
          await prefs.remove('ultimo_correo');
          await prefs.setBool('recordarme', false);
        }

        final parts = token.split('.');
        final payload = utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])),
        );
        final payloadData = jsonDecode(payload);
        final rol = payloadData["rol"];
        await SecureStorage.saveRol(rol);

        if (!mounted) return;

        if (rol == "ADMIN" || rol == "SUB_ADMIN") {
          Navigator.pushReplacementNamed(context, "/admin");
        } else if (rol == "PORTERO") {
          Navigator.pushReplacementNamed(context, "/portero");
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        _showError(data["error"] ?? "Error de autenticación");
      }
    } catch (e) {
      _showError("Error de conexión");
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF5C6BC0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Parte superior con logo ──
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo_rcsfa.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "RCSFA",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Sistema de Asistencia de Empleados",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tarjeta del formulario ──
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Iniciar sesión",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ingresa tus credenciales para continuar",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Campo correo ──
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "Correo electrónico",
                              hintText: "usuario@realcsfa.edu.co",
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFF3949AB),
                              ),
                              // Botón para limpiar el correo
                              suffixIcon: _emailController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.grey, size: 18),
                                      onPressed: () {
                                        _emailController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFF3949AB), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) => v == null || v.isEmpty
                                ? "Ingrese su correo"
                                : null,
                          ),

                          const SizedBox(height: 16),

                          // ── Campo contraseña ──
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF3949AB),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFF3949AB), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? "Ingrese su contraseña"
                                : null,
                          ),

                          const SizedBox(height: 12),

                          // Checkbox Recordarme
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _recordarme,
                                  activeColor: const Color(0xFF3949AB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _recordarme = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _recordarme = !_recordarme),
                                child: Text(
                                  "Recordarme",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── Botón login ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF3949AB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _isLoading ? null : _login,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      "Iniciar sesión",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          // ── Pie ──
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Fundación Real Colegio San Francisco de Asís",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  "Creado con ❤️ por Eduardo Espinal",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}