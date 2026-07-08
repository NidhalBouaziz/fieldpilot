import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/customer.dart';
import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/customer_status_chip.dart';

final searchQueryProvider = StateProvider.autoDispose<String>((_) => '');

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Name, phone, city, company, speciality',
              ),
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: ref.watch(customerRepositoryProvider).search(query),
              builder: (context, snapshot) {
                final results = snapshot.data ?? const <Customer>[];
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final customer = results[index];
                    return ListTile(
                      title: Text(customer.displayName),
                      subtitle: Text(
                        [
                          customer.phone,
                          customer.city,
                        ].where((value) => value.isNotEmpty).join(' • '),
                      ),
                      trailing: CustomerStatusChip(status: customer.status),
                      onTap: () => context.go('/customers/${customer.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
