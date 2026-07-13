import 'package:flutter/foundation.dart';

import 'models/notification.dart';
import 'notification_repository.dart';

/// Holds the notification list + unread count so the dashboard badge and the
/// notifications screen stay in sync.
class NotificationsProvider extends ChangeNotifier {
  final NotificationRepository _repo;

  NotificationsProvider(this._repo);

  List<AppNotification> items = [];
  int unread = 0;
  bool loading = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final page = await _repo.list();
      items = page.results;
      unread = await _repo.unreadCount();
    } catch (_) {
      // Leave previous state on failure; UI shows what it has.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    await _repo.markRead(id);
    final i = items.indexWhere((n) => n.id == id);
    if (i != -1 && items[i].isUnread) {
      items[i] = items[i].copyWith(status: 'read');
      unread = (unread - 1).clamp(0, 1 << 30);
      notifyListeners();
    }
  }

  Future<void> remove(int id) async {
    final wasUnread = items.any((n) => n.id == id && n.isUnread);
    await _repo.delete(id);
    items.removeWhere((n) => n.id == id);
    if (wasUnread) unread = (unread - 1).clamp(0, 1 << 30);
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    items = [for (final n in items) n.copyWith(status: 'read')];
    unread = 0;
    notifyListeners();
  }
}
