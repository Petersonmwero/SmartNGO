import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartngo/core/api_exception.dart';
import 'package:smartngo/core/paginated.dart';
import 'package:smartngo/features/projects/models/milestone.dart';
import 'package:smartngo/features/projects/models/phase.dart';
import 'package:smartngo/features/projects/project_repository.dart';
import 'package:smartngo/features/reports/draft_store.dart';
import 'package:smartngo/features/reports/models/report.dart';
import 'package:smartngo/features/reports/models/report_draft.dart';
import 'package:smartngo/features/reports/report_repository.dart';
import 'package:smartngo/features/reports/screens/submit_report_screen.dart';

/// Fake repository that records calls without touching the network.
class FakeReportRepository implements ReportRepository {
  bool createCalled = false;
  bool submitted = false;

  /// Call counters, for asserting the retry path stays idempotent.
  int createCount = 0;
  int uploadCount = 0;
  int submitAttempts = 0;
  int updateCount = 0;
  int? lastUpdatedId;
  final List<int> deletedImageIds = [];

  /// Structured payload of the last updateReport (edit) call.
  Map<String, dynamic> lastUpdate = const {};

  /// Make the first [failSubmitTimes] submit() calls throw, to simulate a
  /// connection that drops after the report was already created.
  int failSubmitTimes = 0;

  /// Make createReport throw, to simulate an unreachable server (offline).
  bool failCreate = false;

