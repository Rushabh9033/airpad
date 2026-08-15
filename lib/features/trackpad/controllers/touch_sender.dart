// 120 Hz throttled sender. Coalesces touch moves per finger and dispatches
// a single TOUCH_MOVE per finger per 120 Hz tick. Tap and up events flush
// immediately — they're tiny and latency-critical.

import 'dart:async';
import 'dart:typed_data';

import '../../../core/protocol/codec.dart';
import '../../../core/protocol/messages.dart';
import '../../../core/transport/transport.dart';

class TouchSender {
  static const int targetHz = 120;
  static const Duration tickInterval = Duration(microseconds: 1000000 ~/ 120);

  final Transport transport;
  final FrameCodec codec = FrameCodec();

  Timer? _timer;
  // fingerId -> last queued TouchPoint for coalescing
  final Map<int, TouchPoint> _pending = <int, TouchPoint>{};
  bool _scrollDirty = false;
  ScrollEvent _pendingScroll = const ScrollEvent(0, 0);

  TouchSender(this.transport);

  void start() {
    _timer ??= Timer.periodic(tickInterval, (_) => _flushTick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }

  void queueTouch(TouchPoint p) {
    _pending[p.fingerId] = p;
  }

  void queueScroll(ScrollEvent e) {
    _pendingScroll = ScrollEvent(_pendingScroll.dx + e.dx, _pendingScroll.dy + e.dy);
    _scrollDirty = true;
  }

  Future<void> sendTouchDown(TouchPoint p) async {
    await _sendFrame(MessageType.touchDown, encodeTouch(MessageType.touchDown, p));
  }

  Future<void> sendTouchUp(int fingerId) async {
    await _sendFrame(MessageType.touchUp, encodeTouchUp(fingerId));
  }

  Future<void> sendButton(ButtonEvent e) async {
    await _sendFrame(MessageType.button, encodeButton(e));
  }

  Future<void> sendGesture(int kind) async {
    await _sendFrame(MessageType.gesture, encodeGesture(kind));
  }

  Future<void> _flushTick() async {
    if (_pending.isNotEmpty) {
      final batch = _pending.values.toList(growable: false);
      _pending.clear();
      for (final p in batch) {
        await _sendFrame(
            MessageType.touchMove, encodeTouch(MessageType.touchMove, p));
      }
    }
    if (_scrollDirty) {
      final s = _pendingScroll;
      _pendingScroll = const ScrollEvent(0, 0);
      _scrollDirty = false;
      await _sendFrame(MessageType.scroll, encodeScroll(s));
    }
  }

  Future<void> _sendFrame(MessageType type, Uint8List typedPayload) async {
    try {
      await transport.write(codec.wrapMessage(typedPayload));
    } on Object {
      // Transport failures bubble up via the transport's disconnected
      // stream; we don't want to crash the gesture pipeline on a single
      // dropped packet during a transient network blip.
    }
  }
}
