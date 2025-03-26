import 'dart:math';

/// Extension methods for [double]
extension DoubleExt on double {
  /// Rounds a [double] to a specified number of decimal places.
  /// To [int] if the result is an integer.
  num toPrecision(int fractionDigits) {
    if (_canBeInt) return toInt();

    // Use a lookup table for common powers of 10
    double mod;
    switch (fractionDigits) {
      case 0:
        mod = 1;
      case 1:
        mod = 10;
      case 2:
        mod = 100;
      case 3:
        mod = 1000;
      case 4:
        mod = 10000;
      case 5:
        mod = 100000;
      case 6:
        mod = 1000000;
      default:
        mod = pow(10, fractionDigits.toDouble()).toDouble();
    }

    final calculation = (this * mod).round().toDouble() / mod;
    return calculation._canBeInt ? calculation.toInt() : calculation;
  }

  bool get _canBeInt => this % 1 == 0;

  num get toIntIfTrue => _canBeInt ? toInt() : this;
}
