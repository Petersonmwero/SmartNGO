import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/features/reports/models/report.dart';

void main() {
  test('parses DRF string-encoded GPS decimals', () {
    // DRF serialises DecimalField as a JSON string; a naive num cast used
    // to throw here and broke the whole reports list ("Failed to load").
    final report = Report.fromJson({
      'id': 1,
      'project': 2,
      'officer': 3,
      'title': 'GPS test',
      'description': '',
      'status': 'submitted',
      'report_type': 'daily',
      'gps_latitude': '-0.1022000',
      'gps_longitude': '34.7617000',
    });

    expect(report.gpsLatitude, closeTo(-0.1022, 1e-9));
    expect(report.gpsLongitude, closeTo(34.7617, 1e-9));
  });

  test('parses numeric and null GPS values', () {
    final numeric = Report.fromJson({
      'id': 1,
      'project': 2,
      'officer': 3,
      'title': 't',
      'status': 'draft',
      'report_type': 'daily',
      'gps_latitude': -1.21811,
      'gps_longitude': 36.88739,
    });
    expect(numeric.gpsLatitude, closeTo(-1.21811, 1e-9));

    final none = Report.fromJson({
      'id': 2,
      'project': 2,
      'officer': 3,
      'title': 't',
      'status': 'draft',
      'report_type': 'daily',
    });
    expect(none.gpsLatitude, isNull);
    expect(none.gpsLongitude, isNull);
  });
}
