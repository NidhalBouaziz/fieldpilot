import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackPressedAt;

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
      (destination) => widget.location.startsWith(destination.path),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        body: SafeArea(child: widget.child),
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
      ),
    );
  }

  void _handleBack(BuildContext context) {
    final fallbackRoute = _fallbackRouteFor(widget.location);
    if (fallbackRoute != null) {
      context.go(fallbackRoute);
      return;
    }

    final now = DateTime.now();
    final shouldExit = _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);
    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Press back again to exit FieldPilot')),
      );
  }

  String? _fallbackRouteFor(String location) {
    if (location == '/dashboard') return null;
    if (location == '/customers/new' || location.startsWith('/customers/')) {
      return '/customers';
    }
    return '/dashboard';
  }
}

class _Destination {
  const _Destination(this.path, this.icon, this.label, [this.selectedIcon]);

  final String path;
  final IconData icon;
  final String label;
  final IconData? selectedIcon;
}
