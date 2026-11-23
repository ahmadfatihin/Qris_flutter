import 'package:qris_toolkit/qris_toolkit.dart';

void main() {
  // A static QRIS, e.g. scanned from a merchant's printed sticker.
  const payload = '00020101021126660018ID.CO.TOKOKITA.WWW011993600008123456'
      '78901021012345678900303UMI51440014ID.CO.QRIS.WWW0215ID1023123456789'
      '0303UMI5204581253033605802ID5921WARUNG KOPI NUSANTARA6007JAKARTA6105'
      '1011062080704T0016304BE38';

  final qris = Qris.parse(payload);
  print('Merchant : ${qris.merchantName} (${qris.merchantCity})');
  print('NMID     : ${qris.nmid}');
  print('Criteria : ${qris.merchantCriteria?.name}');
  print('Static?  : ${qris.isStatic}');
  print('CRC ok?  : ${qris.isCrcValid}');

  // Turn it into a dynamic QRIS for Rp25.000 + Rp1.000 fee.
  final dynamicQris = qris.toDynamic(
    amount: 25000,
    fee: const QrisFee.fixed(1000),
  );
  print('\nDynamic payload:\n$dynamicQris');

  // Validate anything before rendering it.
  for (final issue in QrisValidator.validate(dynamicQris.raw)) {
    print(issue);
  }
}
