// dart:io TCP implementation of Transport.
// Sets TCP_NODELAY after connect for low-latency small writes.

import 'dart:async';
import 'dart:io';

import 'transport.dart';

class TcpTransport implements Transport {
  Socket? _socket;
  final StreamController<void> _disconnected = StreamController<void>.broadcast();
  String? _lastError;
  bool _closed = false;

  @override
  String? get lastError => _lastError;

  @override
  Stream<void> get disconnected => _disconnected.stream;

  @override
  Future<void> connect({required String host, required int port}) async {
    if (_socket != null) return;
    _lastError = null;
    try {
      final sock = await Socket.connect(host, port,
          timeout: const Duration(seconds: 5));
      sock.setOption(SocketOption.tcpNoDelay, true);
      _socket = sock;
      _closed = false;
      sock.done.then((_) {
        if (!_closed) {
          _disconnected.add(null);
        }
      }).catchError((Object e) {
        if (!_closed) {
          _lastError = e.toString();
          _disconnected.add(null);
        }
      });
    } on Object catch (e) {
      _lastError = e.toString();
      _socket = null;
      _disconnected.add(null);
      rethrow;
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    final s = _socket;
    if (s == null) {
      throw StateError('transport not connected');
    }
    s.add(bytes);
    // Flush promptly — coalesce at the codec layer, not the socket layer.
    await s.flush();
  }

  @override
  Future<void> close() async {
    final s = _socket;
    if (s == null) return;
    _closed = true;
    _socket = null;
    try {
      s.destroy();
    } on Object {
      // Best-effort: a double-close or already-closed socket is fine.
    }
    await _disconnected.close();
  }
}
