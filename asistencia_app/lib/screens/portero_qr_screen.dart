import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';

class PorteroQrScreen extends StatefulWidget {
  const PorteroQrScreen({super.key});

  @override
  State<PorteroQrScreen> createState() => _PorteroQrScreenState();
}

class _PorteroQrScreenState extends State<PorteroQrScreen> {
  String? _codigo;
  DateTime? _expiracion;
  bool _isLoading = true;
  bool _fetchingQR = false;
  Timer? _countdownTimer;
  Duration _tiempoRestante = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fetchQRActivo();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _fetchQRActivo() async {
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
        setState(() => _isLoading = false);
        await Future.delayed(const Duration(seconds: 30));
        if (mounted) _fetchQRActivo();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _iniciarContador() {
    _countdownTimer?.cancel();
    _actualizarTiempoRestante();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _actualizarTiempoRestante();
    });
  }

  void _actualizarTiempoRestante() {
    if (_expiracion == null) return;
    final restante = _expiracion!.toUtc().difference(DateTime.now().toUtc());
    if (restante.isNegative) {
      _countdownTimer?.cancel();
      setState(() {
        _tiempoRestante = Duration.zero;
        _codigo = null;
      });
      if (!_fetchingQR) {
        _fetchingQR = true;
        _fetchQRActivo().whenComplete(() => _fetchingQR = false);
      }
    } else {
      setState(() => _tiempoRestante = restante);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text("QR de Asistencia"),
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : _codigo == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code,
                            size: 80,
                            color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          "Esperando QR activo...",
                          style:
                              TextStyle(color: Colors.white60, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Se actualizará automáticamente",
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Escanea para registrar asistencia",
                          style:
                              TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: _codigo!,
                            version: QrVersions.auto,
                            size: 260,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            color: _colorContador.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _colorContador.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer,
                                  color: _colorContador, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                "Expira en $_tiempoFormateado",
                                style: TextStyle(
                                  color: _colorContador,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}