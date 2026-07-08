import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/page_scaffold.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final colors = Theme.of(context).colorScheme;

    return customers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) {
        final converted = items
            .where((customer) => customer.status == CustomerStatus.customer)
            .length;
        final interested = items
            .where((customer) => customer.status == CustomerStatus.interested)
            .length;
        final cities = <String, int>{};
        for (final customer in items) {
          if (customer.city.isEmpty) continue;
          cities.update(customer.city, (value) => value + 1, ifAbsent: () => 1);
        }

        return PageScaffold(
          title: 'Analytics',
          children: [
            MetricCard(
              label: 'Customers',
              value: '${items.length}',
              icon: Icons.people_alt_outlined,
              color: colors.primary,
            ),
            MetricCard(
              label: 'Converted',
              value: '$converted',
              icon: Icons.verified_outlined,
              color: Colors.green,
            ),
            MetricCard(
              label: 'Interested',
              value: '$interested',
              icon: Icons.trending_up,
              color: Colors.orange,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cities',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (cities.isEmpty)
                      const Text(
                        'City distribution appears after customer data is saved.',
                      )
                    else
                      for (final entry in cities.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Text('${entry.value}'),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
