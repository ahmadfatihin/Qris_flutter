# qris_toolkit

Pure Dart toolkit for **QRIS** (Quick Response Code Indonesian Standard).
Works in Flutter (Android, iOS, web, desktop) and server-side Dart.

- Parse QRIS payloads: merchant name, city, NMID, merchant criteria, MCC, amount, fees, additional data
- Convert **static → dynamic** with amount and tip/convenience fee, with CRC recalculated
- Convert dynamic → static
- Validate with detailed, machine-readable issues (`crc_mismatch`, `invalid_currency`, ...)
- Unknown tags are preserved, so conversions never drop data
- Zero dependencies

## Usage

```dart
import 'package:qris_toolkit/qris_toolkit.dart';

final qris = Qris.parse(scannedString);
print(qris.merchantName); // WARUNG KOPI NUSANTARA
print(qris.nmid);         // ID1023123456789
print(qris.isCrcValid);   // true

final dynamicQris = qris.toDynamic(
  amount: 25000,
  fee: const QrisFee.fixed(1000), // or .percentage(2.5) / .promptTip()
);
// Render dynamicQris.toString() with any QR widget, e.g. qr_flutter.

for (final issue in QrisValidator.validate(dynamicQris.raw)) {
  print(issue); // [error] crc_mismatch (tag 63): ...
}
```

## Disclaimer

This package implements the public EMVCo MPM structure used by QRIS. It is not
affiliated with Bank Indonesia or ASPI. Always test with your acquirer before
going to production.
