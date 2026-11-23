/// Thrown when a string is not a structurally valid QRIS / EMVCo payload.
class QrisFormatException implements Exception {
  const QrisFormatException(this.message, {this.offset});

  /// Human readable description of the problem.
  final String message;

  /// Character offset in the input where the problem was found, if known.
  final int? offset;

  @override
  String toString() => offset == null
      ? 'QrisFormatException: $message'
      : 'QrisFormatException: $message (at offset $offset)';
}
