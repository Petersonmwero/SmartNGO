import 'package:flutter/material.dart';

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
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'on_hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
