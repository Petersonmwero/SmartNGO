import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartngo/core/paginated.dart';
import 'package:smartngo/features/reports/draft_store.dart';
import 'package:smartngo/features/reports/models/report.dart';
import 'package:smartngo/features/reports/models/report_draft.dart';
import 'package:smartngo/features/reports/report_repository.dart';
import 'package:smartngo/features/reports/screens/submit_report_screen.dart';

/// Fake repository that records calls without touching the network.
class FakeReportRepository implements ReportRepository {
  bool createCalled = false;
  bool submitted = false;

  @override
  Future<Paginated<Report>> list({int? projectId, String? status}) async =>
      Paginated(count: 0, results: []);

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

  @override
  Future<Report> get(int id) async => const Report(
        id: 1,
        title: '',
        description: '',
        status: 'draft',
        reportType: 'daily',
        projectId: 0,
        officerId: 0,
      );

  @override
  Future<void> approve(int reportId) async {}
}

Widget _harness(ReportRepository repo, DraftStore store,
        {ReportDraft? draft}) =>
    MultiProvider(
      providers: [
        Provider<ReportRepository>.value(value: repo),
        Provider<DraftStore>.value(value: store),
      ],
      child: MaterialApp(
        home: SubmitReportScreen(projectId: 3, projectName: 'WASH', draft: draft),
      ),
    );

void main() {
  late FakeReportRepository fake;
  late InMemoryDraftStore store;

  setUp(() {
    fake = FakeReportRepository();
    store = InMemoryDraftStore();
  });

  testWidgets('renders the report form fields', (tester) async {
    await tester.pumpWidget(_harness(fake, store));
    expect(find.byKey(const Key('report_title')), findsOneWidget);
    expect(find.byKey(const Key('report_type')), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
  });

  testWidgets('blocks submit when title is empty', (tester) async {
    await tester.pumpWidget(_harness(fake, store));

    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
    expect(fake.createCalled, isFalse);
  });

  testWidgets('Save draft stores the form locally without calling the API',
      (tester) async {
    await tester.pumpWidget(_harness(fake, store));

    await tester.enterText(
        find.byKey(const Key('report_title')), 'Site visit notes');
    await tester.tap(find.byKey(const Key('save_draft_button')));
    await tester.pumpAndSettle();

    final drafts = await store.list();
    expect(drafts, hasLength(1));
    expect(drafts.single.title, 'Site visit notes');
    expect(drafts.single.projectId, 3);
    expect(fake.createCalled, isFalse);
  });

  testWidgets('resuming a draft pre-fills the form', (tester) async {
    final draft = await store.save(ReportDraft(
      projectId: 3,
      projectName: 'WASH',
      title: 'Half-finished report',
      description: 'Two boreholes checked',
      reportType: 'weekly',
      updatedAt: DateTime(2026, 7, 13),
    ));

    await tester.pumpWidget(_harness(fake, store, draft: draft));

    expect(find.text('Half-finished report'), findsOneWidget);
    expect(find.text('Two boreholes checked'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
  });

  testWidgets('submitting a resumed draft deletes it locally',
      (tester) async {
    final draft = await store.save(ReportDraft(
      projectId: 3,
      projectName: 'WASH',
      title: 'Ready to send',
      updatedAt: DateTime(2026, 7, 13),
    ));

    await tester.pumpWidget(_harness(fake, store, draft: draft));
    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pumpAndSettle();

    expect(fake.submitted, isTrue);
    expect(await store.list(), isEmpty);
  });
}
