import 'exception.dart';
import 'tlv.dart';

/// Additional Data Field Template (tag 62).
class AdditionalData {
  AdditionalData._(this.raw, this.subTags);

  /// Parses tag 62. If the value is not valid nested TLV, [subTags] is empty.
  factory AdditionalData.fromValue(String value) {
    List<Tlv> sub;
    try {
      sub = List.unmodifiable(TlvCodec.decode(value));
    } on QrisFormatException {
      sub = const [];
    }
    return AdditionalData._(value, sub);
  }

  /// Raw value of tag 62.
  final String raw;

  /// Nested data objects.
  final List<Tlv> subTags;

  String? get billNumber => subTags.valueOf('01');
  String? get mobileNumber => subTags.valueOf('02');
  String? get storeLabel => subTags.valueOf('03');
  String? get loyaltyNumber => subTags.valueOf('04');
  String? get referenceLabel => subTags.valueOf('05');
  String? get customerLabel => subTags.valueOf('06');
  String? get terminalLabel => subTags.valueOf('07');
  String? get purposeOfTransaction => subTags.valueOf('08');
  String? get additionalConsumerDataRequest => subTags.valueOf('09');

  @override
  String toString() => 'AdditionalData($subTags)';
}
