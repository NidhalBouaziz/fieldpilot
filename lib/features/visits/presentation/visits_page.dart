import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/visit.dart';
import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';

class VisitsPage extends ConsumerWidget {
  const VisitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(visitsProvider);
    final customers = ref.watch(customersProvider).valueOrNull ?? const [];
    final customerById = {
      for (final customer in customers) customer.id: customer,
    };

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
                  subtitle: Text(
                    [
                      if (customerById[visit.customerId] != null)
                        customerById[visit.customerId]!.displayName,
                      visit.notes ?? visit.status.label,
                    ].join(' | '),
                  ),
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

    final details = await _showPlanVisitDialog(context, customers);
    if (details == null) return;

    final now = DateTime.now();
    final visit = Visit(
      id: ref.read(idGeneratorProvider)(),
      customerId: details.customer.id,
      scheduledAt: details.scheduledAt,
      status: VisitStatus.planned,
      notes: details.notes?.isEmpty == true ? null : details.notes,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(visitRepositoryProvider).save(visit);
    ref.invalidate(visitsProvider);
    ref.invalidate(dashboardSnapshotProvider);
  }

  Future<_VisitPlan?> _showPlanVisitDialog(
    BuildContext context,
    List<Customer> customers,
  ) {
    final now = DateTime.now();
    var selectedCustomer = customers.first;
    var selectedDate = now.add(const Duration(days: 1));
    var selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final notes = TextEditingController(
      text: 'Planned follow-up with ${selectedCustomer.displayName}',
    );

    return showDialog<_VisitPlan>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> chooseDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked == null) return;
            setDialogState(() => selectedDate = picked);
          }

          Future<void> chooseTime() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: selectedTime,
            );
            if (picked == null) return;
            setDialogState(() => selectedTime = picked);
          }

          return AlertDialog(
            title: const Text('Plan visit'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Customer>(
                  initialValue: selectedCustomer,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: [
                    for (final customer in customers)
                      DropdownMenuItem(
                        value: customer,
                        child: Text(customer.displayName),
                      ),
                  ],
                  onChanged: (customer) {
                    if (customer == null) return;
                    setDialogState(() {
                      selectedCustomer = customer;
                      notes.text =
                          'Planned follow-up with ${customer.displayName}';
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: chooseDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(DateFormat.yMMMd().format(selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: chooseTime,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(selectedTime.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _VisitPlan(
                      customer: selectedCustomer,
                      scheduledAt: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      ),
                      notes: notes.text.trim(),
                    ),
                  );
                },
                child: const Text('Plan'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(notes.dispose);
  }
}

class _VisitPlan {
  const _VisitPlan({
    required this.customer,
    required this.scheduledAt,
    this.notes,
  });

  final Customer customer;
  final DateTime scheduledAt;
  final String? notes;
}
