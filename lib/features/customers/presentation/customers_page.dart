import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/customer_status_chip.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);

    return customers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) => PageScaffold(
        title: 'Customers',
        actions: [
          IconButton(
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: () => context.go('/customers/new'),
            icon: const Icon(Icons.add),
            tooltip: 'Add customer',
          ),
        ],
        children: [
          if (items.isEmpty)
            EmptyState(
              icon: Icons.people_alt_outlined,
              title: 'No customers yet',
              message:
                  'Create the first profile or scan a business card during your next visit.',
              action: FilledButton.icon(
                onPressed: () => context.go('/customers/new'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add customer'),
              ),
            )
          else
            for (final customer in items)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      customer.displayName.characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(customer.displayName),
                  subtitle: Text(
                    [
                      customer.companyName,
                      customer.city,
                    ].where((value) => value.isNotEmpty).join(' • '),
                  ),
                  trailing: CustomerStatusChip(status: customer.status),
                  onTap: () => context.go('/customers/${customer.id}'),
                ),
              ),
        ],
      ),
    );
  }
}
