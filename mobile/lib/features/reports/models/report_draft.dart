import 'dart:convert';

/// A report saved locally on the device, not yet sent to the server.
///
/// Drafts live in the local sqflite database (see `DraftStore`) so field
/// officers can capture work offline and submit once they have connectivity.
/// [photoPaths] stores the picked files' paths; loading them later is
/// best-effort since the OS may clear the picker's cache directory.
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
      );
}
