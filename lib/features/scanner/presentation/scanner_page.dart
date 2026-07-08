import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/repositories/providers.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  final _rawText = TextEditingController();
  Customer? _reviewCustomer;

  @override
  void dispose() {
    _rawText.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    final extracted = await ref.read(ocrServiceProvider).extract(_rawText.text);
    final now = DateTime.now();
    final parts = (extracted.name ?? '').split(RegExp(r'\s+'));
    setState(() {
      _reviewCustomer = Customer(
        id: ref.read(idGeneratorProvider)(),
        firstName: parts.isEmpty ? '' : parts.first,
        lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
        companyName: extracted.company ?? '',
        phone: extracted.phone ?? '',
        email: extracted.email,
        address: extracted.address,
        city: extracted.city ?? '',
        governorate: '',
        notes: extracted.notes,
        status: CustomerStatus.neverVisited,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  Future<void> _save() async {
    final customer = _reviewCustomer;
    if (customer == null) return;
    await ref.read(customerRepositoryProvider).save(customer);
    ref.invalidate(customersProvider);
    ref.invalidate(dashboardSnapshotProvider);
    setState(() {
      _reviewCustomer = null;
      _rawText.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR scanner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _rawText,
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Recognized text',
              hintText:
                  'Paste OCR text from camera, gallery, or PDF import for review.',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _extract,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Extract fields'),
          ),
          if (_reviewCustomer != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review before saving',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_reviewCustomer!.displayName),
                    Text(_reviewCustomer!.companyName),
                    Text(_reviewCustomer!.phone),
                    if (_reviewCustomer!.email != null)
                      Text(_reviewCustomer!.email!),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save customer'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
