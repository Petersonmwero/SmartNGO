import 'dart:convert';

/// A report saved locally on the device, not yet sent to the server.
///
/// Drafts live in the local sqflite database (see `DraftStore`) so field
/// officers can capture work offline and submit once they have connectivity.
/// [photoPaths] stores the picked files' paths; loading them later is
/// best-effort since the OS may clear the picker's cache directory.
///
/// The structured donor-reporting fields are carried here too: a draft saved
/// in the field must not lose the spend and reach figures before it reaches
/// the server.
class ReportDraft {
  /// Local database row id; null until the draft is first saved.
  final int? id;
  final int projectId;
  final String projectName;
  final String title;
  final String description;
  final String reportType; // daily | weekly | monthly
  final double? latitude;
  final double? longitude;
  final List<String> photoPaths;
  final DateTime updatedAt;

  // ── Structured donor reporting ──────────────────────────────────────────
  final String activityType;
  final int? linkedPhaseId;
  final int? linkedMilestoneId;
  final String amountSpent;
  final String expenditureNotes;
  final int beneficiariesReached;
  final int beneficiariesMale;
  final int beneficiariesFemale;
  final int beneficiariesYouth;
  final String impactDescription;
  final String challengesFaced;
  final String recommendations;
  final String nextSteps;

  const ReportDraft({
    this.id,
    required this.projectId,
    required this.projectName,
    required this.title,
    this.description = '',
    this.reportType = 'daily',
    this.latitude,
    this.longitude,
    this.photoPaths = const [],
    required this.updatedAt,
    this.activityType = '',
    this.linkedPhaseId,
    this.linkedMilestoneId,
    this.amountSpent = '',
    this.expenditureNotes = '',
    this.beneficiariesReached = 0,
    this.beneficiariesMale = 0,
    this.beneficiariesFemale = 0,
    this.beneficiariesYouth = 0,
    this.impactDescription = '',
    this.challengesFaced = '',
    this.recommendations = '',
    this.nextSteps = '',
  });

  /// Row shape for the `report_drafts` table.
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'project_id': projectId,
        'project_name': projectName,
        'title': title,
        'description': description,
        'report_type': reportType,
        'gps_latitude': latitude,
        'gps_longitude': longitude,
        'photo_paths': jsonEncode(photoPaths),
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'activity_type': activityType,
        'linked_phase_id': linkedPhaseId,
        'linked_milestone_id': linkedMilestoneId,
        'amount_spent': amountSpent,
        'expenditure_notes': expenditureNotes,
        'beneficiaries_reached': beneficiariesReached,
        'beneficiaries_male': beneficiariesMale,
        'beneficiaries_female': beneficiariesFemale,
        'beneficiaries_youth': beneficiariesYouth,
        'impact_description': impactDescription,
        'challenges_faced': challengesFaced,
        'recommendations': recommendations,
        'next_steps': nextSteps,
      };

  factory ReportDraft.fromMap(Map<String, Object?> map) => ReportDraft(
        id: map['id'] as int?,
        projectId: map['project_id'] as int,
        projectName: map['project_name'] as String,
        title: map['title'] as String,
        description: (map['description'] as String?) ?? '',
        reportType: (map['report_type'] as String?) ?? 'daily',
        latitude: (map['gps_latitude'] as num?)?.toDouble(),
        longitude: (map['gps_longitude'] as num?)?.toDouble(),
        photoPaths: (jsonDecode((map['photo_paths'] as String?) ?? '[]')
                as List<dynamic>)
            .cast<String>(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (map['updated_at'] as int?) ?? 0),
        // Null-tolerant: rows written before the schema v2 upgrade have
        // NULL in every structured column.
        activityType: (map['activity_type'] as String?) ?? '',
        linkedPhaseId: map['linked_phase_id'] as int?,
        linkedMilestoneId: map['linked_milestone_id'] as int?,
        amountSpent: (map['amount_spent'] as String?) ?? '',
        expenditureNotes: (map['expenditure_notes'] as String?) ?? '',
        beneficiariesReached: (map['beneficiaries_reached'] as int?) ?? 0,
        beneficiariesMale: (map['beneficiaries_male'] as int?) ?? 0,
        beneficiariesFemale: (map['beneficiaries_female'] as int?) ?? 0,
        beneficiariesYouth: (map['beneficiaries_youth'] as int?) ?? 0,
        impactDescription: (map['impact_description'] as String?) ?? '',
        challengesFaced: (map['challenges_faced'] as String?) ?? '',
        recommendations: (map['recommendations'] as String?) ?? '',
        nextSteps: (map['next_steps'] as String?) ?? '',
      );

  ReportDraft copyWith({int? id}) => ReportDraft(
        id: id ?? this.id,
        projectId: projectId,
        projectName: projectName,
        title: title,
        description: description,
        reportType: reportType,
        latitude: latitude,
        longitude: longitude,
        photoPaths: photoPaths,
        updatedAt: updatedAt,
        activityType: activityType,
        linkedPhaseId: linkedPhaseId,
        linkedMilestoneId: linkedMilestoneId,
        amountSpent: amountSpent,
        expenditureNotes: expenditureNotes,
        beneficiariesReached: beneficiariesReached,
        beneficiariesMale: beneficiariesMale,
        beneficiariesFemale: beneficiariesFemale,
        beneficiariesYouth: beneficiariesYouth,
        impactDescription: impactDescription,
        challengesFaced: challengesFaced,
        recommendations: recommendations,
        nextSteps: nextSteps,
      );
}
