// QR scan page. Uses mobile_scanner (already in pubspec). Parses
// airpad://<ip>:<port>/<token> payloads from the host and pops back to
// the connection page with the host/port prefilled. The connection
// page then auto-triggers _connect() once it sees the new values.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanResult {
  final String host;
  final int port;
  final String token;
  const ScanResult({
    required this.host,
    required this.port,
    required this.token,
  });
}

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  String? _error;

  ScanResult? _parse(String raw) {
    // Expected: airpad://192.168.1.42:9876/X7K9P2
    if (!raw.startsWith('airpad://')) return null;
    final body = raw.substring('airpad://'.length);
    final slash = body.indexOf('/');
    if (slash < 0) return null;
    final hostPort = body.substring(0, slash);
    final token = body.substring(slash + 1);
    final colon = hostPort.lastIndexOf(':');
    if (colon < 0) return null;
    final host = hostPort.substring(0, colon);
    final portStr = hostPort.substring(colon + 1);
    final port = int.tryParse(portStr);
    if (port == null || host.isEmpty) return null;
    return ScanResult(host: host, port: port, token: token);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      final r = _parse(raw);
      if (r == null) {
        setState(() => _error = 'Not an airpad QR: $raw');
        continue;
      }
      _handled = true;
      _controller.stop();
      context.pop(r);
      return;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        title: const Text('Scan host QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error ??
                    'Point the camera at the QR code on the airpad host.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
