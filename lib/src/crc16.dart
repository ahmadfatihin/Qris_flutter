import 'dart:convert';

/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF), as required by EMVCo
/// Merchant-Presented Mode and therefore by QRIS (tag 63).
abstract final class Crc16 {
  /// Computes the CRC over the UTF-8 bytes of [data].
  static int ccittFalse(String data) {
    var crc = 0xFFFF;
    for (final byte in utf8.encode(data)) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }

  /// Same as [ccittFalse], formatted as 4 uppercase hex characters.
  static String hex(String data) =>
      ccittFalse(data).toRadixString(16).toUpperCase().padLeft(4, '0');
}
