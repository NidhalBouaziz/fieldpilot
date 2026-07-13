import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/visit.dart';
import '../../../core/repositories/providers.dart';
import '../../../core/services/maps_service.dart';
import '../../../shared/widgets/customer_status_chip.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/logout_button.dart';

class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.watch(customerRepositoryProvider).byId(customerId),
      builder: (context, snapshot) {
        final customer = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (customer == null) {
          return const EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Customer not found',
            message: 'This profile is not available locally.',
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(customer.displayName),
            actions: [
              IconButton(
                onPressed: () => context.go('/customers/${customer.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit customer',
              ),
              PopupMenuButton<_CustomerAction>(
                onSelected: (action) =>
                    _handleAction(context, ref, customer, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _CustomerAction.planVisit,
                    child: ListTile(
                      leading: Icon(Icons.event_available_outlined),
                      title: Text('Plan visit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: customer.isArchived
                        ? _CustomerAction.restore
                        : _CustomerAction.archive,
                    child: ListTile(
                      leading: Icon(
                        customer.isArchived
                            ? Icons.restore_outlined
                            : Icons.archive_outlined,
                      ),
                      title: Text(customer.isArchived ? 'Restore' : 'Archive'),
                    ),
                  ),
                ],
              ),
              const LogoutButton(),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    child: Text(
                      customer.displayName.characters.first.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.displayName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(customer.companyName),
                      ],
                    ),
                  ),
                  CustomerStatusChip(status: customer.status),
                ],
              ),
              const SizedBox(height: 24),
              _tile(Icons.phone_outlined, 'Phone', customer.phone),
              if (customer.phone2 != null)
                _tile(
                  Icons.phone_android_outlined,
                  'Phone 2',
                  customer.phone2!,
                ),
              if (customer.email != null)
                _tile(Icons.mail_outline, 'Email', customer.email!),
              _tile(Icons.location_city_outlined, 'City', customer.city),
              _tile(Icons.map_outlined, 'Governorate', customer.governorate),
              if (customer.address != null)
                _tile(
                  Icons.place_outlined,
                  'Address',
                  customer.address!,
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openMaps(context, customer),
                ),
              if (customer.speciality != null)
                _tile(
                  Icons.medical_services_outlined,
                  'Speciality',
                  customer.speciality!,
                ),
              if (customer.notes != null)
                _tile(Icons.notes_outlined, 'Notes', customer.notes!),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String value, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Future<void> _openMaps(BuildContext context, Customer customer) async {
    final opened = await openCustomerInMaps(customer);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    _CustomerAction action,
  ) async {
    switch (action) {
      case _CustomerAction.planVisit:
        await _planVisit(context, ref, customer);
        return;
      case _CustomerAction.archive:
        await _archive(context, ref, customer);
        return;
      case _CustomerAction.restore:
        await ref.read(customerRepositoryProvider).restore(customer.id);
        ref.invalidate(customersProvider);
        ref.invalidate(dashboardSnapshotProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer restored.')),
          );
        }
        return;
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive customer?'),
        content: Text(
          '${customer.displayName} will be hidden from active customer lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(customerRepositoryProvider).archive(customer.id);
    ref.invalidate(customersProvider);
    ref.invalidate(dashboardSnapshotProvider);
    if (context.mounted) context.go('/customers');
  }

  Future<void> _planVisit(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final visit = Visit(
      id: ref.read(idGeneratorProvider)(),
      customerId: customer.id,
      scheduledAt: scheduledAt,
      status: VisitStatus.planned,
      notes: 'Planned follow-up with ${customer.displayName}',
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(visitRepositoryProvider).save(visit);
    ref.invalidate(visitsProvider);
    ref.invalidate(dashboardSnapshotProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visit planned.')),
      );
    }
  }
}

enum _CustomerAction { planVisit, archive, restore }
