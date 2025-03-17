import 'dart:math';

extension DoubleExt on double {
  num toPrecision(int fractionDigits) {
    if (_canBeInt) return toInt();
    final mod = pow(10, fractionDigits.toDouble()).toDouble();
    final calculation = (this * mod).round().toDouble() / mod;
    return calculation._canBeInt ? calculation.toInt() : calculation;
  }

  bool get _canBeInt => this % 1 == 0;

  num get toIntIfTrue => _canBeInt ? toInt() : this;
}
