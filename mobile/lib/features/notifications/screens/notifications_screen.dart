import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../models/notification.dart';
import '../notifications_provider.dart';

/// Official notification log: action bar with the unread count, time-bucket
/// separators, and flat log rows (gold left rule + amber tint when unread).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().load();
    });
  }

  /// Bucket key: 0 = today, 1 = this week, 2 = earlier.
  int _bucket(AppNotification n) {
    final iso = n.createdAt;
    if (iso == null) return 2;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 2;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!dt.isBefore(today)) return 0;
    if (now.difference(dt).inDays < 7) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final items = provider.items;

    final buckets = <int, List<AppNotification>>{};
    for (final n in items) {
      buckets.putIfAbsent(_bucket(n), () => []).add(n);
    }
    const bucketLabels = {0: 'Today', 1: 'This Week', 2: 'Earlier'};

    return Scaffold(
      appBar: AppBar(title: const Text('NOTIFICATIONS')),
      body: Column(
        children: [
          // Official action bar.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  '${provider.unread} unread '
                  'notification${provider.unread == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: provider.unread > 0
                      ? () =>
                          context.read<NotificationsProvider>().markAllRead()
                      : null,
                  child: const Text(
                    'Mark All Read',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<NotificationsProvider>().load(),
              child: provider.loading && items.isEmpty
                  ? const ShimmerList(cardHeight: 72)
                  : items.isEmpty
                      ? const EmptyState(
                          Icons.notifications_none_outlined,
                          "You're all caught up!",
                          'New notifications will appear here.',
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            for (final bucket in const [0, 1, 2])
                              if (buckets.containsKey(bucket)) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 14, 16, 6),
                                  child: Text(
                                    bucketLabels[bucket]!.toUpperCase(),
                                    style: AppTextStyles.capsLabel,
                                  ),
                                ),
                                for (final n in buckets[bucket]!)
                                  _NotificationRow(notification: n),
                              ],
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat official log row; swipe left to delete, tap to mark read.
class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  const _NotificationRow({required this.notification});

  (IconData, Color, Color) get _typeSpec {
    final text =
        '${notification.title} ${notification.message}'.toLowerCase();
    if (text.contains('approv')) {
      return (Icons.check_circle_outline, AppColors.info, AppColors.infoTint);
    }
    if (text.contains('due') ||
        text.contains('deadline') ||
        text.contains('overdue') ||
        text.contains('budget')) {
      return (Icons.access_time_outlined, AppColors.warning,
          AppColors.warningTint);
    }
    if (text.contains('assign') || text.contains('added')) {
      return (Icons.person_add_outlined, AppColors.success,
          AppColors.successTint);
    }
    return (Icons.notifications_outlined, AppColors.neutral,
        AppColors.neutralTint);
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, color, surface) = _typeSpec;
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => context.read<NotificationsProvider>().remove(n.id),
      child: InkWell(
        onTap: n.isUnread
            ? () => context.read<NotificationsProvider>().markRead(n.id)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: n.isUnread ? AppColors.accentSurface : Colors.white,
            border: Border(
              bottom: const BorderSide(color: Color(0xFFEEEEEE)),
              left: BorderSide(
                color: n.isUnread ? AppColors.accent : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            n.isUnread ? FontWeight.w600 : FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (n.createdAt != null)
                Text(
                  _formatDate(n.createdAt!),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
