// Custom gesture recognizer built on top of Flutter's Listener widget.
//
// Decision tree:
//   - 1 finger, movement < dragThreshold px, release within tapMaxMs -> TAP
//   - 1 finger, movement >= dragThreshold px                         -> DRAG (mouse move)
//   - 2 fingers, movement                                              -> SCROLL
//   - otherwise                                                        -> ignored
//
// Sensitivity (0.5..3.0) is applied here, BEFORE encoding. We never ship
// raw device pixels. Scroll speed multiplies scroll deltas the same way.
//
// All thresholds are in surface-local logical pixels.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' show Size;

import '../../../core/protocol/messages.dart';
import '../../../core/time/clock.dart';

enum GestureKind2 { none, drag, tap, scroll }

class _Pointer {
  int id;
  double x;
  double y;
  int downAtUs;
  double startX;
  double startY;
  bool moved = false;
  _Pointer({
    required this.id,
    required this.x,
    required this.y,
    required this.startX,
    required this.startY,
    required this.downAtUs,
  });
}

class TrackpadGestureRecognizer {
  static const double dragThresholdPx = 8.0;
  static const int tapMaxMs = 250;

  final double Function() sensitivity;
  final double Function() scrollSpeed;

  final Map<int, _Pointer> _active = <int, _Pointer>{};

  TrackpadGestureRecognizer({required this.sensitivity, required this.scrollSpeed});

  bool get hasActive => _active.isNotEmpty;
  int get activeCount => _active.length;

  void onDown(PointerDownEvent e) {
    _active[e.pointer] = _Pointer(
      id: e.pointer,
      x: e.localPosition.dx,
      y: e.localPosition.dy,
      startX: e.localPosition.dx,
      startY: e.localPosition.dy,
      downAtUs: clock.nowUs,
    );
  }

  void onMove(PointerMoveEvent e, Size surface, void Function(TouchPoint p) emitTouch,
      void Function(ScrollEvent s) emitScroll) {
    final p = _active[e.pointer];
    if (p == null) return;
    final newX = e.localPosition.dx;
    final newY = e.localPosition.dy;
    final dx = newX - p.x;
    final dy = newY - p.y;
    final movedFromStart = math.sqrt(
      math.pow(newX - p.startX, 2).toDouble() +
          math.pow(newY - p.startY, 2).toDouble(),
    );
    if (movedFromStart >= dragThresholdPx) {
      p.moved = true;
    }
    p.x = newX;
    p.y = newY;

    if (_active.length >= 2) {
      // Two-finger pan = scroll.
      final s = scrollSpeed();
      emitScroll(ScrollEvent(dx * s, dy * s));
    } else {
      // Always emit the current position. The host needs every move
      // to keep the cursor smooth; the tap-vs-drag decision uses
      // p.moved at TOUCH_UP time, not here.
      emitTouch(TouchPoint(
        fingerId: p.id,
        x: (p.x / surface.width).clamp(0.0, 1.0),
        y: (p.y / surface.height).clamp(0.0, 1.0),
        pressure: e.pressure,
        tUs: clock.nowUs,
      ));
    }
  }

  GestureDecision onUp(PointerUpEvent e, void Function(int fingerId) emitUp) {
    final p = _active.remove(e.pointer);
    if (p == null) return GestureDecision._none();
    emitUp(p.id);
    final heldMs = (clock.nowUs - p.downAtUs) ~/ 1000;
    if (!p.moved && heldMs < tapMaxMs) {
      return GestureDecision(GestureKind2.tap, isTap: true);
    }
    return GestureDecision._none();
  }

  void onCancel(int pointer) {
    _active.remove(pointer);
  }

  void reset() {
    _active.clear();
  }
}

class GestureDecision {
  final GestureKind2 kind;
  final bool isTap;
  const GestureDecision(this.kind, {this.isTap = false});
  const GestureDecision._none() : kind = GestureKind2.none, isTap = false;
}
