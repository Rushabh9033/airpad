// Connection controller. MobX observables; no codegen required because the
// store is tiny. We keep the dependency on mobx/flutter_mobx in pubspec as
// specified, but we hand-write the Observable fields here to avoid spinning
// up build_runner just for two fields.

import 'dart:async';

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
    if (status.value == ConnectionStatus.connecting ||
        status.value == ConnectionStatus.connected) {
      return;
    }
    status.value = ConnectionStatus.connecting;
    lastError.value = '';
    try {
      await transport.connect(host: host, port: port);
      await _sendHello();
      status.value = ConnectionStatus.connected;
      _disconnectSub = transport.disconnected.listen((_) {
        status.value = ConnectionStatus.error;
        lastError.value = transport.lastError ?? 'disconnected';
      });
    } on Object catch (e) {
      status.value = ConnectionStatus.error;
      lastError.value = _humanize(e.toString());
    }
  }

  Future<void> disconnect() async {
    await _disconnectSub?.cancel();
    _disconnectSub = null;
    await transport.close();
    status.value = ConnectionStatus.disconnected;
  }

  Future<void> _sendHello() async {
    final m = HelloMessage(clientName, screenW(), screenH());
    await transport.write(codec.wrap(encodeHello(m)));
  }

  String _humanize(String raw) {
    if (raw.contains('refused')) {
      return 'Connection refused. Is the airpad host running?';
    }
    if (raw.contains('SocketException')) {
      return 'Cannot reach host. Check the IP address.';
    }
    if (raw.contains('timeout')) {
      return 'Connection timed out.';
    }
    return 'Disconnected.';
  }

  void dispose() {
    _statusDisposer();
    _disconnectSub?.cancel();
  }
}
