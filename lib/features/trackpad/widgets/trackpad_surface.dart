// Raw pointer surface. Uses Flutter's Listener (NOT GestureDetector) so we
// can read every PointerEvent with its native timestamp and pointer id.
//
// The widget owns a TrackpadGestureRecognizer + TouchSender for its lifetime.
// It emits debug stats through a callback for the optional debug overlay.

import 'package:flutter/widgets.dart';

import '../../../core/protocol/messages.dart';
import '../controllers/gesture_recognizer.dart';
import '../controllers/touch_sender.dart';

class TouchDebugStats {
  final double x;
  final double y;
  final int fingers;
  final int msSinceLastSend;
  const TouchDebugStats({
    required this.x,
    required this.y,
    required this.fingers,
    required this.msSinceLastSend,
  });
}

class TrackpadSurface extends StatefulWidget {
  final TrackpadGestureRecognizer recognizer;
  final TouchSender sender;
  final void Function(TouchDebugStats stats)? onStats;
  // Set true to allow 2-finger tap = right-click in Phase 1.
  // Phase 2 will own the full gesture grammar.
  final bool enableTwoFingerRightClick;

  const TrackpadSurface({
    super.key,
    required this.recognizer,
    required this.sender,
    this.onStats,
    this.enableTwoFingerRightClick = true,
  });

  @override
  State<TrackpadSurface> createState() => _TrackpadSurfaceState();
}

class _TrackpadSurfaceState extends State<TrackpadSurface> {
  Size? _lastSize;
  int _lastSentAt = 0;

  void _markSent() {
    _lastSentAt = DateTime.now().millisecondsSinceEpoch;
  }

  void _emitStats() {
    final cb = widget.onStats;
    if (cb == null) return;
    cb(TouchDebugStats(
      x: 0,
      y: 0,
      fingers: widget.recognizer.activeCount,
      msSinceLastSend: _lastSentAt == 0
          ? -1
          : DateTime.now().millisecondsSinceEpoch - _lastSentAt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _lastSize = size;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onCancel,
          child: Container(
            color: const Color(0xFF101012),
            child: const Center(
              child: Text(
                'Trackpad',
                style: TextStyle(
                  color: Color(0xFF6B6B70),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onDown(PointerDownEvent e) {
    widget.recognizer.onDown(e);
    final size = _lastSize ?? MediaQuery.of(context).size;
    // Send a TOUCH_DOWN with the initial position so the host can
    // immediately move the cursor to that point — without this, the
    // first 8 px of any drag are silently dropped (recognizer waits
    // for movement to exceed dragThresholdPx before emitting).
    if (widget.recognizer.activeCount == 1) {
      widget.sender.sendTouchDown(TouchPoint(
        fingerId: e.pointer,
        x: (e.localPosition.dx / size.width).clamp(0.0, 1.0),
        y: (e.localPosition.dy / size.height).clamp(0.0, 1.0),
        pressure: e.pressure,
        tUs: DateTime.now().microsecondsSinceEpoch,
      ));
      // First finger down -> LEFT button down (trackpad default).
      widget.sender.sendButton(const ButtonEvent(0, 1));
    } else if (widget.recognizer.activeCount == 2 &&
        widget.enableTwoFingerRightClick) {
      widget.sender.sendTouchDown(TouchPoint(
        fingerId: e.pointer,
        x: (e.localPosition.dx / size.width).clamp(0.0, 1.0),
        y: (e.localPosition.dy / size.height).clamp(0.0, 1.0),
        pressure: e.pressure,
        tUs: DateTime.now().microsecondsSinceEpoch,
      ));
      widget.sender.sendButton(const ButtonEvent(1, 1));
    }
    _markSent();
    _emitStats();
  }

  void _onMove(PointerMoveEvent e) {
    final size = _lastSize ?? MediaQuery.of(context).size;
    widget.recognizer.onMove(
      e,
      size,
      (p) {
        widget.sender.queueTouch(p);
        _markSent();
        _emitStats();
      },
      (s) {
        widget.sender.queueScroll(s);
        _markSent();
        _emitStats();
      },
    );
  }

  void _onUp(PointerUpEvent e) {
    final decision = widget.recognizer.onUp(e, widget.sender.sendTouchUp);
    if (widget.recognizer.activeCount == 0) {
      widget.sender.sendButton(const ButtonEvent(0, 0));
    }
    if (decision.isTap) {
      widget.sender.sendGesture(1); // 1 = tap
    }
    _markSent();
    _emitStats();
  }

  void _onCancel(PointerCancelEvent e) {
    widget.recognizer.onCancel(e.pointer);
    widget.sender.sendTouchUp(e.pointer);
    if (widget.recognizer.activeCount == 0) {
      widget.sender.sendButton(const ButtonEvent(0, 0));
    }
    _emitStats();
  }
}
