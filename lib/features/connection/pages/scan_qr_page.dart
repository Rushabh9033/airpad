// QR scan page. Uses mobile_scanner (already in pubspec). Parses
// airpad://<ip>:<port>/<token> payloads from the host and pops back to
// the connection page with the host/port prefilled. The connection
// page then auto-triggers _connect() once it sees the new values.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String? _parseError;
  // null = checking, false = denied, true = granted
  bool? _permissionGranted;

  @override
  void initState() {
    super.initState();
    _ensurePermission();
  }

  Future<void> _ensurePermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) setState(() => _permissionGranted = true);
      await _controller.start();
      return;
    }
    if (status.isPermanentlyDenied) {
      if (mounted) setState(() => _permissionGranted = false);
      return;
    }
    final result = await Permission.camera.request();
    if (mounted) {
      setState(() => _permissionGranted = result.isGranted);
    }
    if (result.isGranted) {
      await _controller.start();
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

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
        setState(() => _parseError = 'Not an airpad QR: $raw');
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
      body: _permissionGranted == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _permissionGranted == false
              ? _PermissionDeniedView(onOpenSettings: _openSettings)
              : Stack(
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
                          _parseError ??
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

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _PermissionDeniedView({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Color(0xFFFF7A7A), size: 48),
          const SizedBox(height: 16),
          const Text(
            'Camera permission required',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Airpad needs camera access to scan the host QR code. Grant it from system settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onOpenSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3D7CFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
