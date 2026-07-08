import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/customer_status_chip.dart';
import '../../../shared/widgets/empty_state.dart';

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
          appBar: AppBar(title: Text(customer.displayName)),
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
                _tile(Icons.place_outlined, 'Address', customer.address!),
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

  Widget _tile(IconData icon, String title, String value) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
