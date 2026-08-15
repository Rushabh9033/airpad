import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../connection/controllers/connection_controller.dart';
import '../../settings/pages/settings_page.dart';
import '../controllers/gesture_recognizer.dart';
import '../controllers/touch_sender.dart';
import '../widgets/trackpad_surface.dart';

class TrackpadPage extends StatefulWidget {
  final ConnectionController connection;
  final SettingsStore settings;
  const TrackpadPage({
    super.key,
    required this.connection,
    required this.settings,
  });

  @override
  State<TrackpadPage> createState() => _TrackpadPageState();
}

class _TrackpadPageState extends State<TrackpadPage> {
  late final TrackpadGestureRecognizer _recognizer;
  late final TouchSender _sender;
  TouchDebugStats _stats = const TouchDebugStats(
      x: 0, y: 0, fingers: 0, msSinceLastSend: -1);
  Timer? _statsTicker;

  @override
  void initState() {
    super.initState();
    _recognizer = TrackpadGestureRecognizer(
      sensitivity: () => widget.settings.sensitivity,
      scrollSpeed: () => widget.settings.scrollSpeed,
    );
    _sender = TouchSender(widget.connection.transport)..start();
    _statsTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statsTicker?.cancel();
    _sender.stop();
    _recognizer.reset();
    super.dispose();
  }

  Future<void> _disconnect() async {
    await widget.connection.disconnect();
    if (!mounted) return;
    context.go('/connection');
  }

  @override
  Widget build(BuildContext context) {
    final showDebug = kDebugMode && widget.settings.debugOverlay;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        title: const Text('Airpad'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            tooltip: 'Disconnect',
            icon: const Icon(Icons.link_off),
            onPressed: _disconnect,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: TrackpadSurface(
                recognizer: _recognizer,
                sender: _sender,
                onStats: (s) {
                  // Throttle UI updates to ~10 Hz; the sender already
                  // runs at 120 Hz internally.
                  _stats = s;
                },
              ),
            ),
            if (showDebug)
              Positioned(
                left: 12,
                bottom: 12,
                child: _DebugPanel(stats: _stats),
              ),
          ],
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  final TouchDebugStats stats;
  const _DebugPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF9EE493),
          fontSize: 11,
          fontFamily: 'monospace',
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('fingers: ${stats.fingers}'),
            Text('last send: ${stats.msSinceLastSend < 0 ? '-' : '${stats.msSinceLastSend}ms ago'}'),
          ],
        ),
      ),
    );
  }
}
