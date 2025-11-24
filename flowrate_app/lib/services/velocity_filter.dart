class VelocityFilter {
  final int windowSize;
  final List<double> _values = [];

  VelocityFilter({this.windowSize = 5});

  double addSample(double v) {
    _values.add(v);
    if (_values.length > windowSize) {
      _values.removeAt(0);
    }
    return _values.reduce((a, b) => a + b) / _values.length;
  }

  void reset() => _values.clear();
}
