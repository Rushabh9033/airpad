// Frame codec: 4-byte little-endian length prefix + payload.
// Pre-allocates reusable buffers so the 120Hz sender path avoids GC churn.

import 'dart:typed_data';

class FrameCodec {
  static const int _prefixLen = 4;
  static const int _maxFrameLen = 1 << 20; // 1 MiB sanity cap.

  final ByteData _prefixBuf = ByteData(_prefixLen);

  /// Wrap a payload in a length-prefixed frame.
  /// Returns a freshly-copied Uint8List (the prefix + payload).
  Uint8List wrap(Uint8List payload) {
    final len = payload.length;
    if (len > _maxFrameLen) {
      throw StateError('frame too large: $len bytes');
    }
    _prefixBuf.setUint32(0, len, Endian.little);
    final out = Uint8List(_prefixLen + len);
    final outView = ByteData.view(out.buffer);
    outView.setUint32(0, len, Endian.little);
    out.setRange(_prefixLen, _prefixLen + len, payload);
    return out;
  }

  /// Encode a payload + 1-byte type id into a single wrapped frame.
  /// Used by the hot path where we always know the type byte.
  Uint8List wrapTyped(int typeId, Uint8List payload) {
    final total = 1 + payload.length;
    if (total > _maxFrameLen) {
      throw StateError('frame too large: $total bytes');
    }
    final out = Uint8List(_prefixLen + total);
    final outView = ByteData.view(out.buffer);
    outView.setUint32(0, total, Endian.little);
    out[_prefixLen] = typeId;
    out.setRange(_prefixLen + 1, _prefixLen + total, payload);
    return out;
  }

  /// Convenience: wrap a single pre-encoded message (already includes
  /// its own type byte) with a length prefix.
  Uint8List wrapMessage(Uint8List typedPayload) => wrap(typedPayload);
}
