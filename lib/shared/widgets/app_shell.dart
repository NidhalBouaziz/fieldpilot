import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _destinations = [
    _Destination(
      '/dashboard',
      Icons.space_dashboard_outlined,
      'Today',
      Icons.space_dashboard,
    ),
    _Destination(
      '/customers',
      Icons.people_alt_outlined,
      'Customers',
      Icons.people_alt,
    ),
    _Destination(
      '/visits',
      Icons.event_available_outlined,
      'Visits',
      Icons.event_available,
    ),
    _Destination(
      '/scanner',
      Icons.document_scanner_outlined,
      'Scan',
      Icons.document_scanner,
    ),
    _Destination('/map', Icons.map_outlined, 'Map', Icons.map),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedIndex = _destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          onDestinationSelected: (index) =>
              context.go(_destinations[index].path),
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.path, this.icon, this.label, [this.selectedIcon]);

  final String path;
  final IconData icon;
  final String label;
  final IconData? selectedIcon;
}
