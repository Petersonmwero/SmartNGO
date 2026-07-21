/// Budget phase of a project — feeds the financial dimension of the
/// weighted composite (EVM) progress model.
class ProjectPhase {
  final int id;
  final int project;
  final String phaseName;
  final String phaseType; // planning | implementation | monitoring | closeout
  final double allocatedBudget;

  /// Baseline spend typed in by a manager, before report-based tracking.
  final double openingSpend;

  /// Spend posted by approved field reports linked to this phase.
  final double reportedSpend;

  /// Actual spend: [openingSpend] + [reportedSpend], computed server-side.
  final double spentBudget;
  final String startDate;
  final String endDate;
  final String status; // not_started | in_progress | completed
  final String description;
  final double utilizationPercentage;

  const ProjectPhase({
    required this.id,
    required this.project,
    required this.phaseName,
    required this.phaseType,
    required this.allocatedBudget,
    this.openingSpend = 0,
    this.reportedSpend = 0,
    required this.spentBudget,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.description,
    required this.utilizationPercentage,
  });

  /// DRF serialises DecimalFields as JSON strings; accept string or number.
  static double asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  factory ProjectPhase.fromJson(Map<String, dynamic> json) => ProjectPhase(
        id: json['id'] as int,
        project: (json['project'] ?? 0) as int,
        phaseName: (json['phase_name'] ?? '') as String,
        phaseType: (json['phase_type'] ?? '') as String,
        allocatedBudget: asDouble(json['allocated_budget']),
        openingSpend: asDouble(json['opening_spend']),
        reportedSpend: asDouble(json['reported_spend']),
        spentBudget: asDouble(json['spent_budget']),
        startDate: (json['start_date'] ?? '') as String,
        endDate: (json['end_date'] ?? '') as String,
        status: (json['status'] ?? 'not_started') as String,
        description: (json['description'] ?? '') as String,
        utilizationPercentage: asDouble(json['utilization_percentage']),
      );

  String get statusLabel => switch (status) {
        'not_started' => 'Not Started',
        'in_progress' => 'In Progress',
        'completed' => 'Completed',
        _ => status,
      };

  String get typeLabel => switch (phaseType) {
        'planning' => 'Planning',
        'implementation' => 'Implementation',
        'monitoring' => 'Monitoring & Evaluation',
        'closeout' => 'Closeout',
        _ => phaseType,
      };
}
