import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  Future<void> _sendQr(String qrValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _controller.stop();

    try {
      final response = await ApiService.post(
        "/asistencia/marcar",
        {"codigo_qr": qrValue},
      );

      final data = jsonDecode(response.body);
      if (!mounted) return;

      final bool exito = response.statusCode == 200;
      final String mensaje = exito
          ? data["mensaje"] ?? "Asistencia registrada"
          : data["error"] ?? "Error";

      _showResult(mensaje, exito);
    } catch (e) {
      if (mounted) _showResult("Error de conexión", false);
    } finally {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        await _controller.start();
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showResult(String mensaje, bool exito) {
    IconData icono;
    Color color;
    String titulo;

    if (!exito) {
      icono = Icons.error_outline;
      color = Colors.red;
      titulo = "Error";
    } else if (mensaje.toLowerCase().contains('entrada')) {
      icono = Icons.login;
      color = Colors.green;
      titulo = "Entrada registrada";
    } else if (mensaje.toLowerCase().contains('salida')) {
      icono = Icons.logout;
      color = Colors.indigo;
      titulo = "Salida registrada";
    } else {
      icono = Icons.check_circle_outline;
      color = Colors.green;
      titulo = "Listo";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(color: color),
            const SizedBox(height: 8),
            const Text(
              "Redirigiendo al menú...",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.65;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Escanear QR"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Cámara ──
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isProcessing) return;
              final code = capture.barcodes.first.rawValue;
              if (code != null) _sendQr(code);
            },
          ),

          // Overlay oscuro con hueco central
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanSize,
                    height: scanSize,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Esquinas del scanner
          Center(
            child: SizedBox(
              width: scanSize,
              height: scanSize,
              child: CustomPaint(
                painter: _CornerPainter(
                  color: _isProcessing ? Colors.grey : Colors.white,
                ),
              ),
            ),
          ),

          // Texto instrucción
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _isProcessing
                      ? "Procesando..."
                      : "Apunta la cámara al código QR",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isProcessing ? Colors.grey : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (!_isProcessing)
                  const Text(
                    "El código se detecta automáticamente",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),

          // Overlay de procesando
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Pintor de esquinas
class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double len = 28.0;
    const double radius = 12.0;

    // Esquina superior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, radius)
        ..arcToPoint(Offset(radius, 0),
            radius: const Radius.circular(radius))
        ..lineTo(len, 0),
      paint,
    );

    // Esquina superior derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(Offset(size.width, radius),
            radius: const Radius.circular(radius))
        ..lineTo(size.width, len),
      paint,
    );

    // Esquina inferior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - radius)
        ..arcToPoint(Offset(radius, size.height),
            radius: const Radius.circular(radius), clockwise: false)
        ..lineTo(len, size.height),
      paint,
    );

    // Esquina inferior derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - radius, size.height)
        ..arcToPoint(Offset(size.width, size.height - radius),
            radius: const Radius.circular(radius), clockwise: false)
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) =>
      oldDelegate.color != color;
}