class SetupProfile {
  SetupProfile({
    required this.id,
    required this.magnetCount,
    required this.magnetSizeMm,
    required this.pipeDiameterMm,
    required this.electrodeType,
    required this.couplingMode,
    this.notes = '',
  });

  final String id;
  final int magnetCount;
  final double magnetSizeMm;
  final double pipeDiameterMm;
  final ElectrodeType electrodeType;
  final CouplingMode couplingMode;
  final String notes;

  String get label =>
      '${magnetSizeMm.toStringAsFixed(0)} mm × $magnetCount · ${pipeDiameterMm.toStringAsFixed(0)} mm pipe';
}

enum ElectrodeType { sheet, pin }

enum CouplingMode { direct, capacitive }
