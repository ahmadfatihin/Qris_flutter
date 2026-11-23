import 'exception.dart';

/// A single EMVCo Tag-Length-Value data object.
class Tlv {
  const Tlv(this.id, this.value);

  /// Two-digit tag ID, e.g. `"59"`.
  final String id;

  /// Raw value.
  final String value;

  /// Encodes as `ID + LL + value`. Throws if value is longer than 99 chars.
  String encode() {
    if (value.length > 99) {
      throw QrisFormatException(
          'Value of tag $id is ${value.length} characters; maximum is 99.');
    }
    return '$id${value.length.toString().padLeft(2, '0')}$value';
  }

  @override
  bool operator ==(Object other) =>
      other is Tlv && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);

  @override
  String toString() => 'Tlv($id, "$value")';
}

/// Parser/encoder for flat lists of EMVCo TLV objects.
abstract final class TlvCodec {
  static final _twoDigits = RegExp(r'^\d{2}$');

  /// Parses [input] into a list of TLV objects, preserving order.
  ///
  /// Throws [QrisFormatException] on malformed input.
  static List<Tlv> decode(String input) {
    final result = <Tlv>[];
    var i = 0;
    while (i < input.length) {
      if (i + 4 > input.length) {
        throw QrisFormatException('Truncated tag header.', offset: i);
      }
      final id = input.substring(i, i + 2);
      final len = input.substring(i + 2, i + 4);
      if (!_twoDigits.hasMatch(id)) {
        throw QrisFormatException('Invalid tag ID "$id".', offset: i);
      }
      if (!_twoDigits.hasMatch(len)) {
        throw QrisFormatException('Invalid length "$len" for tag $id.',
            offset: i + 2);
      }
      final start = i + 4;
      final end = start + int.parse(len);
      if (end > input.length) {
        throw QrisFormatException(
            'Tag $id declares length $len but the payload ends early.',
            offset: start);
      }
      result.add(Tlv(id, input.substring(start, end)));
      i = end;
    }
    return result;
  }

  /// Encodes [items] in the given order.
  static String encode(Iterable<Tlv> items) =>
      items.map((t) => t.encode()).join();
}

/// Helpers for working with a list of TLV objects.
extension TlvListX on List<Tlv> {
  /// Value of the first tag with [id], or `null`.
  String? valueOf(String id) {
    for (final t in this) {
      if (t.id == id) return t.value;
    }
    return null;
  }
}
