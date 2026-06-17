import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartngo/features/reports/report_repository.dart';
import 'package:smartngo/features/reports/screens/submit_report_screen.dart';

/// Fake repository that records calls without touching the network.
class FakeReportRepository implements ReportRepository {
  bool createCalled = false;
  bool submitted = false;

  @override
  Future<int> createReport({
    required int projectId,
    required String title,
    required String reportType,
    String description = '',
    double? latitude,
    double? longitude,
  }) async {
    createCalled = true;
    return 1;
  }

  @override
  Future<void> uploadImage(int reportId,
      {required Uint8List bytes, required String filename, String caption = ''}) async {}

  @override
  Future<void> submit(int reportId) async {
    submitted = true;
  }
}

Widget _harness(ReportRepository repo) => Provider<ReportRepository>.value(
      value: repo,
      child: const MaterialApp(
        home: SubmitReportScreen(projectId: 3, projectName: 'WASH'),
      ),
    );

void main() {
  testWidgets('renders the report form fields', (tester) async {
    await tester.pumpWidget(_harness(FakeReportRepository()));
    expect(find.byKey(const Key('report_title')), findsOneWidget);
    expect(find.byKey(const Key('report_type')), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
  });

  testWidgets('blocks submit when title is empty', (tester) async {
    final fake = FakeReportRepository();
    await tester.pumpWidget(_harness(fake));

    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
    expect(fake.createCalled, isFalse);
  });
}
