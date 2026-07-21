import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/features/projects/models/project.dart';
import 'package:smartngo/features/projects/widgets/evm_cards.dart';

Map<String, dynamic> _projectJson({
  required double physical,
  required double plannedValue,
  double? spi,
}) =>
    {
      'id': 1,
      'project_name': 'Food Security Programme',
      'description': '',
      'budget': '1000000.00',
      'status': 'active',
      'ngo': 1,
      'physical_progress': physical,
      'time_progress': 50.0,
      'planned_value_progress': plannedValue,
      'schedule_performance_index': spi,
      'health_status': 'critical',
    };

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
}
