import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No notifications.')),
                    ],
                  )
                : ListView.separated(
                    itemCount: provider.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = provider.items[i];
                      return Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) =>
                            context.read<NotificationsProvider>().remove(n.id),
                        child: ListTile(
                          leading: Icon(
                            n.isUnread
                                ? Icons.mark_email_unread
                                : Icons.mark_email_read,
                            color: n.isUnread
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight:
                                  n.isUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(n.message),
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
}
