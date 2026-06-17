import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';

class ReportRepository {
  final ApiClient _api;

  ReportRepository(this._api);

  /// Create a draft report; returns its id.
  Future<int> createReport({
    required int projectId,
    required String title,
    required String reportType, // daily | weekly | monthly
    String description = '',
    double? latitude,
    double? longitude,
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
      final res = await _api.dio.post('/reports/', data: body);
      return res.data['id'] as int;
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
}
