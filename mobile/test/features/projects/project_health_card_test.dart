import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/features/projects/models/project.dart';
import 'package:smartngo/features/projects/widgets/evm_cards.dart';

Map<String, dynamic> _projectJson({
  required double physical,
  required double plannedValue,
  double? spi,
  double composite = 27.0,
}) =>
    {
      'id': 1,
      'project_name': 'Food Security Programme',
      'description': '',
      'budget': '1000000.00',
      'status': 'active',
      'ngo': 1,
      'progress_percentage': composite,
      'physical_progress': physical,
      'time_progress': 50.0,
      'planned_value_progress': plannedValue,
      'schedule_performance_index': spi,
      'health_status': 'critical',
    };

/// Width factors of the two filled bands, in draw order (composite, then
/// physical over it).
List<double?> _bandWidthFactors(WidgetTester tester) => tester
    .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .map((b) => b.widthFactor)
    .toList();

void main() {
  test('parses planned_value_progress, defaulting to 0 when absent', () {
    final project = Project.fromJson(
      _projectJson(physical: 40.0, plannedValue: 80.0),
    );
    expect(project.plannedValueProgress, 80.0);
    // Older payloads (pre-PV backend) must not crash the parse.
    final legacy = Project.fromJson(
      _projectJson(physical: 40.0, plannedValue: 0)..remove('planned_value_progress'),
    );
    expect(legacy.plannedValueProgress, 0.0);
  });

  testWidgets('health card shows earned vs planned work under the SPI',
      (tester) async {
    final project = Project.fromJson(
      _projectJson(physical: 40.0, plannedValue: 80.0, spi: 0.5),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProjectHealthCard(project: project),
          ),
        ),
      ),
    );
    expect(find.text('0.50'), findsOneWidget);
    expect(find.text('Behind planned work ⚠'), findsOneWidget);
    expect(
      find.text('Earned 40.0% of budgeted work vs 80.0% planned'),
      findsOneWidget,
    );
  });

  testWidgets('SPI reads as undefined when no work was scheduled yet',
      (tester) async {
    final project = Project.fromJson(
      _projectJson(physical: 0, plannedValue: 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProjectHealthCard(project: project),
          ),
        ),
      ),
    );
    expect(find.text('No work scheduled yet'), findsOneWidget);
    expect(find.text('Earned 0.0% of budgeted work vs 0.0% planned'),
        findsOneWidget);
  });

  group('EvmProgressTrack', () {
    Future<void> pumpTrack(WidgetTester tester, Project project) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  child: EvmProgressTrack(project: project),
                ),
              ),
            ),
          ),
        );

    testWidgets('draws composite and physical bands plus a planned tick',
        (tester) async {
      await pumpTrack(
        tester,
        Project.fromJson(
          _projectJson(physical: 10.0, plannedValue: 49.0, composite: 27.0),
        ),
      );
      expect(_bandWidthFactors(tester), [0.27, 0.10]);
      // The tick's x maps 0-100% onto -1..1, so 49% sits just left of centre.
      final tick = tester.widget<Align>(find.byKey(EvmProgressTrack.tickKey));
      expect((tick.alignment as Alignment).x, closeTo(-0.02, 0.001));
    });

    testWidgets('anchors the bands to the left of the track', (tester) async {
      // Regression: a bare FractionallySizedBox inside the Stack is centred
      // by the Stack, which made every band float mid-track.
      await pumpTrack(
        tester,
        Project.fromJson(
          _projectJson(physical: 10.0, plannedValue: 49.0, composite: 27.0),
        ),
      );
      final trackLeft = tester.getTopLeft(find.byType(EvmProgressTrack)).dx;
      // The keyed widget is the full-width Align; the drawn band is its
      // FractionallySizedBox child.
      final band = tester.getRect(
        find.descendant(
          of: find.byKey(EvmProgressTrack.physicalBandKey),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(band.left, trackLeft);
      expect(band.width, closeTo(200 * 0.10, 0.5));
    });

    testWidgets('honours a caller-supplied band colour', (tester) async {
      // The dashboard rows stay status-coloured rather than EVM green.
      const accent = Color(0xFFCC0000);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: EvmProgressTrack(
                project: Project.fromJson(
                  _projectJson(physical: 10.0, plannedValue: 49.0),
                ),
                color: accent,
              ),
            ),
          ),
        ),
      );
      final band = tester.widget<Container>(
        find.descendant(
          of: find.byKey(EvmProgressTrack.physicalBandKey),
          matching: find.byType(Container),
        ),
      );
      expect((band.color), accent);
    });

    testWidgets('omits the tick when nothing was planned yet', (tester) async {
      await pumpTrack(
        tester,
        Project.fromJson(_projectJson(physical: 0, plannedValue: 0)),
      );
      expect(find.byKey(EvmProgressTrack.tickKey), findsNothing);
    });

    testWidgets('clamps over-100% values to a full track', (tester) async {
      await pumpTrack(
        tester,
        Project.fromJson(
          _projectJson(physical: 140.0, plannedValue: 130.0, composite: 120.0),
        ),
      );
      expect(_bandWidthFactors(tester), [1.0, 1.0]);
    });
  });
}
