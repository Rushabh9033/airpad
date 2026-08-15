// Binary message types and payloads for the airpad wire protocol.
// Wire format: 4-byte LE length prefix + 1-byte type + payload.
// All multi-byte fields are little-endian.
// Coordinates are normalized 0.0..1.0 from the phone's touch surface.

import 'dart:typed_data';

enum MessageType {
  hello(0x1),
  ping(0x2),
  touchDown(0x3),
  touchMove(0x4),
  touchUp(0x5),
  scroll(0x6),
  button(0x7),
  gesture(0x8);

  final int id;
  const MessageType(this.id);
}

class TouchPoint {
  final int fingerId;
  final double x;
  final double y;
  final double pressure;
  final int tUs;

  const TouchPoint({
    required this.fingerId,
    required this.x,
    required this.y,
    required this.pressure,
    required this.tUs,
  });
}

class ScrollEvent {
  final double dx;
  final double dy;
  const ScrollEvent(this.dx, this.dy);
}

class ButtonEvent {
  // 0 = left, 1 = right
  final int button;
  // 0 = up, 1 = down
  final int state;
  const ButtonEvent(this.button, this.state);
}

class GestureKind {
  // Reserved for Phase 2. We still ship the type id so the host can
  // safely ignore unknown gesture codes in Phase 1.
  static const int none = 0;
  static const int tap = 1;
}

class HelloMessage {
  final String clientName;
  final int screenW;
  final int screenH;
  const HelloMessage(this.clientName, this.screenW, this.screenH);
}

// Frame writer helpers: each returns the encoded type+payload (without
// the 4-byte length prefix). The transport layer is responsible for
// prepending the length.

Uint8List encodeHello(HelloMessage m) {
  final nameBytes = m.clientName.codeUnits;
  final buf = ByteData(1 + 2 + 2 + 4 + nameBytes.length);
  int o = 0;
  buf.setUint8(o, MessageType.hello.id); o += 1;
  buf.setUint16(o, m.screenW, Endian.little); o += 2;
  buf.setUint16(o, m.screenH, Endian.little); o += 2;
  buf.setUint32(o, nameBytes.length, Endian.little); o += 4;
  for (final b in nameBytes) {
    buf.setUint8(o, b); o += 1;
  }
  return buf.buffer.asUint8List(o);
}

Uint8List encodePing(int tUs) {
  final buf = ByteData(1 + 8);
  buf.setUint8(0, MessageType.ping.id);
  buf.setUint64(1, tUs, Endian.little);
  return buf.buffer.asUint8List();
}

Uint8List encodeTouch(MessageType type, TouchPoint p) {
  assert(type == MessageType.touchDown || type == MessageType.touchMove);
  final buf = ByteData(1 + 2 + 4 + 4 + 4 + 8);
  int o = 0;
  buf.setUint8(o, type.id); o += 1;
  buf.setUint16(o, p.fingerId, Endian.little); o += 2;
  buf.setFloat32(o, p.x, Endian.little); o += 4;
  buf.setFloat32(o, p.y, Endian.little); o += 4;
  buf.setFloat32(o, p.pressure, Endian.little); o += 4;
  buf.setUint64(o, p.tUs, Endian.little); o += 8;
  return buf.buffer.asUint8List(o);
}

Uint8List encodeTouchUp(int fingerId) {
  final buf = ByteData(1 + 2);
  buf.setUint8(0, MessageType.touchUp.id);
  buf.setUint16(1, fingerId, Endian.little);
  return buf.buffer.asUint8List();
}

Uint8List encodeScroll(ScrollEvent e) {
  final buf = ByteData(1 + 4 + 4);
  buf.setUint8(0, MessageType.scroll.id);
  buf.setFloat32(1, e.dx, Endian.little);
  buf.setFloat32(5, e.dy, Endian.little);
  return buf.buffer.asUint8List();
}

Uint8List encodeButton(ButtonEvent e) {
  final buf = ByteData(1 + 1 + 1);
  buf.setUint8(0, MessageType.button.id);
  buf.setUint8(1, e.button);
  buf.setUint8(2, e.state);
  return buf.buffer.asUint8List();
}

Uint8List encodeGesture(int kind) {
  final buf = ByteData(1 + 2);
  buf.setUint8(0, MessageType.gesture.id);
  buf.setUint16(1, kind, Endian.little);
  return buf.buffer.asUint8List();
}
