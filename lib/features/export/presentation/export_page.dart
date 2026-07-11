import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/providers.dart';
import '../../../shared/widgets/logout_button.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  String _preview = '';

  Future<void> _buildJson() async {
    final customers =
        await ref.read(customerRepositoryProvider).list(includeArchived: true);
    final visits = await ref.read(visitRepositoryProvider).list();
    const encoder = JsonEncoder.withIndent('  ');
    setState(() {
      _preview = encoder.convert({
        'customers': customers.map((customer) => customer.toJson()).toList(),
        'visits': visits.map((visit) => visit.toJson()).toList(),
      });
    });
  }

  Future<void> _buildCsv() async {
    final customers =
        await ref.read(customerRepositoryProvider).list(includeArchived: true);
    final rows = [
      'id,name,company,phone,email,city,status',
      for (final customer in customers)
        [
          customer.id,
          customer.displayName,
          customer.companyName,
          customer.phone,
          customer.email ?? '',
          customer.city,
          customer.status.name,
        ].map(_escape).join(','),
    ];
    setState(() => _preview = rows.join('\n'));
  }

  String _escape(String value) => '"${value.replaceAll('"', '""')}"';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        actions: const [LogoutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _buildJson,
                icon: const Icon(Icons.data_object),
                label: const Text('JSON'),
              ),
              OutlinedButton.icon(
                onPressed: _buildCsv,
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _buildJson,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF data'),
              ),
              OutlinedButton.icon(
                onPressed: _buildJson,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Backup'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            _preview.isEmpty ? 'Choose an export format.' : _preview,
          ),
        ],
      ),
    );
  }
}
