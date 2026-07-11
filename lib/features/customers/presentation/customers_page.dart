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
                  'Create the first profile or scan a document during your next visit.',
              action: FilledButton.icon(
                onPressed: () => context.go('/customers/new'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add customer'),
              ),
            )
          else
            for (final entry in items.asMap().entries)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(
                    entry.value.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (entry.value.phone.isNotEmpty) entry.value.phone,
                      if (entry.value.city.isNotEmpty) entry.value.city,
                      if (entry.value.address != null) entry.value.address!,
                    ].join(' | '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: SizedBox(
                    width: 118,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: CustomerStatusChip(status: entry.value.status),
                    ),
                  ),
                  onTap: () => context.go('/customers/${entry.value.id}'),
                ),
              ),
        ],
      ),
    );
  }
}
