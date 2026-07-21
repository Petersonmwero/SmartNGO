import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
    createCalled = true;
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

Widget _harness(
  ReportRepository repo,
  DraftStore store, {
  ReportDraft? draft,
  ProjectRepository? projects,
}) =>
    MultiProvider(
      providers: [
        Provider<ReportRepository>.value(value: repo),
        Provider<DraftStore>.value(value: store),
        Provider<ProjectRepository>.value(
            value: projects ?? FakeProjectRepository()),
      ],
      child: MaterialApp(
        home: draft == null
            ? SubmitReportScreen(projectId: 3, projectName: 'WASH')
            : SubmitReportScreen(draft: draft),
      ),
    );

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

  testWidgets('Save draft stores the form locally without calling the API',
      (tester) async {
    await tester.pumpWidget(_harness(fake, store));

    await tester.enterText(
        find.byKey(const Key('report_title')), 'Site visit notes');
    await _goToReview(tester);
    await _tapKey(tester, 'save_draft_button');

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

  testWidgets('a draft keeps its structured data across save and resume',
      (tester) async {
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
}
