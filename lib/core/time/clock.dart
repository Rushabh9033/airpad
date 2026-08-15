// Microsecond-precision monotonic clock for stamping touch events.
// Uses Stopwatch.elapsedMicroseconds which is monotonic on every platform.

class Clock {
  final Stopwatch _sw;
  Clock() : _sw = Stopwatch()..start();

  int get nowUs => _sw.elapsedMicroseconds;
}

final Clock clock = Clock();
