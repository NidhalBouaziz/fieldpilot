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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Map'),
            actions: const [LogoutButton()],
          ),
          body: FutureBuilder<List<_MappedCustomer>>(
            future: _mappedCustomers(items),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Resolving customer addresses...'),
                    ],
                  ),
                );
              }

              final mapped = snapshot.data ?? const <_MappedCustomer>[];
              if (mapped.isEmpty) {
                return const EmptyState(
                  icon: Icons.map_outlined,
                  title: 'No mappable customers',
                  message: 'Add an address, city, governorate, or coordinates.',
                );
              }

              final initial = mapped.first.point;
              final exactCount =
                  mapped.where((item) => !item.point.approximate).length;
              final approximateCount = mapped.length - exactCount;
              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(initial.latitude, initial.longitude),
                      zoom: mapped.length == 1 ? 13 : 6.4,
                    ),
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: (controller) {
                      _fitMapToCustomers(controller, mapped);
                    },
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
                                : _locationLabel(item.customer),
                            onTap: () => context.go(
                              '/customers/${item.customer.id}',
                            ),
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            _hue(
                              item.customer.status,
                              item.point.approximate,
                            ),
                          ),
                        ),
                    },
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: _MapSummaryBar(
                      total: mapped.length,
                      exact: exactCount,
                      approximate: approximateCount,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _CustomerMapSheet(mapped: mapped),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _fitMapToCustomers(
    GoogleMapController controller,
    List<_MappedCustomer> mapped,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mapped.length == 1) {
      final point = mapped.first.point;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(point.latitude, point.longitude),
          point.approximate ? 8 : 15,
        ),
      );
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFor(mapped), 76),
    );
  }

  Future<List<_MappedCustomer>> _mappedCustomers(
    List<Customer> customers,
  ) async {
    final used = <String, int>{};
    final mapped = <_MappedCustomer>[];
    for (final customer in customers) {
      final point = await resolveMapPointForCustomer(customer);
      if (point == null) continue;
      mapped.add(
        _MappedCustomer(
          customer: customer,
          point: _spreadPoint(point, used),
        ),
      );
    }
    return mapped;
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
}

LatLngBounds _boundsFor(List<_MappedCustomer> mapped) {
  var minLatitude = mapped.first.point.latitude;
  var maxLatitude = mapped.first.point.latitude;
  var minLongitude = mapped.first.point.longitude;
  var maxLongitude = mapped.first.point.longitude;

  for (final item in mapped.skip(1)) {
    minLatitude = math.min(minLatitude, item.point.latitude);
    maxLatitude = math.max(maxLatitude, item.point.latitude);
    minLongitude = math.min(minLongitude, item.point.longitude);
    maxLongitude = math.max(maxLongitude, item.point.longitude);
  }

  if (minLatitude == maxLatitude) {
    minLatitude -= 0.01;
    maxLatitude += 0.01;
  }
  if (minLongitude == maxLongitude) {
    minLongitude -= 0.01;
    maxLongitude += 0.01;
  }

  return LatLngBounds(
    southwest: LatLng(minLatitude, minLongitude),
    northeast: LatLng(maxLatitude, maxLongitude),
  );
}

class _MapSummaryBar extends StatelessWidget {
  const _MapSummaryBar({
    required this.total,
    required this.exact,
    required this.approximate,
  });

  final int total;
  final int exact;
  final int approximate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.location_on, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$total customers mapped',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            _MapCountChip(label: 'Exact', value: exact),
            const SizedBox(width: 6),
            _MapCountChip(label: 'Approx.', value: approximate),
          ],
        ),
      ),
    );
  }
}

class _MapCountChip extends StatelessWidget {
  const _MapCountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
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
