/// A tiny, fully deterministic pseudo-random number generator.
///
/// Why not `dart:math`'s `Random(seed)`? Its documentation explicitly warns
/// that the generated stream "can change between releases of the library",
/// which would break Hard Rule #3 (byte-identical runs for a given seed).
/// This xorshift32 generator is specified entirely here, so the same seed
/// yields the same stream on every platform and every Dart version.
///
/// xorshift32 uses only shifts and XORs (no multiplication), so it stays
/// exactly within 32 bits and behaves identically on native and web targets.
/// Its statistical quality is more than adequate for spawn placement.
class DeterministicRng {
  /// Constructs the generator from [seed]. The internal state must never be
  /// zero (xorshift would then be stuck at zero), so a zero seed is remapped
  /// to a fixed non-zero constant.
  DeterministicRng(int seed)
    : _state = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : (seed & 0xFFFFFFFF);

  int _state;

  /// The current internal state. Exposed only so a simulation can be cloned
  /// or serialized for replays/determinism checks.
  int get state => _state;

  /// Advances the generator and returns the raw 32-bit unsigned value.
  int _next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  /// Returns a value in `[0, max)`. [max] must be positive.
  int nextInt(int max) {
    assert(max > 0, 'nextInt requires a positive bound');
    return _next() % max;
  }
}
