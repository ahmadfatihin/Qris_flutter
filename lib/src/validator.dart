import 'exception.dart';
import 'qris.dart';

/// How serious a [QrisIssue] is.
enum QrisIssueSeverity {
  /// The payload violates the spec and will likely be rejected by apps.
  error,

  /// Unusual but may still be accepted.
  warning,
}

/// A single problem found by [QrisValidator].
class QrisIssue {
  const QrisIssue(this.severity, this.code, this.message, {this.tag});

  final QrisIssueSeverity severity;

  /// Stable machine-readable identifier, e.g. `crc_mismatch`.
  final String code;

  /// Human readable explanation.
  final String message;

  /// Related tag ID, if any.
  final String? tag;

  bool get isError => severity == QrisIssueSeverity.error;

  @override
  String toString() =>
      '[${severity.name}] $code${tag == null ? '' : ' (tag $tag)'}: $message';
}

/// Checks QRIS payloads against the rules apps commonly enforce.
abstract final class QrisValidator {
  static final _amount = RegExp(r'^\d+(\.\d{1,2})?$');
  static final _mcc = RegExp(r'^\d{4}$');

  /// Validates a raw string. Structural problems are reported as a single
  /// `malformed` error instead of being thrown.
  static List<QrisIssue> validate(String input) {
    try {
      return validateQris(Qris.parse(input));
    } on QrisFormatException catch (e) {
      return [QrisIssue(QrisIssueSeverity.error, 'malformed', e.message)];
    }
  }

  /// Validates an already parsed payload.
  static List<QrisIssue> validateQris(Qris qris) {
    final issues = <QrisIssue>[];
    void error(String code, String msg, [String? tag]) =>
        issues.add(QrisIssue(QrisIssueSeverity.error, code, msg, tag: tag));
    void warn(String code, String msg, [String? tag]) =>
        issues.add(QrisIssue(QrisIssueSeverity.warning, code, msg, tag: tag));

    // Duplicates
    final seen = <String>{};
    for (final t in qris.tags) {
      if (!seen.add(t.id)) error('duplicate_tag', 'Tag appears more than once.', t.id);
    }

    // 00, 01
    if (qris.payloadFormatIndicator != '01') {
      error('invalid_format_indicator', 'Tag 00 must be "01".', '00');
    }
    final poi = qris.pointOfInitiationMethod;
    if (poi == null) {
      warn('missing_initiation_method', 'Tag 01 is missing.', '01');
    } else if (poi != '11' && poi != '12') {
      error('invalid_initiation_method',
          'Tag 01 must be "11" (static) or "12" (dynamic), got "$poi".', '01');
    }

    // Merchant accounts
    final accounts = qris.merchantAccounts;
    if (accounts.isEmpty) {
      error('missing_merchant_account',
          'At least one merchant account template (tags 02–51) is required.');
    } else if (qris.nationalAccount == null) {
      warn('missing_national_account',
          'No template with ID.CO.QRIS.WWW (usually tag 51) was found.');
    }

    // Mandatory simple tags
    final mcc = qris.merchantCategoryCode;
    if (mcc == null) {
      error('missing_mcc', 'Tag 52 (Merchant Category Code) is missing.', '52');
    } else if (!_mcc.hasMatch(mcc)) {
      error('invalid_mcc', 'Tag 52 must be 4 digits, got "$mcc".', '52');
    }
    if (qris.currencyCode != '360') {
      error('invalid_currency',
          'Tag 53 must be "360" (IDR), got "${qris.currencyCode}".', '53');
    }
    if (qris.countryCode != 'ID') {
      error('invalid_country',
          'Tag 58 must be "ID", got "${qris.countryCode}".', '58');
    }
    final name = qris.merchantName;
    if (name == null || name.isEmpty) {
      error('missing_merchant_name', 'Tag 59 is missing.', '59');
    } else if (name.length > 25) {
      warn('merchant_name_too_long',
          'Tag 59 is ${name.length} characters; the spec allows 25.', '59');
    }
    final city = qris.merchantCity;
    if (city == null || city.isEmpty) {
      error('missing_merchant_city', 'Tag 60 is missing.', '60');
    } else if (city.length > 15) {
      warn('merchant_city_too_long',
          'Tag 60 is ${city.length} characters; the spec allows 15.', '60');
    }

    // Amount
    final amount = qris.amountRaw;
    if (amount != null) {
      if (!_amount.hasMatch(amount) || amount.length > 13) {
        error('invalid_amount', 'Tag 54 "$amount" is not a valid amount.', '54');
      } else if (num.parse(amount) <= 0) {
        error('invalid_amount', 'Tag 54 must be greater than zero.', '54');
      }
      if (qris.isStatic) {
        warn('static_with_amount',
            'Static QR (tag 01 = 11) should not contain an amount.', '54');
      }
    } else if (qris.isDynamic) {
      warn('dynamic_without_amount',
          'Dynamic QR (tag 01 = 12) usually contains an amount.', '54');
    }

    // Fees
    final indicator = qris.valueOf('55');
    final fixed = qris.valueOf('56');
    final percent = qris.valueOf('57');
    switch (indicator) {
      case null:
        if (fixed != null || percent != null) {
          warn('fee_without_indicator',
              'Tag 56/57 is present but tag 55 is missing.', '55');
        }
      case '01':
        break;
      case '02':
        if (fixed == null || !_amount.hasMatch(fixed)) {
          error('invalid_fixed_fee',
              'Tag 55 = 02 requires a valid fixed fee in tag 56.', '56');
        }
      case '03':
        final p = num.tryParse(percent ?? '');
        if (p == null || p <= 0 || p >= 100) {
          error('invalid_percentage_fee',
              'Tag 55 = 03 requires a percentage between 0 and 100 in tag 57.',
              '57');
        }
      default:
        error('invalid_fee_indicator',
            'Tag 55 must be 01, 02, or 03, got "$indicator".', '55');
    }

    // CRC
    if (!qris.isCrcValid) {
      error('crc_mismatch',
          'CRC is ${qris.crc} but should be ${qris.computedCrc}.', '63');
    }

    return issues;
  }
}

/// Convenience validation on [Qris].
extension QrisValidation on Qris {
  /// All issues found by [QrisValidator].
  List<QrisIssue> validate() => QrisValidator.validateQris(this);

  /// `true` when there are no error-level issues (warnings are allowed).
  bool get isValid => !validate().any((i) => i.isError);
}
