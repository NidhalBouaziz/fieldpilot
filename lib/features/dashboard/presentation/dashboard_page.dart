import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/page_scaffold.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final colors = Theme.of(context).colorScheme;

    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (data) => PageScaffold(
        title: 'Today',
        actions: [
          IconButton(
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: () => context.go('/export'),
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
          ),
        ],
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final cards = [
                MetricCard(
                  label: "Today's visits",
                  value: '${data.todaysVisits}',
                  icon: Icons.today_outlined,
                  color: colors.primary,
                ),
                MetricCard(
                  label: 'Upcoming visits',
                  value: '${data.upcomingVisits}',
                  icon: Icons.event_outlined,
                  color: Colors.indigo,
                ),
                MetricCard(
                  label: 'Overdue visits',
                  value: '${data.overdueVisits}',
                  icon: Icons.warning_amber_outlined,
                  color: Colors.red,
                ),
                MetricCard(
                  label: 'New customers',
                  value: '${data.newCustomers}',
                  icon: Icons.person_add_alt,
                  color: Colors.green,
                ),
                MetricCard(
                  label: 'Interested',
                  value: '${data.interestedCustomers}',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
                MetricCard(
                  label: 'Never visited',
                  value: '${data.neverVisited}',
                  icon: Icons.location_off_outlined,
                  color: Colors.grey,
                ),
              ];
              return GridView.count(
                crossAxisCount: compact ? 2 : 3,
                childAspectRatio: compact ? 1.35 : 2.4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: cards,
              );
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/customers/new'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add customer'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/scanner'),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan card'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/visits'),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Plan visit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
