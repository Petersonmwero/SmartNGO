import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/notifications/notification_repository.dart';

import 'notification_stub.dart';

void main() {
  late NotificationRepository repo;
  late NotificationStub stub;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    stub = NotificationStub();
    dio.httpClientAdapter = stub;
    repo = NotificationRepository(ApiClient(InMemoryTokenStore(), dio: dio));
  });

  test('list parses notifications', () async {
    final page = await repo.list();
    expect(page.count, 2);
    expect(page.results.first.isUnread, isTrue);
  });

  test('unreadCount uses the status filter', () async {
    expect(await repo.unreadCount(), 1);
  });

  test('markRead PATCHes the notification', () async {
    await repo.markRead(1);
    expect(stub.calls, contains('PATCH /notifications/1/'));
  });

  test('delete removes the notification', () async {
    await repo.delete(2);
    expect(stub.calls, contains('DELETE /notifications/2/'));
  });
}
