import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/paginated.dart';
import 'models/report.dart';

class ReportRepository {
  final ApiClient _api;

  ReportRepository(this._api);

  Future<Report> get(int id) {
    return apiGuard(() async {
      final res = await _api.dio.get('/reports/$id/');
      return Report.fromJson(res.data as Map<String, dynamic>);
    });
  }

  Future<Paginated<Report>> list({int? projectId, String? status}) {
    return apiGuard(() async {
      final params = <String, dynamic>{};
      if (projectId != null) params['project_id'] = projectId;
      if (status != null) params['status'] = status;
      final res = await _api.dio.get('/reports/', queryParameters: params);
      return Paginated.fromJson(
        res.data as Map<String, dynamic>,
        (json) => Report.fromJson(json),
      );
    });
  }

  /// Create a draft report; returns its id.
  ///
  /// The structured donor-reporting arguments are all optional — a
  /// narrative-only report stays valid — and empty ones are left out of the
  /// body entirely so the server's defaults apply.
  Future<int> createReport({
    required int projectId,
    required String title,
    required String reportType, // daily | weekly | monthly
    String description = '',
    double? latitude,
    double? longitude,
    String activityType = '',
    int? linkedPhaseId,
    int? linkedMilestoneId,
    String amountSpent = '',
    String expenditureNotes = '',
    int beneficiariesReached = 0,
    int beneficiariesMale = 0,
    int beneficiariesFemale = 0,
    int beneficiariesYouth = 0,
    String impactDescription = '',
    String challengesFaced = '',
    String recommendations = '',
    String nextSteps = '',
  }) {
    return apiGuard(() async {
      final body = <String, dynamic>{
        'project': projectId,
        'title': title,
        'report_type': reportType,
        'description': description,
      };
      if (latitude != null) body['gps_latitude'] = latitude;
      if (longitude != null) body['gps_longitude'] = longitude;
      if (activityType.isNotEmpty) body['activity_type'] = activityType;
      if (linkedPhaseId != null) body['linked_phase'] = linkedPhaseId;
      if (linkedMilestoneId != null) body['linked_milestone'] = linkedMilestoneId;
      if (amountSpent.isNotEmpty) body['amount_spent'] = amountSpent;
      if (expenditureNotes.isNotEmpty) {
        body['expenditure_notes'] = expenditureNotes;
      }
      if (beneficiariesReached > 0) {
        body['beneficiaries_reached'] = beneficiariesReached;
        body['beneficiaries_male'] = beneficiariesMale;
        body['beneficiaries_female'] = beneficiariesFemale;
        body['beneficiaries_youth'] = beneficiariesYouth;
      }
      if (impactDescription.isNotEmpty) {
        body['impact_description'] = impactDescription;
      }
      if (challengesFaced.isNotEmpty) body['challenges_faced'] = challengesFaced;
      if (recommendations.isNotEmpty) body['recommendations'] = recommendations;
      if (nextSteps.isNotEmpty) body['next_steps'] = nextSteps;
      final res = await _api.dio.post('/reports/', data: body);
      return res.data['id'] as int;
    });
  }

  /// Update an existing report's editable content (PATCH).
  ///
  /// Unlike [createReport], empty structured values are sent explicitly so an
  /// officer can *clear* a field they previously filled — a blank amount
  /// becomes 0, blank counts become 0, and cleared links are set to null.
  /// GPS is only sent when re-captured, so an edit never wipes an existing fix.
  /// `status` is read-only server-side, so this never changes the workflow
  /// state — a draft stays a draft, a submitted report stays submitted.
  Future<void> updateReport(
    int reportId, {
    required String title,
    required String reportType,
    String description = '',
    double? latitude,
    double? longitude,
    String activityType = '',
    int? linkedPhaseId,
    int? linkedMilestoneId,
    String amountSpent = '',
    String expenditureNotes = '',
    int beneficiariesReached = 0,
    int beneficiariesMale = 0,
    int beneficiariesFemale = 0,
    int beneficiariesYouth = 0,
    String impactDescription = '',
    String challengesFaced = '',
    String recommendations = '',
    String nextSteps = '',
  }) {
    return apiGuard(() async {
      final body = <String, dynamic>{
        'title': title,
        'report_type': reportType,
        'description': description,
        'activity_type': activityType,
        'linked_phase': linkedPhaseId,
        'linked_milestone': linkedMilestoneId,
        'amount_spent': amountSpent.isEmpty ? '0' : amountSpent,
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
      if (latitude != null) body['gps_latitude'] = latitude;
      if (longitude != null) body['gps_longitude'] = longitude;
      await _api.dio.patch('/reports/$reportId/', data: body);
    });
  }

  /// Upload one image to a report (multipart).
  Future<void> uploadImage(
    int reportId, {
    required Uint8List bytes,
    required String filename,
    String caption = '',
  }) {
    return apiGuard(() async {
      final form = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes, filename: filename),
        if (caption.isNotEmpty) 'caption': caption,
      });
      await _api.dio.post('/reports/$reportId/images/', data: form);
    });
  }

  /// Transition a draft report to submitted.
  Future<void> submit(int reportId) {
    return apiGuard(() async {
      await _api.dio.post('/reports/$reportId/submit/');
    });
  }

  /// Approve a submitted report (manager/admin only).
  Future<void> approve(int reportId) {
    return apiGuard(() async {
      await _api.dio.post('/reports/$reportId/approve/');
    });
  }
}
