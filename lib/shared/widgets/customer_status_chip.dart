import 'package:flutter/material.dart';

import '../../core/models/customer.dart';

class CustomerStatusChip extends StatelessWidget {
  const CustomerStatusChip({required this.status, super.key});

  final CustomerStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      CustomerStatus.neverVisited => Colors.grey,
      CustomerStatus.planned => Colors.blue,
      CustomerStatus.customer => Colors.green,
      CustomerStatus.followUp => Colors.amber,
      CustomerStatus.interested => Colors.orange,
      CustomerStatus.notInterested => Colors.red,
      CustomerStatus.archived => Colors.blueGrey,
    };

    return Chip(
      label: Text(status.label),
      avatar: CircleAvatar(backgroundColor: color, radius: 4),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      side: BorderSide(color: color.withValues(alpha: 0.22)),
      backgroundColor: color.withValues(alpha: 0.10),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    );
  }
}
