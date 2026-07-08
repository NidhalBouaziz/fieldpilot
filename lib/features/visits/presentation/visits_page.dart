import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/visit.dart';
import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';

class VisitsPage extends ConsumerWidget {
  const VisitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(visitsProvider);

    return visits.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) => PageScaffold(
        title: 'Visits',
        actions: [
          IconButton(
            onPressed: () => _planVisit(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Plan visit',
          ),
        ],
        children: [
          if (items.isEmpty)
            EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No visits planned',
              message:
                  'Plan follow-ups and daily routes from customer profiles.',
              action: FilledButton.icon(
                onPressed: () => _planVisit(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Plan visit'),
              ),
            )
          else
            for (final visit in items)
              Card(
                child: ListTile(
                  leading: Icon(
                    visit.isOverdue
                        ? Icons.warning_amber_outlined
                        : Icons.event_outlined,
                  ),
                  title: Text(
                    DateFormat.yMMMd().add_jm().format(visit.scheduledAt),
                  ),
                  subtitle: Text(visit.notes ?? visit.status.label),
                  trailing: Chip(label: Text(visit.status.label)),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _planVisit(BuildContext context, WidgetRef ref) async {
    final customers = await ref.read(customerRepositoryProvider).list();
    if (!context.mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a customer before planning a visit.'),
        ),
      );
      return;
    }

    final customer = customers.first;
    final now = DateTime.now();
    final visit = Visit(
      id: ref.read(idGeneratorProvider)(),
      customerId: customer.id,
      scheduledAt: now.add(const Duration(days: 1)),
      status: VisitStatus.planned,
      notes: 'Planned follow-up with ${customer.displayName}',
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(visitRepositoryProvider).save(visit);
    ref.invalidate(visitsProvider);
    ref.invalidate(dashboardSnapshotProvider);
  }
}
