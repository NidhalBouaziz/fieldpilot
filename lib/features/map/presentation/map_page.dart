import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models/customer.dart';
import '../../../core/repositories/providers.dart';

class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);

    return customers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (items) {
        final positioned = items
            .where(
              (customer) =>
                  customer.latitude != null && customer.longitude != null,
            )
            .toList();
        if (positioned.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Map')),
            body: const Center(
              child: Text(
                'Customer locations appear here once latitude and longitude are saved.',
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Map')),
          body: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                positioned.first.latitude!,
                positioned.first.longitude!,
              ),
              zoom: 12,
            ),
            markers: {
              for (final customer in positioned)
                Marker(
                  markerId: MarkerId(customer.id),
                  position: LatLng(customer.latitude!, customer.longitude!),
                  infoWindow: InfoWindow(
                    title: customer.displayName,
                    snippet: customer.status.label,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    _hue(customer.status),
                  ),
                ),
            },
          ),
        );
      },
    );
  }

  double _hue(CustomerStatus status) {
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
