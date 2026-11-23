import 'additional_data.dart';
import 'crc16.dart';
import 'exception.dart';
import 'fee.dart';
import 'merchant_account.dart';
import 'tlv.dart';

/// A parsed QRIS (EMVCo Merchant-Presented Mode) payload.
///
/// Instances are immutable. Unknown tags are preserved, so converting a
/// payload with [toDynamic] or [toStatic] never drops data you didn't touch.
class Qris {
  Qris._(this.raw, this.tags);

  /// Parses [input]. Leading/trailing whitespace is ignored.
  ///
  /// Only the structure is checked here (TLV format, tag 00 first, tag 63
  /// last). Use [isCrcValid] or `QrisValidator` for semantic checks.
  ///
  /// Throws [QrisFormatException] if [input] is not a QRIS payload.
  factory Qris.parse(String input) {
    final payload = input.trim();
    if (payload.isEmpty) {
      throw const QrisFormatException('Payload is empty.');
    }
    final tags = TlvCodec.decode(payload);
    if (tags.first.id != '00') {
      throw const QrisFormatException(
          'Payload must start with Payload Format Indicator (tag 00).');
    }
    if (tags.last.id != '63' || tags.last.value.length != 4) {
      throw const QrisFormatException(
          'Payload must end with a 4-character CRC (tag 63).');
    }
    return Qris._(payload, List.unmodifiable(tags));
  }

  /// Like [Qris.parse] but returns `null` instead of throwing.
  static Qris? tryParse(String input) {
    try {
      return Qris.parse(input);
    } on QrisFormatException {
      return null;
    }
  }

  /// The payload string, exactly as parsed or generated.
  final String raw;

  /// All top-level tags in payload order.
  final List<Tlv> tags;

  /// Value of the first top-level tag with [id], or `null`.
  String? valueOf(String id) => tags.valueOf(id);

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  /// Tag 00. Should be `"01"`.
  String? get payloadFormatIndicator => valueOf('00');

  /// Tag 01. `"11"` = static, `"12"` = dynamic.
  String? get pointOfInitiationMethod => valueOf('01');

  /// Static QR: reusable, the customer enters the amount.
  bool get isStatic => pointOfInitiationMethod == '11';

  /// Dynamic QR: single transaction, usually with a fixed amount.
  bool get isDynamic => pointOfInitiationMethod == '12';

  // ---------------------------------------------------------------------------
  // Merchant
  // ---------------------------------------------------------------------------

  /// All merchant account templates (tags 02–51) in payload order.
  List<MerchantAccount> get merchantAccounts => [
        for (final t in tags)
          if (_isMerchantAccountTag(t.id)) MerchantAccount.fromTlv(t),
      ];

  /// The QRIS national template (`ID.CO.QRIS.WWW`), usually tag 51.
  MerchantAccount? get nationalAccount {
    for (final a in merchantAccounts) {
      if (a.isQrisNational) return a;
    }
    return null;
  }

  /// National Merchant ID (NMID), e.g. `ID1023123456789`.
  String? get nmid => nationalAccount?.merchantId;

  /// Merchant criteria from the national template, falling back to the
  /// first template that declares one.
  MerchantCriteria? get merchantCriteria {
    final national = nationalAccount?.merchantCriteria;
    if (national != null) return national;
    for (final a in merchantAccounts) {
      if (a.merchantCriteria != null) return a.merchantCriteria;
    }
    return null;
  }

  /// Tag 52, Merchant Category Code (ISO 18245).
  String? get merchantCategoryCode => valueOf('52');

  /// Tag 53, ISO 4217 numeric currency. `"360"` = IDR.
  String? get currencyCode => valueOf('53');

  /// Tag 58, ISO 3166-1 alpha-2 country code. `"ID"` for QRIS.
  String? get countryCode => valueOf('58');

  /// Tag 59.
  String? get merchantName => valueOf('59');

  /// Tag 60.
  String? get merchantCity => valueOf('60');

  /// Tag 61.
  String? get postalCode => valueOf('61');

  /// Tag 62, parsed.
  AdditionalData? get additionalData {
    final v = valueOf('62');
    return v == null ? null : AdditionalData.fromValue(v);
  }

  // ---------------------------------------------------------------------------
  // Amount & fees
  // ---------------------------------------------------------------------------

  /// Tag 54 as written in the payload.
  String? get amountRaw => valueOf('54');

