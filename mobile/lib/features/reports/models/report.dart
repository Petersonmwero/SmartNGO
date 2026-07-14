class ReportImage {
  final int id;
  final String imageUrl;
  final String? caption;

  const ReportImage({required this.id, required this.imageUrl, this.caption});

  factory ReportImage.fromJson(Map<String, dynamic> json) => ReportImage(
        id: json['id'] as int,
        imageUrl: (json['image_url'] ?? '') as String,
        caption: json['caption'] as String?,
      );
}

/// DRF serialises DecimalFields as JSON strings (e.g. "-0.1022000"), so GPS
/// values must be parsed from either a number or a string — a plain
/// `as num?` cast throws and would fail the whole list parse.
double? _asDouble(dynamic value) =>
    value == null ? null : double.tryParse(value.toString());

class Report {
  final int id;
  final String title;
  final String description;
  final String status; // draft | submitted | approved
  final String reportType; // daily | weekly | monthly
  final String? dateSubmitted;
  final int projectId;
  final int officerId;
  final String? officerName;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final List<ReportImage> images;

  const Report({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.reportType,
    required this.projectId,
    required this.officerId,
    this.dateSubmitted,
    this.officerName,
    this.gpsLatitude,
    this.gpsLongitude,
    this.images = const [],
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as int,
        title: (json['title'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        status: (json['status'] ?? 'draft') as String,
        reportType: (json['report_type'] ?? 'daily') as String,
        dateSubmitted: json['date_submitted'] as String?,
        projectId: json['project'] as int,
        officerId: json['officer'] as int,
        officerName: json['officer_name'] as String?,
        gpsLatitude: _asDouble(json['gps_latitude']),
        gpsLongitude: _asDouble(json['gps_longitude']),
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => ReportImage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get statusLabel {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'approved':
        return 'Approved';
      default:
        return 'Draft';
    }
  }

  String get typeLabel =>
      reportType[0].toUpperCase() + reportType.substring(1);
}
