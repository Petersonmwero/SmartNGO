import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/projects/project_repository.dart';
import 'package:smartngo/features/projects/screens/projects_list_screen.dart';

import 'project_repository_test.dart' show StubAdapter;

void main() {
  testWidgets('renders the list of projects from the repository',
      (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    dio.httpClientAdapter = StubAdapter();
    final repo = ProjectRepository(ApiClient(InMemoryTokenStore(), dio: dio));

    await tester.pumpWidget(
      Provider<ProjectRepository>.value(
        value: repo,
        child: const MaterialApp(home: ProjectsListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
  });
}