  /// Tag 54 as a number, or `null` if absent/unparseable.
  num? get amount {
    final v = amountRaw;
    return v == null ? null : num.tryParse(v);
  }

  /// Tags 55–57 interpreted as a [QrisFee], or `null` if absent/invalid.
  QrisFee? get fee {
    switch (valueOf('55')) {
      case '01':
        return const QrisFee.promptTip();
      case '02':
        final v = num.tryParse(valueOf('56') ?? '');
        return v == null ? null : QrisFee.fixed(v);
      case '03':
        final v = num.tryParse(valueOf('57') ?? '');
        return v == null ? null : QrisFee.percentage(v);
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CRC
  // ---------------------------------------------------------------------------

  /// CRC declared in tag 63.
  String get crc => tags.last.value;

  /// CRC computed from the payload.
  String get computedCrc => Crc16.hex(raw.substring(0, raw.length - 4));

  /// Whether [crc] matches [computedCrc] (case-insensitive).
  bool get isCrcValid => crc.toUpperCase() == computedCrc;

  // ---------------------------------------------------------------------------
  // Conversion
  // ---------------------------------------------------------------------------

  /// Returns a dynamic QRIS with [amount] (and optional [fee]).
  ///
  /// Sets tag 01 to `12`, replaces tags 54–57, keeps every other tag in its
  /// original order, and recalculates the CRC. Works on static and dynamic
  /// payloads alike.
  ///
  /// Throws [ArgumentError] if [amount] or the fee value is out of range.
  Qris toDynamic({required num amount, QrisFee? fee}) {
    final amountTags = <Tlv>[
      Tlv('54', formatAmount(amount)),
      ...switch (fee) {
        null => const <Tlv>[],
        QrisPromptTip() => const [Tlv('55', '01')],
        QrisFixedFee(amount: final feeAmount) => [
            const Tlv('55', '02'),
            Tlv('56', formatAmount(feeAmount, name: 'fee')),
          ],
        QrisPercentageFee(:final percent) => [
            const Tlv('55', '03'),
            Tlv('57', _formatPercent(percent)),
          ],
      },
    ];
    return _rebuild(initiation: '12', insert: amountTags);
  }

  /// Returns a static QRIS: tag 01 set to `11`, tags 54–57 removed, CRC
  /// recalculated.
  Qris toStatic() => _rebuild(initiation: '11', insert: const []);

  Qris _rebuild({required String initiation, required List<Tlv> insert}) {
    const amountIds = {'54', '55', '56', '57'};
    final body = <Tlv>[
      for (final t in tags)
        if (t.id != '63' && !amountIds.contains(t.id))
          t.id == '01' ? Tlv('01', initiation) : t,
    ];
    if (body.valueOf('01') == null) {
      body.insert(1, Tlv('01', initiation));
    }
    var at = body.indexWhere((t) => t.id.compareTo('57') > 0);
    if (at == -1) at = body.length;
    body.insertAll(at, insert);
    return Qris.parse(assemble(body));
  }

  /// Encodes [tags] (without tag 63) and appends a freshly computed CRC.
  static String assemble(Iterable<Tlv> tags) {
    final withoutCrc = '${TlvCodec.encode(tags.where((t) => t.id != '63'))}'
        '6304';
    return withoutCrc + Crc16.hex(withoutCrc);
  }

  /// Formats a positive IDR amount as QRIS expects: no grouping, `.` as the
  /// decimal separator, at most 2 decimals, at most 13 characters.
  static String formatAmount(num value, {String name = 'amount'}) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'must be a positive number');
    }
    final text = _trimDecimals(value);
    if (text.length > 13) {
      throw ArgumentError.value(value, name, 'exceeds 13 characters');
    }
    return text;
  }

  static String _formatPercent(num value) {
    if (!value.isFinite || value <= 0 || value >= 100) {
      throw ArgumentError.value(
          value, 'percent', 'must be greater than 0 and less than 100');
    }
    return _trimDecimals(value);
  }

  static String _trimDecimals(num value) {
    if (value == value.truncate()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static bool _isMerchantAccountTag(String id) {
    final n = int.tryParse(id);
    return n != null && n >= 2 && n <= 51;
  }

  @override
  bool operator ==(Object other) => other is Qris && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  /// Returns the payload string, ready to be rendered as a QR code.
  @override
  String toString() => raw;
}
