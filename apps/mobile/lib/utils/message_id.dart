import 'dart:math';

final Random _random = Random.secure();

/// A random UUID (version 4) for a chat message, made on the phone before
/// the message is sent.
///
/// The bubble shown while sending and the row that comes back from the
/// database then share this id, so the app can recognise them as the same
/// message and show it once. A made-up local id (`temp_…`) never matched the
/// database's own id, which is why every sent message used to appear twice.
String newMessageId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
