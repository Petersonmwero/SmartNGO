import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../models/notification.dart';
import '../notifications_provider.dart';

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
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unread > 0)
            TextButton(
              onPressed: () =>
                  context.read<NotificationsProvider>().markAllRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.accentLight),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<NotificationsProvider>().load(),
        child: provider.loading && items.isEmpty
            ? const ShimmerList(cardHeight: 88)
            : items.isEmpty
                ? const EmptyState(
                    Icons.notifications_none_outlined,
                    "You're all caught up! 🎉",
                    'New notifications will appear here.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (final bucket in const [0, 1, 2])
                        if (buckets.containsKey(bucket)) ...[
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              bucketLabels[bucket]!.toUpperCase(),
                              style: AppTextStyles.capsLabel,
                            ),
                          ),
                          for (final n in buckets[bucket]!)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _NotificationCard(notification: n),
                            ),
                        ],
                    ],
                  ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  const _NotificationCard({required this.notification});

  /// Icon and color inferred from the notification's subject: green person
  /// for team assignments, amber clock for deadlines, blue check for
  /// approvals, grey bell otherwise.
  (IconData, Color) get _typeSpec {
    final text =
        '${notification.title} ${notification.message}'.toLowerCase();
    if (text.contains('approv')) {
      return (Icons.check_circle_outline, AppColors.info);
    }
    if (text.contains('due') ||
        text.contains('deadline') ||
        text.contains('overdue') ||
        text.contains('budget')) {
      return (Icons.schedule, AppColors.accent);
    }
    if (text.contains('assign') || text.contains('added')) {
      return (Icons.person_outline, AppColors.success);
    }
    return (Icons.notifications_outlined, AppColors.muted);
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
    final (icon, color) = _typeSpec;
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => context.read<NotificationsProvider>().remove(n.id),
      child: Card(
        // Unread cards get a faint amber tint so they stand out at a glance.
        color: n.isUnread
            ? Color.alphaBlend(
                AppColors.warningTint.withValues(alpha: 0.35), Colors.white)
            : Colors.white,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: n.isUnread
              ? () => context.read<NotificationsProvider>().markRead(n.id)
              : null,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: n.isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                            ),
                          ),
                          if (n.createdAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(n.createdAt!),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.message,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 13, color: AppColors.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
