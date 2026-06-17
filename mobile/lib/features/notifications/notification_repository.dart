import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/paginated.dart';
import 'models/notification.dart';

class NotificationRepository {
  final ApiClient _api;

  NotificationRepository(this._api);

  Future<Paginated<AppNotification>> list({String? status}) {
    return apiGuard(() async {
      final query = <String, dynamic>{};
      if (status != null) query['status'] = status;
      final res = await _api.dio.get('/notifications/', queryParameters: query);
      return Paginated.fromJson(
          res.data as Map<String, dynamic>, AppNotification.fromJson);
    });
  }

  Future<int> unreadCount() async {
    final page = await list(status: 'unread');
    return page.count;
  }

  Future<void> markRead(int id) {
    return apiGuard(() async {
      await _api.dio
          .patch('/notifications/$id/', data: {'status': 'read'});
    });
  }

  Future<void> delete(int id) {
    return apiGuard(() async {
      await _api.dio.delete('/notifications/$id/');
    });
  }
}