  /// Structured payload of the last createReport call, for assertions.
  Map<String, dynamic> lastCreate = const {};

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
  }) async {
    if (failCreate) {
      throw ApiException('Cannot reach the server', code: 'network_error');
    }
    createCalled = true;
    createCount++;
    lastCreate = {
      'activity_type': activityType,
      'linked_phase': linkedPhaseId,
      'linked_milestone': linkedMilestoneId,
      'amount_spent': amountSpent,
      'beneficiaries_reached': beneficiariesReached,
      'beneficiaries_male': beneficiariesMale,
      'beneficiaries_female': beneficiariesFemale,
      'beneficiaries_youth': beneficiariesYouth,
      'impact_description': impactDescription,
      'next_steps': nextSteps,
    };
    return 1;
  }

  @override
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
  }) async {
    updateCount++;
    lastUpdatedId = reportId;
    lastUpdate = {
      'title': title,
      'amount_spent': amountSpent,
      'beneficiaries_reached': beneficiariesReached,
      'linked_phase': linkedPhaseId,
      'impact_description': impactDescription,
    };
  }

  @override
  Future<void> uploadImage(int reportId,
      {required Uint8List bytes,
      required String filename,
      String caption = ''}) async {
    uploadCount++;
  }

  @override
  Future<void> deleteImage(int reportId, int imageId) async {
    deletedImageIds.add(imageId);
  }

  @override
  Future<void> submit(int reportId) async {
    submitAttempts++;
    if (submitAttempts <= failSubmitTimes) {
      throw ApiException('Connection lost', code: 'network_error');
    }
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

/// Fake project repository serving the Activity step's link pickers.
///
/// Only `phases` and `milestones` are reachable from this screen; the rest
/// of the interface is stubbed out via noSuchMethod so the fake does not
/// have to track every unrelated repository method.
class FakeProjectRepository implements ProjectRepository {
  final List<ProjectPhase> projectPhases;
  final List<Milestone> projectMilestones;

  FakeProjectRepository({
    this.projectPhases = const [],
    this.projectMilestones = const [],
  });

  @override
  Future<List<ProjectPhase>> phases(int projectId) async => projectPhases;

  @override
  Future<List<Milestone>> milestones(int projectId) async => projectMilestones;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

ProjectPhase _phase(int id, String name) => ProjectPhase(
      id: id,
      project: 3,
      phaseName: name,
      phaseType: 'implementation',
      allocatedBudget: 1000,
      spentBudget: 0,
      startDate: '2026-01-01',
      endDate: '2026-12-31',
      status: 'in_progress',
      description: '',
      utilizationPercentage: 0,
    );

Milestone _milestone(int id, String title) => Milestone(
      id: id,
      project: 3,
      title: title,
      description: '',
      status: 'pending',
    );

/// An existing server-side report, for the edit-mode tests.
Report _existingReport({String status = 'draft', int imageCount = 0}) => Report(
      id: 42,
      title: 'Original title',
      description: 'Original description',
      status: status,
      reportType: 'weekly',
      projectId: 3,
      projectName: 'WASH',
      officerId: 1,
      amountSpent: 5000,
      beneficiariesReached: 40,
      impactDescription: 'Some early impact.',
      images: [
        for (var i = 0; i < imageCount; i++)
          ReportImage(id: i + 1, imageUrl: 'https://x/$i.jpg'),
      ],
    );

Widget _harness(
  ReportRepository repo,
  DraftStore store, {
  ReportDraft? draft,
  Report? editing,
  ProjectRepository? projects,
}) {
  final Widget home;
  if (editing != null) {
    home = SubmitReportScreen(editing: editing);
  } else if (draft != null) {
    home = SubmitReportScreen(draft: draft);
  } else {
    home = SubmitReportScreen(projectId: 3, projectName: 'WASH');
  }
  return MultiProvider(
    providers: [
      Provider<ReportRepository>.value(value: repo),
      Provider<DraftStore>.value(value: store),
      Provider<ProjectRepository>.value(
          value: projects ?? FakeProjectRepository()),
    ],
    child: MaterialApp(home: home),
  );
}

/// Tap a widget after scrolling it into view — the Review step is taller
/// than the default 800x600 test surface, so its buttons start off-screen.
Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Advance the wizard from Details to Review, through Activity, Impact,
/// GPS and Photos.
Future<void> _goToReview(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
  }
}

void main() {
  late FakeReportRepository fake;
  late InMemoryDraftStore store;

  setUp(() {
    fake = FakeReportRepository();
    store = InMemoryDraftStore();
  });

  testWidgets('step 1 renders the report details fields', (tester) async {
    await tester.pumpWidget(_harness(fake, store));
    expect(find.byKey(const Key('report_title')), findsOneWidget);
    expect(find.byKey(const Key('report_type')), findsOneWidget);
    expect(find.text('WASH'), findsOneWidget);
  });

  testWidgets('blocks progression past step 1 when title is empty',
      (tester) async {
    await tester.pumpWidget(_harness(fake, store));

    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
    // Still on step 1: the title field is visible, the GPS step is not.
    expect(find.byKey(const Key('report_title')), findsOneWidget);
    expect(find.text('Capture Location'), findsNothing);
  });

  testWidgets('wizard walks Details → Activity → Impact → GPS → Photos → Review',
      (tester) async {
    await tester.pumpWidget(_harness(fake, store));
    await tester.enterText(
        find.byKey(const Key('report_title')), 'Site visit notes');

    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity_type')), findsOneWidget);

    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('impact_description')), findsOneWidget);

    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Capture Location'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Add photos'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit_button')), findsOneWidget);
    expect(find.byKey(const Key('save_draft_button')), findsOneWidget);
  });

  testWidgets('structured fields reach the API payload', (tester) async {
    await tester.pumpWidget(_harness(
      fake,
      store,
      projects: FakeProjectRepository(
        projectPhases: [_phase(7, 'Drilling')],
        projectMilestones: [_milestone(9, 'Borehole 12')],
      ),
    ));
    await tester.enterText(
        find.byKey(const Key('report_title')), 'Water point commissioned');
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    // Activity step: type, both links, spend and the reach breakdown.
    await tester.tap(find.byKey(const Key('activity_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Construction').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('linked_phase')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drilling').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount_spent')), '125000');
    await tester.enterText(
        find.byKey(const Key('beneficiaries_reached')), '300');
    await tester.enterText(find.byKey(const Key('beneficiaries_male')), '140');
    await tester.enterText(
        find.byKey(const Key('beneficiaries_female')), '160');
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('impact_description')), 'Walking time halved.');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();
    }
    await _tapKey(tester, 'submit_button');

    expect(fake.lastCreate['activity_type'], 'construction');
    expect(fake.lastCreate['linked_phase'], 7);
    expect(fake.lastCreate['amount_spent'], '125000');
    expect(fake.lastCreate['beneficiaries_reached'], 300);
    expect(fake.lastCreate['beneficiaries_male'], 140);
    expect(fake.lastCreate['beneficiaries_female'], 160);
    expect(fake.lastCreate['impact_description'], 'Walking time halved.');
    expect(fake.submitted, isTrue);
  });

  testWidgets('a gender split wider than the total blocks the step',
      (tester) async {
    await tester.pumpWidget(_harness(fake, store));
    await tester.enterText(find.byKey(const Key('report_title')), 'Training');
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('beneficiaries_reached')), '10');
    await tester.enterText(find.byKey(const Key('beneficiaries_male')), '6');
    await tester.enterText(find.byKey(const Key('beneficiaries_female')), '6');
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    // Still on Activity — the server would have rejected this anyway.
    expect(find.byKey(const Key('activity_type')), findsOneWidget);
    expect(
      find.text('Male plus female cannot exceed the total reached.'),
      findsOneWidget,
    );
  });

  testWidgets('warns when spend is entered without a phase to post it to',
      (tester) async {
    // Spend aggregates per phase, so an unlinked amount would be recorded
    // on the report but never reach the project's budget figures.
    await tester.pumpWidget(_harness(
      fake,
      store,
      projects: FakeProjectRepository(projectPhases: [_phase(7, 'Drilling')]),
    ));
    await tester.enterText(find.byKey(const Key('report_title')), 'Purchase');
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('will not count'), findsNothing);
    await tester.enterText(find.byKey(const Key('amount_spent')), '5000');
    await tester.pumpAndSettle();
    expect(find.textContaining('will not count'), findsOneWidget);

    await tester.tap(find.byKey(const Key('linked_phase')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drilling').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('will not count'), findsNothing);
  });

  testWidgets('link pickers degrade when a project has no phases',
      (tester) async {
    await tester.pumpWidget(_harness(fake, store));
    await tester.enterText(find.byKey(const Key('report_title')), 'Visit');
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    expect(find.text('No phases recorded for this project'), findsOneWidget);
    expect(
        find.text('No milestones recorded for this project'), findsOneWidget);
  });

  testWidgets('Save as Draft creates a server-side draft without submitting',
      (tester) async {
    await tester.pumpWidget(_harness(fake, store));

    await tester.enterText(
        find.byKey(const Key('report_title')), 'Site visit notes');
    await _goToReview(tester);
    await _tapKey(tester, 'save_draft_button');

    // Online: the draft is created on the server (not submitted) and no local
    // copy is kept.
    expect(fake.createCount, 1);
    expect(fake.submitted, isFalse);
    expect(fake.lastCreate['impact_description'], isNotNull);
    expect(await store.list(), isEmpty);
  });

  testWidgets('Save as Draft falls back to a local draft when offline',
      (tester) async {
    // createReport throws (server unreachable) on every attempt.
    fake.failCreate = true;
    await tester.pumpWidget(_harness(fake, store));

    await tester.enterText(
        find.byKey(const Key('report_title')), 'Offline notes');
    await _goToReview(tester);
    await _tapKey(tester, 'save_draft_button');

    final drafts = await store.list();
    expect(drafts, hasLength(1));
    expect(drafts.single.title, 'Offline notes');
    expect(fake.submitted, isFalse);
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

  testWidgets('a local (offline) draft keeps its structured data',
      (tester) async {
    // Force the offline fallback so the structured payload round-trips
    // through the local draft store.
    fake.failCreate = true;
    await tester.pumpWidget(_harness(fake, store));
    await tester.enterText(find.byKey(const Key('report_title')), 'Clinic day');
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount_spent')), '4500');
    await tester.enterText(
        find.byKey(const Key('beneficiaries_reached')), '80');
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('impact_description')), 'Clinic reopened.');

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();
    }
    await _tapKey(tester, 'save_draft_button');

    final saved = (await store.list()).single;
    expect(saved.amountSpent, '4500');
    expect(saved.beneficiariesReached, 80);
    expect(saved.impactDescription, 'Clinic reopened.');
  });

  testWidgets('resuming a draft pre-fills its structured fields',
      (tester) async {
    final draft = await store.save(ReportDraft(
      projectId: 3,
      projectName: 'WASH',
      title: 'Clinic day',
      updatedAt: DateTime(2026, 7, 22),
      activityType: 'training',
      amountSpent: '4500',
      beneficiariesReached: 80,
      beneficiariesFemale: 50,
      impactDescription: 'Clinic reopened.',
    ));

    await tester.pumpWidget(_harness(fake, store, draft: draft));
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('4500'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
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
    await _goToReview(tester);
    await _tapKey(tester, 'submit_button');

    expect(fake.submitted, isTrue);
    expect(await store.list(), isEmpty);
  });

  testWidgets('retrying a failed submit does not create a duplicate report',
      (tester) async {
    // The report is created, then the connection drops before the submit
    // transition; the officer taps Submit again.
    fake.failSubmitTimes = 1;
    await tester.pumpWidget(_harness(fake, store));
    await tester.enterText(
        find.byKey(const Key('report_title')), 'Site visit notes');
    await _goToReview(tester);

    // First attempt: report created, submit fails, still on Review.
    await _tapKey(tester, 'submit_button');
    expect(fake.createCount, 1);
    expect(fake.submitted, isFalse);
    expect(find.byKey(const Key('submit_button')), findsOneWidget);

    // Retry: resumes the same report — no second create — and succeeds.
    await _tapKey(tester, 'submit_button');
    expect(fake.createCount, 1);
    expect(fake.submitted, isTrue);
  });

  testWidgets('submit skips a draft photo the device can no longer read',
      (tester) async {
    // A resumed draft whose picked file the OS has since evicted from the
    // picker cache: reading it throws a filesystem error, which must not
    // abort an otherwise-valid submission.
    final draft = await store.save(ReportDraft(
      projectId: 3,
      projectName: 'WASH',
      title: 'Has a stale photo',
      updatedAt: DateTime(2026, 7, 22),
      photoPaths: const ['/tmp/smartngo-missing-photo.jpg'],
    ));

    await tester.pumpWidget(_harness(fake, store, draft: draft));
    await _goToReview(tester);

    // Submitting reads the evicted photo, which is real (failing) dart:io
    // that resolves on the real event loop — runAsync drives it, where
    // pumpAndSettle would only spin on the async gap.
    final submit = find.byKey(const Key('submit_button'));
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(submit);
      // Let the create → skip-photo → submit → delete-draft chain run.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // The unreadable photo is skipped rather than uploaded, and the report
    // still submits and clears the local draft.
    expect(fake.uploadCount, 0);
    expect(fake.submitted, isTrue);
    expect(await store.list(), isEmpty);
  });

  // ── Edit mode ─────────────────────────────────────────────────────────

  testWidgets('editing a report pre-fills the form and shows Edit Report',
      (tester) async {
    await tester.pumpWidget(
        _harness(fake, store, editing: _existingReport()));

    expect(find.text('Edit Report'), findsOneWidget);
    expect(find.text('Original title'), findsOneWidget);
    // Project is fixed, so no selector is shown.
    expect(find.byKey(const Key('project_selector')), findsNothing);
    expect(find.text('WASH'), findsOneWidget);
  });

  testWidgets('Save Changes on a draft PATCHes rather than creating',
      (tester) async {
    await tester.pumpWidget(
        _harness(fake, store, editing: _existingReport(status: 'draft')));
    await tester.enterText(
        find.byKey(const Key('report_title')), 'Revised title');
    await _goToReview(tester);
    await _tapKey(tester, 'save_changes_button');

    expect(fake.updateCount, 1);
    expect(fake.lastUpdatedId, 42);
    expect(fake.lastUpdate['title'], 'Revised title');
    expect(fake.createCount, 0);
    expect(fake.submitted, isFalse);
  });

  testWidgets('Submit while editing a draft PATCHes then submits',
      (tester) async {
    await tester.pumpWidget(
        _harness(fake, store, editing: _existingReport(status: 'draft')));
    await _goToReview(tester);
    await _tapKey(tester, 'submit_button');

    expect(fake.updateCount, 1);
    expect(fake.submitted, isTrue);
    expect(fake.createCount, 0);
  });

  testWidgets('editing a submitted report offers only Save Changes',
      (tester) async {
    await tester.pumpWidget(
        _harness(fake, store, editing: _existingReport(status: 'submitted')));
    await _goToReview(tester);

    // No Submit button — status is manager-driven and stays submitted.
    expect(find.byKey(const Key('submit_button')), findsNothing);
    expect(find.byKey(const Key('save_changes_button')), findsOneWidget);

    await _tapKey(tester, 'save_changes_button');
    expect(fake.updateCount, 1);
    expect(fake.submitted, isFalse);
  });

  testWidgets('editing surfaces already-attached photos as a count',
      (tester) async {
    await tester.pumpWidget(_harness(fake, store,
        editing: _existingReport(status: 'draft', imageCount: 2)));
    // Step through to the Photos step.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('2 already attached'), findsOneWidget);
  });

  testWidgets('removing an existing photo deletes it on save', (tester) async {
    await tester.pumpWidget(_harness(fake, store,
        editing: _existingReport(status: 'draft', imageCount: 2)));
    // Step to the Photos step and remove the first existing image (id 1).
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('remove_existing_1')));
    await tester.pumpAndSettle();
    // One removed → "1 already attached".
    expect(find.textContaining('1 already attached'), findsOneWidget);

    // On to Review and save.
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'save_changes_button');

    expect(fake.deletedImageIds, contains(1));
    expect(fake.deletedImageIds, isNot(contains(2)));
    expect(fake.updateCount, 1);
  });
}
