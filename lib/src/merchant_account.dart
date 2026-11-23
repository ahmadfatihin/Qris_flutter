import 'exception.dart';
import 'tlv.dart';

/// Merchant criteria defined by Bank Indonesia (sub-tag 03).
enum MerchantCriteria {
  /// Usaha Mikro.
  micro('UMI'),

  /// Usaha Kecil.
  small('UKE'),

  /// Usaha Menengah.
  medium('UME'),

  /// Usaha Besar.
  large('UBE'),

  /// Reguler (non-UMKM, e.g. government, education, donation).
  regular('URE');

  const MerchantCriteria(this.code);

  /// The code as it appears in the payload.
  final String code;

  /// Returns the matching criteria, or `null` for unknown codes.
  static MerchantCriteria? fromCode(String? code) {
    for (final c in values) {
      if (c.code == code?.toUpperCase()) return c;
    }
    return null;
  }
}

/// Merchant Account Information template (tags 26–51 in QRIS).
class MerchantAccount {
  MerchantAccount._(this.tag, this.raw, this.subTags);

  /// Parses a merchant account template. If the value is not a valid nested
  /// TLV structure, [subTags] is empty and [raw] still holds the value.
  factory MerchantAccount.fromTlv(Tlv tlv) {
    List<Tlv> sub;
    try {
      sub = List.unmodifiable(TlvCodec.decode(tlv.value));
    } on QrisFormatException {
      sub = const [];
    }
    return MerchantAccount._(tlv.id, tlv.value, sub);
  }

  /// Top-level tag ID, e.g. `"26"` or `"51"`.
  final String tag;

  /// Raw template value.
  final String raw;

  /// Nested data objects.
  final List<Tlv> subTags;

  /// Sub-tag 00, reverse domain name such as `ID.CO.QRIS.WWW`.
  String? get globalUniqueIdentifier => subTags.valueOf('00');

  /// Sub-tag 01, Merchant PAN (usually 19 digits).
  String? get merchantPan => subTags.valueOf('01');

  /// Sub-tag 02, merchant ID. For the national template this is the NMID.
  String? get merchantId => subTags.valueOf('02');

  /// Sub-tag 03, raw merchant criteria code.
  String? get merchantCriteriaCode => subTags.valueOf('03');

  /// Parsed [merchantCriteriaCode].
  MerchantCriteria? get merchantCriteria =>
      MerchantCriteria.fromCode(merchantCriteriaCode);

  /// National Numbering System code: first 8 digits of the PAN, which
  /// identify the issuer.
  String? get nns {
    final pan = merchantPan;
    return pan != null && pan.length >= 8 ? pan.substring(0, 8) : null;
  }

  /// Whether this is the QRIS national template (`ID.CO.QRIS.WWW`).
  bool get isQrisNational =>
      globalUniqueIdentifier?.toUpperCase() == 'ID.CO.QRIS.WWW';

  @override
  String toString() => 'MerchantAccount(tag: $tag, '
      'gui: $globalUniqueIdentifier, id: $merchantId)';
}
