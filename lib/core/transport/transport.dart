// Abstract transport. One Transport = one bidirectional stream.

abstract class Transport {
  Future<void> connect({required String host, required int port});
  Future<void> write(List<int> bytes);
  Future<void> close();
  Stream<void> get disconnected;
  String? get lastError;
}
