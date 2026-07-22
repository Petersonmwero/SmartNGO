class ReportImage {
  final int id;
  final String imageUrl;
  final String? caption;

  const ReportImage({required this.id, required this.imageUrl, this.caption});

  // The API serialises the ImageField as `image` (absolute URL); the DB
  // column is image_url, which older payloads exposed directly.
  factory ReportImage.fromJson(Map<String, dynamic> json) => ReportImage(
        id: json['id'] as int,
        imageUrl: (json['image'] ?? json['image_url'] ?? '') as String,
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
  final String? projectName;
  final int officerId;
  final String? officerName;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final List<ReportImage> images;

  // ── Structured donor reporting ──────────────────────────────────────────
  // Defaulted throughout: reports filed before these fields existed, and
  // narrative-only reports, parse to empty values rather than failing.
  final String activityType;
  final int? linkedPhase;
  final int? linkedMilestone;
  final double amountSpent;
  final String expenditureNotes;
  final int beneficiariesReached;
  final int beneficiariesMale;
  final int beneficiariesFemale;
  final int beneficiariesYouth;
  final String impactDescription;
  final String challengesFaced;
  final String recommendations;
  final String nextSteps;

  /// Set when an approved report's figures posted to the project ledger.
  final String? postedAt;

  const Report({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.reportType,
    required this.projectId,
    required this.officerId,
    this.dateSubmitted,
    this.projectName,
    this.officerName,
    this.gpsLatitude,
    this.gpsLongitude,
    this.images = const [],
    this.activityType = '',
    this.linkedPhase,
    this.linkedMilestone,
    this.amountSpent = 0,
    this.expenditureNotes = '',
    this.beneficiariesReached = 0,
    this.beneficiariesMale = 0,
    this.beneficiariesFemale = 0,
    this.beneficiariesYouth = 0,
    this.impactDescription = '',
    this.challengesFaced = '',
    this.recommendations = '',
    this.nextSteps = '',
    this.postedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as int,
        title: (json['title'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        status: (json['status'] ?? 'draft') as String,
        reportType: (json['report_type'] ?? 'daily') as String,
        dateSubmitted: json['date_submitted'] as String?,
        projectId: json['project'] as int,
        projectName: json['project_name'] as String?,
        officerId: json['officer'] as int,
        officerName: json['officer_name'] as String?,
        gpsLatitude: _asDouble(json['gps_latitude']),
        gpsLongitude: _asDouble(json['gps_longitude']),
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => ReportImage.fromJson(e as Map<String, dynamic>))
            .toList(),
        activityType: (json['activity_type'] ?? '') as String,
        linkedPhase: json['linked_phase'] as int?,
        linkedMilestone: json['linked_milestone'] as int?,
        amountSpent: _asDouble(json['amount_spent']) ?? 0,
        expenditureNotes: (json['expenditure_notes'] ?? '') as String,
        beneficiariesReached: (json['beneficiaries_reached'] ?? 0) as int,
        beneficiariesMale: (json['beneficiaries_male'] ?? 0) as int,
        beneficiariesFemale: (json['beneficiaries_female'] ?? 0) as int,
        beneficiariesYouth: (json['beneficiaries_youth'] ?? 0) as int,
        impactDescription: (json['impact_description'] ?? '') as String,
        challengesFaced: (json['challenges_faced'] ?? '') as String,
        recommendations: (json['recommendations'] ?? '') as String,
        nextSteps: (json['next_steps'] ?? '') as String,
        postedAt: json['posted_at'] as String?,
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

  /// True when the report carries any structured donor-reporting content,
  /// i.e. there is something for the detail screen to show.
  bool get hasStructuredData =>
      activityType.isNotEmpty ||
      amountSpent > 0 ||
      beneficiariesReached > 0 ||
      hasNarrative;

  bool get hasNarrative =>
      impactDescription.isNotEmpty ||
      challengesFaced.isNotEmpty ||
      recommendations.isNotEmpty ||
      nextSteps.isNotEmpty;
}
