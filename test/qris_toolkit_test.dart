import 'package:qris_toolkit/qris_toolkit.dart';
import 'package:test/test.dart';

// Fictional merchant. Fixtures were generated with an independent reference
// implementation (Python) to avoid testing the library against itself.
const staticQris = '00020101021126660018ID.CO.TOKOKITA.WWW0119936000081234567'
    '8901021012345678900303UMI51440014ID.CO.QRIS.WWW0215ID10231234567890303'
    'UMI5204581253033605802ID5921WARUNG KOPI NUSANTARA6007JAKARTA6105101106'
    '2080704T0016304BE38';

const dynamicQris = '00020101021226660018ID.CO.TOKOKITA.WWW01199360000812345'
    '678901021012345678900303UMI51440014ID.CO.QRIS.WWW0215ID102312345678903'
    '03UMI5204581253033605405250005802ID5921WARUNG KOPI NUSANTARA6007JAKART'
    'A61051011062080704T0016304D58D';

const dynamicWithFeeQris = '00020101021226660018ID.CO.TOKOKITA.WWW0119936000'
    '0812345678901021012345678900303UMI51440014ID.CO.QRIS.WWW0215ID10231234'
    '567890303UMI520458125303360540525000550202560410005802ID5921WARUNG KOP'
    'I NUSANTARA6007JAKARTA61051011062080704T0016304086A';

void main() {
  group('Crc16', () {
    test('matches the CRC-16/CCITT-FALSE check value', () {
      expect(Crc16.hex('123456789'), '29B1');
    });
  });

  group('TlvCodec', () {
    test('round-trips', () {
      final tags = TlvCodec.decode('000201010211');
      expect(tags, [const Tlv('00', '01'), const Tlv('01', '11')]);
      expect(TlvCodec.encode(tags), '000201010211');
    });

    test('rejects truncated values', () {
      expect(() => TlvCodec.decode('0005AB'),
          throwsA(isA<QrisFormatException>()));
    });

    test('rejects non-numeric lengths', () {
      expect(() => TlvCodec.decode('00XX01'),
          throwsA(isA<QrisFormatException>()));
    });
  });

  group('Qris.parse', () {
    final qris = Qris.parse(staticQris);

    test('reads merchant data', () {
      expect(qris.isStatic, isTrue);
      expect(qris.merchantName, 'WARUNG KOPI NUSANTARA');
      expect(qris.merchantCity, 'JAKARTA');
      expect(qris.postalCode, '10110');
      expect(qris.merchantCategoryCode, '5812');
      expect(qris.currencyCode, '360');
      expect(qris.countryCode, 'ID');
      expect(qris.amount, isNull);
    });

    test('reads merchant accounts', () {
      expect(qris.merchantAccounts.map((a) => a.tag), ['26', '51']);
      expect(qris.nmid, 'ID1023123456789');
      expect(qris.merchantCriteria, MerchantCriteria.micro);
      final issuer = qris.merchantAccounts.first;
      expect(issuer.globalUniqueIdentifier, 'ID.CO.TOKOKITA.WWW');
      expect(issuer.nns, '93600008');
    });

    test('reads additional data', () {
      expect(qris.additionalData?.terminalLabel, 'T001');
    });

    test('verifies CRC', () {
      expect(qris.crc, 'BE38');
      expect(qris.isCrcValid, isTrue);
    });

    test('trims whitespace', () {
      expect(Qris.parse('  $staticQris\n').raw, staticQris);
    });

    test('tryParse returns null for garbage', () {
      expect(Qris.tryParse('hello'), isNull);
      expect(Qris.tryParse(''), isNull);
    });

    test('requires tag 63 at the end', () {
      expect(() => Qris.parse('000201010211'),
          throwsA(isA<QrisFormatException>()));
    });
  });

  group('toDynamic', () {
    final qris = Qris.parse(staticQris);

    test('matches reference output', () {
      expect(qris.toDynamic(amount: 25000).raw, dynamicQris);
    });

    test('adds a fixed fee', () {
      final d = qris.toDynamic(amount: 25000, fee: const QrisFee.fixed(1000));
      expect(d.raw, dynamicWithFeeQris);
      expect(d.fee, const QrisFee.fixed(1000));
    });

    test('adds prompt tip and percentage fee', () {
      expect(qris.toDynamic(amount: 1, fee: const QrisFee.promptTip()).fee,
          const QrisFee.promptTip());
      final p = qris.toDynamic(amount: 1, fee: const QrisFee.percentage(2.5));
      expect(p.valueOf('57'), '2.5');
      expect(p.fee, const QrisFee.percentage(2.5));
    });

    test('replaces an existing amount', () {
      final d = Qris.parse(dynamicWithFeeQris).toDynamic(amount: 5000);
      expect(d.amountRaw, '5000');
      expect(d.fee, isNull);
      expect(d.isCrcValid, isTrue);
    });

    test('formats decimals', () {
      expect(qris.toDynamic(amount: 10000.5).amountRaw, '10000.5');
      expect(qris.toDynamic(amount: 10000.0).amountRaw, '10000');
    });

    test('rejects invalid amounts', () {
      expect(() => qris.toDynamic(amount: 0), throwsArgumentError);
      expect(() => qris.toDynamic(amount: -1), throwsArgumentError);
      expect(() => qris.toDynamic(amount: double.nan), throwsArgumentError);
      expect(() => qris.toDynamic(amount: 99999999999999), throwsArgumentError);
    });

    test('result is valid', () {
      expect(qris.toDynamic(amount: 25000).isValid, isTrue);
    });
  });

  group('toStatic', () {
    test('reverses toDynamic', () {
      expect(Qris.parse(dynamicWithFeeQris).toStatic().raw, staticQris);
    });
  });

  group('QrisValidator', () {
    test('accepts valid payloads', () {
      expect(QrisValidator.validate(staticQris), isEmpty);
      expect(QrisValidator.validate(dynamicQris), isEmpty);
    });

    test('reports malformed input', () {
      final issues = QrisValidator.validate('not a qris');
      expect(issues.single.code, 'malformed');
    });

    test('reports CRC mismatch', () {
      final broken = '${staticQris.substring(0, staticQris.length - 4)}0000';
      final issues = QrisValidator.validate(broken);
      expect(issues.map((i) => i.code), contains('crc_mismatch'));
    });

    test('reports wrong currency', () {
      final tags = Qris.parse(staticQris)
          .tags
          .map((t) => t.id == '53' ? const Tlv('53', '840') : t);
      final issues = QrisValidator.validate(Qris.assemble(tags));
      expect(issues.map((i) => i.code), ['invalid_currency']);
    });

    test('warns on dynamic without amount', () {
      final tags = Qris.parse(staticQris)
          .tags
          .map((t) => t.id == '01' ? const Tlv('01', '12') : t);
      final issues = QrisValidator.validate(Qris.assemble(tags));
      expect(issues.single.code, 'dynamic_without_amount');
      expect(issues.single.isError, isFalse);
    });
  });
}
