import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'phase.dart';

class Project {
  final int id;
  final String projectName;
  final String description;
  final String budget;
  final String? startDate;
  final String? endDate;
  final String status;
  final int ngo;

  // Weighted Composite Progress (EVM) — computed server-side.
  final double progressPercentage;
  final double financialProgress;
  final double physicalProgress;
  final double timeProgress;
  final double? costPerformanceIndex;
  final double? schedulePerformanceIndex;
  final String healthStatus; // healthy | at_risk | critical | not_started
  final double totalSpent;
  final double budgetRemaining;
  final List<ProjectPhase> phases;

  const Project({
    required this.id,
    required this.projectName,
    required this.description,
    required this.budget,
    required this.status,
    required this.ngo,
    this.startDate,
    this.endDate,
    this.progressPercentage = 0,
    this.financialProgress = 0,
    this.physicalProgress = 0,
    this.timeProgress = 0,
    this.costPerformanceIndex,
    this.schedulePerformanceIndex,
    this.healthStatus = 'not_started',
    this.totalSpent = 0,
    this.budgetRemaining = 0,
    this.phases = const [],
  });

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as int,
        projectName: (json['project_name'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        budget: (json['budget'] ?? '0').toString(),
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        status: (json['status'] ?? '') as String,
        ngo: json['ngo'] as int,
        progressPercentage: ProjectPhase.asDouble(json['progress_percentage']),
        financialProgress: ProjectPhase.asDouble(json['financial_progress']),
        physicalProgress: ProjectPhase.asDouble(json['physical_progress']),
        timeProgress: ProjectPhase.asDouble(json['time_progress']),
        costPerformanceIndex:
            _asNullableDouble(json['cost_performance_index']),
        schedulePerformanceIndex:
            _asNullableDouble(json['schedule_performance_index']),
        healthStatus: (json['health_status'] ?? 'not_started') as String,
        totalSpent: ProjectPhase.asDouble(json['total_spent']),
        budgetRemaining: ProjectPhase.asDouble(json['budget_remaining']),
        phases: ((json['phases'] ?? []) as List)
            .map((p) => ProjectPhase.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  String get statusLabel {
    switch (status) {
      case 'planning':
        return 'Planning';
      case 'active':
        return 'Active';
      case 'on_hold':
        return 'On Hold';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.info;
      case 'on_hold':
        return AppColors.neutral;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  /// Composite progress as a 0.0–1.0 fraction for progress bars.
  double get compositeFraction => (progressPercentage / 100).clamp(0.0, 1.0);

  /// Mini breakdown line shown under list progress bars.
  String get dimensionSummary =>
      'F: ${financialProgress.round()}% · P: ${physicalProgress.round()}% · '
      'T: ${timeProgress.round()}%';

  String get healthLabel => switch (healthStatus) {
        'healthy' => 'HEALTHY',
        'at_risk' => 'AT RISK',
        'critical' => 'CRITICAL',
        _ => 'NOT STARTED',
      };

  Color get healthColor => switch (healthStatus) {
        'healthy' => AppColors.success,
        'at_risk' => AppColors.warning,
        'critical' => AppColors.danger,
        _ => AppColors.neutral,
      };

  /// Timeline progress: fraction of the project duration already elapsed
  /// (0.0 before start, 1.0 after end). Kept for header "% elapsed" badges;
  /// progress bars now use the server-computed composite instead.
  double get timelineProgress {
    final start = DateTime.tryParse(startDate ?? '');
    final end = DateTime.tryParse(endDate ?? '');
    if (start == null || end == null || !end.isAfter(start)) return 0;
    final total = end.difference(start).inDays;
    final elapsed = DateTime.now().difference(start).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// Total project duration in days, or null when dates are missing.
  int? get totalDays {
    final start = DateTime.tryParse(startDate ?? '');
    final end = DateTime.tryParse(endDate ?? '');
    if (start == null || end == null || !end.isAfter(start)) return null;
    return end.difference(start).inDays;
  }

  /// Days elapsed since the start, clamped to the project duration.
  int? get elapsedDays {
    final start = DateTime.tryParse(startDate ?? '');
    final total = totalDays;
    if (start == null || total == null) return null;
    return DateTime.now().difference(start).inDays.clamp(0, total);
  }
}
