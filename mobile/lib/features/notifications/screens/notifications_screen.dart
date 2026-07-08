import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () => context.read<NotificationsProvider>().load(),
        child: provider.loading && provider.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.items.isEmpty
                ? _EmptyState()
                : ListView.separated(
                    itemCount: provider.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = provider.items[i];
                      return Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: const Color(0xFFC62828),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child:
                              const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) =>
                            context.read<NotificationsProvider>().remove(n.id),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: n.isUnread
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.border,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              n.isUnread
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_outlined,
                              color: n.isUnread ? AppColors.primary : AppColors.muted,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: n.isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                n.message,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.muted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (n.createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(n.createdAt!),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ],
                          ),
                          trailing: n.isUnread
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          onTap: n.isUnread
                              ? () => context
                                  .read<NotificationsProvider>()
                                  .markRead(n.id)
                              : null,
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_outlined,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text('All caught up!',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('No notifications at this time.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
