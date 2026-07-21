import 'package:flutter/material.dart';

/// The kinds of field activity a report can document.
///
/// Values mirror `Report.ActivityType` on the backend exactly — the API
/// rejects anything else — so this list is the client-side copy of that
/// enum, with the icon and label the form shows.
class ReportActivityType {
  final String value;
  final String label;
  final IconData icon;

  const ReportActivityType(this.value, this.label, this.icon);

  static const all = <ReportActivityType>[
    ReportActivityType('training', 'Training', Icons.school_outlined),
    ReportActivityType(
        'distribution', 'Distribution', Icons.inventory_2_outlined),
    ReportActivityType(
        'construction', 'Construction', Icons.construction_outlined),
    ReportActivityType(
        'survey', 'Survey / Assessment', Icons.fact_check_outlined),
    ReportActivityType(
        'community_meeting', 'Community Meeting', Icons.groups_outlined),
    ReportActivityType(
        'monitoring', 'Monitoring Visit', Icons.visibility_outlined),
    ReportActivityType('other', 'Other', Icons.more_horiz),
  ];

  /// Human label for a stored value; falls back to the raw value so an
  /// activity type added server-side still renders.
  static String labelFor(String? value) {
    if (value == null || value.isEmpty) return 'Not specified';
    for (final type in all) {
      if (type.value == value) return type.label;
    }
    return value;
  }
}
