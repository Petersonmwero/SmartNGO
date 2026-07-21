import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/features/projects/models/impact_summary.dart';
import 'package:smartngo/features/projects/widgets/impact_card.dart';
import 'package:smartngo/features/reports/models/report.dart';

Map<String, dynamic> _reportJson({Map<String, dynamic> extra = const {}}) => {
      'id': 1,
      'title': 'Water point commissioned',
      'description': '',
      'status': 'approved',
      'report_type': 'monthly',
      'project': 3,
      'officer': 2,
      ...extra,
    };

void main() {
  group('Report structured parsing', () {
    test('reads the structured payload off the API response', () {
      final report = Report.fromJson(_reportJson(extra: {
        'activity_type': 'construction',
        'linked_phase': 7,
        'linked_milestone': 9,
        // DRF sends decimals as strings.
        'amount_spent': '125000.00',
        'beneficiaries_reached': 300,
        'beneficiaries_male': 140,
        'beneficiaries_female': 160,
        'beneficiaries_youth': 90,
        'impact_description': 'Walking time halved.',
        'posted_at': '2026-07-22T09:00:00Z',
      }));

      expect(report.activityType, 'construction');
      expect(report.linkedPhase, 7);
      expect(report.linkedMilestone, 9);
      expect(report.amountSpent, 125000.0);
      expect(report.beneficiariesReached, 300);
      expect(report.beneficiariesYouth, 90);
      expect(report.postedAt, isNotNull);
      expect(report.hasStructuredData, isTrue);
      expect(report.hasNarrative, isTrue);
    });

    test('a report filed before these fields existed still parses', () {
      final report = Report.fromJson(_reportJson());
      expect(report.activityType, '');
      expect(report.linkedPhase, isNull);
      expect(report.amountSpent, 0);
      expect(report.beneficiariesReached, 0);
      expect(report.postedAt, isNull);
      expect(report.hasStructuredData, isFalse);
      expect(report.hasNarrative, isFalse);
    });
  });

  group('ImpactSummary', () {
    test('parses the roll-up envelope', () {
      final summary = ImpactSummary.fromJson({
        'approved_reports': 2,
        'reach': {
          'total': 150,
          'male': 40,
          'female': 60,
          'youth': 30,
          'unspecified': 50,
        },
        'reported_spend': '70000.00',
        'total_spent': '90000.00',
        'cost_per_beneficiary': 600.0,
        'by_activity': [
          {
            'activity_type': 'training',
            'label': 'Training',
            'reports': 2,
            'beneficiaries_reached': 150,
            'amount_spent': '70000.00',
          }
        ],
        'narratives': [],
      });

      expect(summary.approvedReports, 2);
      expect(summary.reached, 150);
      expect(summary.unspecified, 50);
      expect(summary.totalSpent, 90000.0);
      expect(summary.costPerBeneficiary, 600.0);
      expect(summary.byActivity.single.label, 'Training');
      expect(summary.byActivity.single.amountSpent, 70000.0);
      expect(summary.isEmpty, isFalse);
    });

    test('an empty roll-up is flagged rather than shown as zeros', () {
      final summary = ImpactSummary.fromJson({
        'approved_reports': 0,
        'reach': {'total': 0, 'male': 0, 'female': 0, 'youth': 0,
            'unspecified': 0},
        'reported_spend': '0.00',
        'total_spent': '0.00',
        'cost_per_beneficiary': null,
        'by_activity': [],
        'narratives': [],
      });
      expect(summary.isEmpty, isTrue);
      expect(summary.costPerBeneficiary, isNull);
    });
  });

  group('ProjectImpactCard', () {
    Future<void> pumpCard(WidgetTester tester, ImpactSummary summary) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectImpactCard(summary: summary),
            ),
          ),
        ));

    testWidgets('shows reach, cost and the activity breakdown',
        (tester) async {
      await pumpCard(
        tester,
        const ImpactSummary(
          approvedReports: 2,
          reached: 150,
          male: 40,
          female: 60,
          unspecified: 50,
          youth: 30,
          totalSpent: 90000,
          costPerBeneficiary: 4542.86,
          byActivity: [
            ActivityBreakdown(
              activityType: 'training',
              label: 'Training',
              reports: 2,
              reached: 150,
              amountSpent: 70000,
            ),
          ],
        ),
      );

      expect(find.text('150'), findsOneWidget);
      expect(find.text('People reached'), findsOneWidget);
      // Per-person cost keeps its precision instead of collapsing to "5K".
      expect(find.text('KES 4,543'), findsOneWidget);
      expect(find.text('Cost per person'), findsOneWidget);
      expect(find.text('Training'), findsOneWidget);
      expect(find.text('150 reached'), findsOneWidget);
      expect(find.text('60 female'), findsOneWidget);
      expect(find.text('50 unspecified'), findsOneWidget);
      expect(find.text('incl. 30 youth'), findsOneWidget);
    });

    testWidgets('explains an empty roll-up instead of showing zeros',
        (tester) async {
      await pumpCard(tester, const ImpactSummary());
      expect(find.textContaining('No approved field reports yet'),
          findsOneWidget);
      expect(find.text('People reached'), findsNothing);
    });
  });
}
