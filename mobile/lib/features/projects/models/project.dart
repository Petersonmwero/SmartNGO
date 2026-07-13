import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class Project {
  final int id;
  final String projectName;
  final String description;
  final String budget;
  final String? startDate;
  final String? endDate;
  final String status;
  final int ngo;

  const Project({
    required this.id,
    required this.projectName,
    required this.description,
    required this.budget,
    required this.status,
    required this.ngo,
    this.startDate,
    this.endDate,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as int,
        projectName: (json['project_name'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        budget: (json['budget'] ?? '0').toString(),
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        status: (json['status'] ?? '') as String,
        ngo: json['ngo'] as int,
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

  /// Timeline progress: fraction of the project duration already elapsed
  /// (0.0 before start, 1.0 after end). The schema stores no completion
  /// percentage, so elapsed time is the honest proxy shown on cards.
  double get timelineProgress {
    final start = DateTime.tryParse(startDate ?? '');
    final end = DateTime.tryParse(endDate ?? '');
    if (start == null || end == null || !end.isAfter(start)) return 0;
    final total = end.difference(start).inDays;
    final elapsed = DateTime.now().difference(start).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
