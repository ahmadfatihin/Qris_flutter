/// Tip or convenience fee indicator (QRIS tags 55, 56, 57).
sealed class QrisFee {
  const QrisFee();

  /// Tag 55 = `01`: the payer's app prompts the customer to enter a tip.
  const factory QrisFee.promptTip() = QrisPromptTip;

  /// Tag 55 = `02`, tag 56: a fixed convenience fee in IDR.
  const factory QrisFee.fixed(num amount) = QrisFixedFee;

  /// Tag 55 = `03`, tag 57: a percentage convenience fee, e.g. `2.5` = 2.5%.
  const factory QrisFee.percentage(num percent) = QrisPercentageFee;
}

final class QrisPromptTip extends QrisFee {
  const QrisPromptTip();

  @override
  bool operator ==(Object other) => other is QrisPromptTip;
  @override
  int get hashCode => 55;
  @override
  String toString() => 'QrisFee.promptTip()';
}

final class QrisFixedFee extends QrisFee {
  const QrisFixedFee(this.amount);
  final num amount;

  @override
  bool operator ==(Object other) =>
      other is QrisFixedFee && other.amount == amount;
  @override
  int get hashCode => Object.hash(56, amount);
  @override
  String toString() => 'QrisFee.fixed($amount)';
}

final class QrisPercentageFee extends QrisFee {
  const QrisPercentageFee(this.percent);
  final num percent;

  @override
  bool operator ==(Object other) =>
      other is QrisPercentageFee && other.percent == percent;
  @override
  int get hashCode => Object.hash(57, percent);
  @override
  String toString() => 'QrisFee.percentage($percent)';
}
