/// ScanBuffer — pure-Dart state machine for USB-HID barcode scanners.
///
/// Most retail barcode scanners present as a keyboard: they type the
/// payload character-by-character and finish with a configurable
/// terminator (Enter is the universal default). This class accumulates
/// printable chars and emits the completed payload when the terminator
/// arrives.
///
/// Two safety nets:
///   - Inter-char timeout: characters arriving more than [interCharTimeout]
///     after the previous one are treated as a fresh scan (the previous
///     buffer is discarded). Protects against an operator who types a
///     few digits manually, walks away, then triggers a scan minutes
///     later — we don't want the partial input bleeding in.
///   - Max length: scans longer than [maxLength] are dropped — protects
///     against pathological held-key input.
///
/// The class is deliberately UI-agnostic: callers feed it raw chars
/// and a clock (or rely on the default DateTime.now). The widget layer
/// is responsible for filtering down to "printable single char" and
/// for recognising the terminator key.
library;

class ScanBuffer {
  ScanBuffer({
    this.interCharTimeout = const Duration(milliseconds: 100),
    this.maxLength = 64,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration interCharTimeout;
  final int maxLength;
  final DateTime Function() _clock;

  final StringBuffer _buf = StringBuffer();
  DateTime? _lastCharAt;

  /// Current buffered length — useful for tests/diagnostics.
  int get length => _buf.length;

  /// Empties the buffer. Use after consuming a scan, or to bail out
  /// when context changes (e.g. the user opened a dialog).
  void reset() {
    _buf.clear();
    _lastCharAt = null;
  }

  /// Feeds one printable character. Returns null. If the inter-char
  /// timeout has elapsed since the previous char, the buffer is reset
  /// before appending — the new char starts a fresh scan.
  void add(String ch) {
    if (ch.length != 1) {
      throw ArgumentError('ScanBuffer.add: expected single char, got "$ch"');
    }
    final now = _clock();
    if (_lastCharAt != null && now.difference(_lastCharAt!) > interCharTimeout) {
      _buf.clear();
    }
    if (_buf.length >= maxLength) {
      // Pathological — drop everything; treat the new char as the start
      // of a fresh scan attempt.
      _buf.clear();
    }
    _buf.write(ch);
    _lastCharAt = now;
  }

  /// Terminator received. Returns the completed scan (the empty string
  /// if nothing was buffered) and clears the buffer.
  String commit() {
    final out = _buf.toString();
    reset();
    return out;
  }
}
