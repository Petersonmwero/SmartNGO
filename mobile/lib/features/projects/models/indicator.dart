class Indicator {
  final int id;
  final int project;
  final String indicatorName;
  final String targetValue;
  final String currentValue;
  final String unit;
  final double? progressPercent;

  const Indicator({
    required this.id,
    required this.project,
    required this.indicatorName,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    this.progressPercent,
  });

  factory Indicator.fromJson(Map<String, dynamic> json) => Indicator(
        id: json['id'] as int,
        project: json['project'] as int,
        indicatorName: (json['indicator_name'] ?? '') as String,
        targetValue: (json['target_value'] ?? '0').toString(),
        currentValue: (json['current_value'] ?? '0').toString(),
        unit: (json['unit'] ?? '') as String,
        progressPercent: (json['progress_percent'] as num?)?.toDouble(),
      );

  /// Progress as a 0..1 fraction for a progress bar.
  double get fraction => ((progressPercent ?? 0) / 100).clamp(0.0, 1.0);
}
