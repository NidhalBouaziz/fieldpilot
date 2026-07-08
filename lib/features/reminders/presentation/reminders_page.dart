import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(visitsProvider);

    return visits.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) {
        final upcoming = items
            .where((visit) => visit.scheduledAt.isAfter(DateTime.now()))
            .toList();
        return PageScaffold(
          title: 'Reminders',
          actions: [
            IconButton(
              onPressed: () =>
                  ref.read(notificationServiceProvider).initialize(),
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: 'Enable notifications',
            ),
          ],
          children: [
            if (upcoming.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No reminders',
                message: 'Upcoming planned visits will appear here.',
              )
            else
              for (final visit in upcoming)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_none_outlined),
                    title: Text(
                      DateFormat.yMMMd().add_jm().format(visit.scheduledAt),
                    ),
                    subtitle: Text(visit.notes ?? 'Follow-up reminder'),
                  ),
                ),
          ],
        );
      },
    );
  }
}
