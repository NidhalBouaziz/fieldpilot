import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models/customer.dart';
import '../../../core/repositories/providers.dart';
import '../../../core/services/maps_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/logout_button.dart';

class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);

    return customers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) {
        final mapped = _mappedCustomers(items);
        if (mapped.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Map'),
              actions: const [LogoutButton()],
            ),
            body: const EmptyState(
              icon: Icons.map_outlined,
              title: 'No mappable customers',
              message: 'Add an address, city, governorate, or coordinates.',
            ),
          );
        }

        final initial = mapped.first.point;
        return Scaffold(
          appBar: AppBar(
            title: Text('Map (${mapped.length})'),
            actions: const [LogoutButton()],
          ),
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(initial.latitude, initial.longitude),
                  zoom: mapped.length == 1 ? 12 : 6.4,
                ),
                markers: {
                  for (final item in mapped)
                    Marker(
                      markerId: MarkerId(item.customer.id),
                      position: LatLng(
                        item.point.latitude,
                        item.point.longitude,
                      ),
                      infoWindow: InfoWindow(
                        title: item.customer.displayName,
                        snippet: item.point.approximate
                            ? 'Approx. ${_locationLabel(item.customer)}'
                            : item.customer.address,
                        onTap: () => context.go(
                          '/customers/${item.customer.id}',
                        ),
                      ),
                      onTap: () => _openMaps(context, item.customer),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        _hue(item.customer.status, item.point.approximate),
                      ),
                    ),
                },
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _CustomerMapSheet(mapped: mapped),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_MappedCustomer> _mappedCustomers(List<Customer> customers) {
    final used = <String, int>{};
    return [
      for (final customer in customers)
        if (mapPointForCustomer(customer) case final point?)
          _MappedCustomer(
            customer: customer,
            point: _spreadPoint(point, used),
          ),
    ];
  }

  MapPoint _spreadPoint(MapPoint point, Map<String, int> used) {
    if (!point.approximate) return point;

    final key = '${point.latitude.toStringAsFixed(3)},'
        '${point.longitude.toStringAsFixed(3)}';
    final index = used.update(key, (value) => value + 1, ifAbsent: () => 0);
    if (index == 0) return point;

    final angle = index * 0.9;
    final radius = 0.035 + (index ~/ 8) * 0.015;
    return MapPoint(
      point.latitude + math.sin(angle) * radius,
      point.longitude + math.cos(angle) * radius,
      approximate: true,
    );
  }

  double _hue(CustomerStatus status, bool approximate) {
    if (approximate) return BitmapDescriptor.hueOrange;
    return switch (status) {
      CustomerStatus.neverVisited => BitmapDescriptor.hueAzure,
      CustomerStatus.planned => BitmapDescriptor.hueBlue,
      CustomerStatus.customer => BitmapDescriptor.hueGreen,
      CustomerStatus.followUp => BitmapDescriptor.hueYellow,
      CustomerStatus.interested => BitmapDescriptor.hueOrange,
      CustomerStatus.notInterested => BitmapDescriptor.hueRed,
      CustomerStatus.archived => BitmapDescriptor.hueViolet,
    };
  }

  Future<void> _openMaps(BuildContext context, Customer customer) async {
    final opened = await openCustomerInMaps(customer);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }
}

class _CustomerMapSheet extends StatelessWidget {
  const _CustomerMapSheet({required this.mapped});

  final List<_MappedCustomer> mapped;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: SizedBox(
        height: 184,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                'Customers on map',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                itemCount: mapped.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = mapped[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      radius: 15,
                      backgroundColor: item.point.approximate
                          ? colorScheme.secondaryContainer
                          : colorScheme.primaryContainer,
                      child: Icon(
                        item.point.approximate
                            ? Icons.location_searching
                            : Icons.location_on,
                        size: 17,
                      ),
                    ),
                    title: Text(
                      item.customer.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (item.point.approximate) 'Approx.',
                        _locationLabel(item.customer),
                      ].where((part) => part.isNotEmpty).join(' | '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Open in Google Maps',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => openCustomerInMaps(item.customer),
                    ),
                    onTap: () => context.go('/customers/${item.customer.id}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MappedCustomer {
  const _MappedCustomer({required this.customer, required this.point});

  final Customer customer;
  final MapPoint point;
}

String _locationLabel(Customer customer) {
  return [
    customer.city,
    customer.governorate,
    customer.address,
  ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
}
