import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AdminQrScreen extends StatefulWidget {
  const AdminQrScreen({super.key});

  @override
  State<AdminQrScreen> createState() => _AdminQrScreenState();
}

class _AdminQrScreenState extends State<AdminQrScreen> {
  String? _codigo;
  DateTime? _expiracion;
  bool _isLoading = false;
  bool _fetchingQR = false;

  Timer? _countdownTimer;
  Duration _tiempoRestante = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchQRActivo();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Obtener QR activo o generar uno nuevo si no existe
  Future<void> _fetchQRActivo() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get("/qr/activo");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _codigo = data["codigo"];
          _expiracion = DateTime.parse(data["fecha_expiracion"]);
          _isLoading = false;
        });

        _iniciarContador();
      } else if (response.statusCode == 404) {
        await _generarNuevoQR();
      } else {
        setState(() => _isLoading = false);
        _showError("Error inesperado");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError("Error de conexión");
    }
  }

  // Generar un nuevo QR (si no hay activo o por botón de refrescar)
  Future<void> _generarNuevoQR() async {
    try {
      final response = await ApiService.post("/qr/generar", {});

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _codigo = data["codigo"];
          _expiracion = DateTime.parse(data["fecha_expiracion"]);
          _isLoading = false;
        });

        _iniciarContador();
      } else {
        setState(() => _isLoading = false);
        _showError("Error al generar QR");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError("Error de conexión");
    }
  }

  // Contador para mostrar tiempo restante del QR activo
  void _iniciarContador() {
    _countdownTimer?.cancel();

    _actualizarTiempoRestante();

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      _actualizarTiempoRestante();
    });
  }

  void _actualizarTiempoRestante() {
    if (_expiracion == null) return;

    final ahoraUtc = DateTime.now().toUtc();
    final restante = _expiracion!.toUtc().difference(ahoraUtc);

    if (restante.isNegative) {
      _countdownTimer?.cancel();

      setState(() {
        _tiempoRestante = Duration.zero;
        _codigo = null;
      });

      if (!_isLoading && !_fetchingQR) {
        _fetchingQR = true;
        _fetchQRActivo().whenComplete(() {
          _fetchingQR = false;
        });
      }
    } else {
      setState(() => _tiempoRestante = restante);
    }
  }

  // Formato contador y color según tiempo restante
  String get _tiempoFormateado {
    final minutos =
        _tiempoRestante.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos =
        _tiempoRestante.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutos:$segundos";
  }

  Color get _colorContador {
    if (_tiempoRestante.inMinutes >= 10) return Colors.green;
    if (_tiempoRestante.inMinutes >= 5) return Colors.orange;
    return Colors.red;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // UI del QR activo
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR de Asistencia"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generarNuevoQR,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SOLO DEPENDE DE QUE EXISTA CÓDIGO
                    if (_codigo != null) ...[
                      const Text(
                        "QR Activo",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      QrImageView(
                        data: _codigo!,
                        version: QrVersions.auto,
                        size: 260,
                      ),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: _colorContador.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _colorContador),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer, color: _colorContador),
                            const SizedBox(width: 8),
                            Text(
                              "Expira en $_tiempoFormateado",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _colorContador,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.qr_code,
                          size: 120, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "No hay QR activo",
                        style: TextStyle(
                            color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}