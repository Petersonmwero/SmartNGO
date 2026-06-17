import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/notifications/notification_repository.dart';
import 'package:smartngo/features/notifications/notifications_provider.dart';
import 'package:smartngo/features/notifications/screens/notifications_screen.dart';

import 'notification_stub.dart';

NotificationsProvider _provider() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
  dio.httpClientAdapter = NotificationStub();
  return NotificationsProvider(
      NotificationRepository(ApiClient(InMemoryTokenStore(), dio: dio)));
}

void main() {
  test('load populates items and unread count', () async {
    final provider = _provider();
    await provider.load();
    expect(provider.items, hasLength(2));
    expect(provider.unread, 1);
  });

  test('markRead decrements unread and flips status locally', () async {
    final provider = _provider();
    await provider.load();
    await provider.markRead(1);
    expect(provider.unread, 0);
    expect(provider.items.firstWhere((n) => n.id == 1).isUnread, isFalse);
  });

  testWidgets('NotificationsScreen renders notifications', (tester) async {
    final provider = _provider();
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificationsProvider>.value(
        value: provider,
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report approved'), findsOneWidget);
    expect(find.text('Added to a project'), findsOneWidget);
  });
}
