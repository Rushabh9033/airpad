import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/connection_controller.dart';
import 'scan_qr_page.dart';

class ConnectionPage extends StatefulWidget {
  final ConnectionController controller;
  const ConnectionPage({super.key, required this.controller});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  static const String _prefHost = 'airpad.lastHost';
  static const String _prefPort = 'airpad.lastPort';
  static const int defaultPort = 9876;

  final TextEditingController _hostCtrl = TextEditingController();
  final TextEditingController _portCtrl = TextEditingController(text: '$defaultPort');
  final FocusNode _hostFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final h = p.getString(_prefHost);
    final pt = p.getInt(_prefPort);
    if (!mounted) return;
    if (h != null && h.isNotEmpty) _hostCtrl.text = h;
    if (pt != null) _portCtrl.text = '$pt';
  }

  Future<void> _savePrefs(String host, int port) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefHost, host);
    await p.setInt(_prefPort, port);
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _hostFocus.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    // Dismiss keyboard first so it doesn't swallow the button area.
    FocusScope.of(context).unfocus();
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? defaultPort;
    if (host.isEmpty) {
      _hostFocus.requestFocus();
      if (mounted) setState(() {});
      return;
    }
    await _savePrefs(host, port);
    await widget.controller.connect(host, port);
    if (!mounted) return;
    if (widget.controller.status.value == ConnectionStatus.connected) {
      context.go('/trackpad');
    }
  }

  Future<void> _scanQr() async {
    FocusScope.of(context).unfocus();
    final r = await context.push<ScanResult>('/scan');
    if (r == null || !mounted) return;
    setState(() {
      _hostCtrl.text = r.host;
      _portCtrl.text = '${r.port}';
    });
    // Auto-trigger connect with the scanned values.
    await _connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        title: const Text('Airpad'),
        actions: [
          IconButton(
            tooltip: 'Scan host QR',
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: _scanQr,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Observer(
            builder: (_) {
              final status = widget.controller.status.value;
              final error = widget.controller.lastError.value;
              final hostEmpty = _hostCtrl.text.trim().isEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Connect to your computer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the IP address shown by the airpad host app. Default port is 9876.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _Field(
                    label: 'Host IP',
                    controller: _hostCtrl,
                    focusNode: _hostFocus,
                    keyboardType: TextInputType.number,
                    hint: 'e.g. 192.168.1.42',
                    onChanged: (_) {
                      // Rebuild so the inline hint shows/hides.
                      setState(() {});
                    },
                  ),
                  if (hostEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Host IP is required.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _Field(
                    label: 'Port',
                    controller: _portCtrl,
                    keyboardType: TextInputType.number,
                    hint: '9876',
                  ),
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusPill(
                      status: status,
                      error: error,
                      fallbackError: error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: status == ConnectionStatus.connecting
                        ? null
                        : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D7CFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: status == ConnectionStatus.connecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Connect',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                  if (status == ConnectionStatus.error && error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1414),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error,
                        style: const TextStyle(
                            color: Color(0xFFFF7A7A), fontSize: 13),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.controller,
    required this.keyboardType,
    required this.hint,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: onChanged,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: const Color(0xFF3D7CFF),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: const Color(0xFF1A1A1F),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ConnectionStatus status;
  final String error;
  final String fallbackError;
  const _StatusPill({
    required this.status,
    required this.error,
    required this.fallbackError,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConnectionStatus.connected => ('Connected', const Color(0xFF6CE38C)),
      ConnectionStatus.connecting => ('Connecting...', const Color(0xFFFFC857)),
      _ => (
          // disconnected + error both surface the last error string so
          // you actually see *why* the connect failed.
          error.isNotEmpty
              ? error
              : fallbackError.isNotEmpty
                  ? fallbackError
                  : 'Disconnected',
          const Color(0xFFFF7A7A),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
