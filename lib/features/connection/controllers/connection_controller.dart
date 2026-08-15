// Connection controller. MobX observables; no codegen required because the
// store is tiny. We keep the dependency on mobx/flutter_mobx in pubspec as
// specified, but we hand-write the Observable fields here to avoid spinning
// up build_runner just for two fields.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';

import '../../../core/protocol/codec.dart';
import '../../../core/protocol/messages.dart';
import '../../../core/transport/transport.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionController {
  final Transport transport;
  final String clientName;
  final int Function() screenW;
  final int Function() screenH;
  final FrameCodec codec;

  ConnectionController({
    required this.transport,
    required this.clientName,
    required this.screenW,
    required this.screenH,
    FrameCodec? codec,
  }) : codec = codec ?? FrameCodec() {
    _statusDisposer = reaction((_) => status.value, (_) {});
  }

  late final ReactionDisposer _statusDisposer;
  StreamSubscription<void>? _disconnectSub;

  final Observable<ConnectionStatus> status =
      Observable<ConnectionStatus>(ConnectionStatus.disconnected);

  final Observable<String> lastError = Observable<String>('');

  Future<void> connect(String host, int port) async {
    debugPrint('[airpad] connect() called status=${status.value} host=$host port=$port');
    if (status.value == ConnectionStatus.connecting ||
        status.value == ConnectionStatus.connected) {
      debugPrint('[airpad] connect() early-return (busy)');
      return;
    }
    runInAction(() {
      status.value = ConnectionStatus.connecting;
      lastError.value = '';
    });
    try {
      debugPrint('[airpad] dialing TCP...');
      await transport.connect(host: host, port: port);
      debugPrint('[airpad] TCP ok, sending HELLO');
      await _sendHello();
      await _disconnectSub?.cancel();
      runInAction(() {
        status.value = ConnectionStatus.connected;
      });
      _disconnectSub = transport.disconnected.listen((_) {
        runInAction(() {
          status.value = ConnectionStatus.error;
          lastError.value = transport.lastError ?? 'disconnected';
        });
      });
    } on Object catch (e) {
      debugPrint('[airpad] connect failed: $e');
      runInAction(() {
        status.value = ConnectionStatus.error;
        lastError.value = _humanize(e.toString());
      });
    }
  }

  Future<void> disconnect() async {
    await _disconnectSub?.cancel();
    _disconnectSub = null;
    await transport.close();
    runInAction(() {
      status.value = ConnectionStatus.disconnected;
    });
  }

  Future<void> _sendHello() async {
    final m = HelloMessage(clientName, screenW(), screenH());
    await transport.write(codec.wrap(encodeHello(m)));
  }

  String _humanize(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('refused') || r.contains('actively refused')) {
      return 'Connection refused. Is the airpad host running on this IP?';
    }
    if (r.contains('timed out') || r.contains('timeout')) {
      return 'Connection timed out. Phone and laptop must be on the same Wi-Fi.';
    }
    if (r.contains('unreachable') || r.contains('no route')) {
      return 'Host unreachable. Check the IP and that both devices are on the same network.';
    }
    if (r.contains('failed host lookup') || r.contains('socketexception')) {
      return 'Cannot reach host. Check the IP address.';
    }
    return 'Disconnected: $raw';
  }

  void dispose() {
    _statusDisposer();
    _disconnectSub?.cancel();
  }
}
