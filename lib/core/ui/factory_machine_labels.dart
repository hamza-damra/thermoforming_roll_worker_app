/// Human-readable thermoforming machine labels for the factory floor.
///
/// Uses 1-based index to match [RollWorkerHomeScreen.lineIndex] and tab order.
class FactoryMachineLabels {
  FactoryMachineLabels._();

  static const List<String> _ordered = <String>[
    'ماكنة أ',
    'ماكنة ب',
    'ماكنة ت',
    'ماكنة ث',
    'ماكنة ج',
  ];

  /// [oneBasedIndex] is 1 for the first active machine, 2 for the second, etc.
  static String titleForOneBasedIndex(int oneBasedIndex) {
    final int i = oneBasedIndex - 1;
    if (i >= 0 && i < _ordered.length) return _ordered[i];
    return 'ماكنة $oneBasedIndex';
  }

  /// 0-based list index (e.g. picker row order).
  static String titleForZeroBasedIndex(int zeroBasedIndex) {
    return titleForOneBasedIndex(zeroBasedIndex + 1);
  }
}
