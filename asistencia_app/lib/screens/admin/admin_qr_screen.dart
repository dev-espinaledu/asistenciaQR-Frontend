import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/secure_storage.dart';
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
  double _duracionMinutos = 1.0;
  String _rol = '';

  Timer? _countdownTimer;
  Duration _tiempoRestante = Duration.zero;

  @override
  void initState() {
    super.initState();
    _cargarRol();
    _fetchConfiguracion();
    _fetchQRActivo();
  }

  Future<void> _cargarRol() async {
    final rol = await SecureStorage.getRol();
    setState(() => _rol = rol ?? '');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchConfiguracion() async {
    try {
      final response = await ApiService.get("/qr/configuracion");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _duracionMinutos = (data['duracionMinutos'] as num).toDouble();
        });
      }
    } catch (e) {
      // silencioso
    }
  }

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
        // Solo ADMIN puede generar, SUB_ADMIN solo espera
        if (_rol == 'ADMIN') {
          await _generarNuevoQR();
        } else {
          setState(() => _isLoading = false);
        }
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

  void _iniciarContador() {
    _countdownTimer?.cancel();
    _actualizarTiempoRestante();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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

  void _mostrarConfiguracion() {
    double minutosTemp = _duracionMinutos.roundToDouble();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Configurar duración del QR",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Se aplicará a todos los QR generados a partir de ahora.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Duración",
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      "${minutosTemp.round()} minutos",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                          fontSize: 16),
                    ),
                  ],
                ),
                Slider(
                  value: minutosTemp,
                  min: 1,
                  max: 60,
                  divisions: 59,
                  activeColor: Colors.indigo,
                  label: "${minutosTemp.round()} min",
                  onChanged: (v) =>
                      setSheetState(() => minutosTemp = v.roundToDouble()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final response = await ApiService.put(
                        "/qr/configuracion",
                        {"duracionMinutos": minutosTemp.round()},
                      );
                      if (response.statusCode == 200) {
                        setState(() => _duracionMinutos = minutosTemp);
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context);
                        _showSuccess("Configuración guardada correctamente");
                      } else {
                        _showError("Error al guardar configuración");
                      }
                    },
                    child: const Text("Guardar"),
                  ),
                ),
              ],
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
        title: const Text("QR de Asistencia"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Solo ADMIN puede configurar y generar
          if (_rol == 'ADMIN') ...[
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: "Configurar duración",
              onPressed: _mostrarConfiguracion,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Generar nuevo QR",
              onPressed: _generarNuevoQR,
            ),
          ],
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
                    if (_codigo != null) ...[
                      const Text(
                        "Escanea para registrar asistencia",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                            horizontal: 24, vertical: 12),
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
                      // Mensaje diferente según rol
                      Text(
                        _rol == 'ADMIN'
                            ? "No hay QR activo"
                            : "No hay QR activo. Contacta al administrador.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}