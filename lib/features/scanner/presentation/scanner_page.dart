import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/customer.dart';
import '../../../core/repositories/providers.dart';
import '../../../core/services/ocr_service.dart';
import '../../../shared/widgets/logout_button.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  final _rawText = TextEditingController();
  final _picker = ImagePicker();
  Customer? _reviewCustomer;
  List<Customer> _bulkCustomers = const [];
  String? _sourceLabel;
  bool _busy = false;

  @override
  void dispose() {
    _rawText.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> _importImage() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 3200,
      );
      if (image == null) return;

      final document =
          await ref.read(ocrServiceProvider).recognizeDocument(image.path);
      _rawText.text = document.rawText;
      _sourceLabel =
          source == ImageSource.camera ? 'Camera photo' : 'Gallery image';
      if (document.rows.length > 1) {
        _setBulkCustomers(document.rows);
      } else {
        await _extract();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not scan image: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importPdf() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      final file = result?.files.single;
      if (file == null) return;

      _sourceLabel = 'PDF: ${file.name}';
      _rawText.text = [
        'PDF: ${file.name}',
        if (file.size > 0) 'Size: ${_formatBytes(file.size)}',
      ].join('\n');
      setState(() {
        _reviewCustomer = null;
        _bulkCustomers = const [];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extract() async {
    final rawText = _rawText.text.trim();
    if (rawText.isEmpty) {
      setState(() {
        _reviewCustomer = null;
        _bulkCustomers = const [];
      });
      return;
    }

    final rows = ref.read(ocrServiceProvider).extractRows(rawText);
    if (rows.length > 1) {
      _setBulkCustomers(rows);
      return;
    }

    final extracted = await ref.read(ocrServiceProvider).extract(_rawText.text);
    final now = DateTime.now();
    final parts = (extracted.name ?? '').trim().split(RegExp(r'\s+'));
    setState(() {
      _bulkCustomers = const [];
      _reviewCustomer = Customer(
        id: ref.read(idGeneratorProvider)(),
        firstName: parts.isEmpty ? '' : parts.first,
        lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
        companyName: extracted.company ?? '',
        phone: extracted.phone ?? '',
        email: extracted.email,
        address: extracted.address,
        city: extracted.city ?? '',
        governorate: extracted.city ?? '',
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
      _bulkCustomers = const [];
      _rawText.clear();
      _sourceLabel = null;
    });
  }

  Future<void> _saveBulk() async {
    if (_bulkCustomers.isEmpty) return;
    final repository = ref.read(customerRepositoryProvider);
    for (final customer in _bulkCustomers) {
      await repository.save(customer);
    }
    ref.invalidate(customersProvider);
    ref.invalidate(dashboardSnapshotProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${_bulkCustomers.length} customers')),
    );
    setState(() {
      _bulkCustomers = const [];
      _reviewCustomer = null;
      _rawText.clear();
      _sourceLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document scanner'),
        actions: const [LogoutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk customer import',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bulkCustomers.isEmpty
                            ? 'Ready to scan customer tables'
                            : '${_bulkCustomers.length} customers detected',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _capturePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _importImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _importPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF'),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_sourceLabel != null) ...[
            const SizedBox(height: 12),
            Chip(
              avatar: const Icon(Icons.description_outlined, size: 18),
              label: Text(_sourceLabel!),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Recognized text',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rawText,
                    minLines: 7,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Document text',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _extract,
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: const Text('Extract customers'),
                  ),
                ],
              ),
            ),
          ),
          if (_bulkCustomers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk review',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_bulkCustomers.length} customers detected',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    for (final entry
                        in _bulkCustomers.take(20).toList().asMap().entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('${entry.key + 1}'),
                        ),
                        title: Text(entry.value.displayName),
                        subtitle: Text(
                          [
                            if (entry.value.city.isNotEmpty) entry.value.city,
                            if (entry.value.phone.isNotEmpty) entry.value.phone,
                            if (entry.value.address != null)
                              entry.value.address!,
                          ].join(' | '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_bulkCustomers.length > 20)
                      Text('+ ${_bulkCustomers.length - 20} more'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saveBulk,
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Save all customers'),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  void _setBulkCustomers(List<ExtractedCustomerRow> rows) {
    final now = DateTime.now();
    final customers = rows.map((row) {
      final nameParts = row.name.trim().split(RegExp(r'\s+'));
      final city = _guessCity(row.address);
      return Customer(
        id: ref.read(idGeneratorProvider)(),
        firstName: nameParts.isEmpty ? row.name : nameParts.first,
        lastName: nameParts.length > 1 ? nameParts.skip(1).join(' ') : '',
        companyName: row.name,
        phone: row.phone ?? '',
        address: row.address,
        city: city,
        governorate: city,
        notes: [
          'Code client: ${row.code}',
          if (row.taxCode != null) 'Code TVA: ${row.taxCode}',
        ].join('\n'),
        status: CustomerStatus.neverVisited,
        createdAt: now,
        updatedAt: now,
        tags: ['bulk-scan', row.code],
      );
    }).toList();

    setState(() {
      _reviewCustomer = null;
      _bulkCustomers = customers;
    });
  }

  String _guessCity(String? address) {
    final value = address?.toUpperCase() ?? '';
    const aliases = {
      'SAKIET EZZIT': 'SAKIET EZZIT',
      'SAKIET': 'SAKIET EZZIT',
      'FOUSSANA': 'FOUSSANA',
      'KASSERINE': 'KASSERINE',
      'DOUALY': 'GAFSA',
      'GAFSA': 'GAFSA',
      'KAIROUAN': 'KAIROUAN',
      'DJERBA': 'DJERBA',
      'GABES': 'GABES',
      'MEDNIN': 'MEDNIN',
      'MEDENINE': 'MEDENINE',
      'ELLOUZA': 'ELLOUZA',
      'SFAX': 'SFAX',
      'REDEYEF': 'REDEYEF',
      'KEBELI': 'KEBELI',
      'BOUHEL': 'BOUHEL',
      'BOUHELL': 'BOUHEL',
      'MSSAKEN': 'MSSAKEN',
      'HAFFOUZ': 'HAFFOUZ',
      'SIDI MANSOUR': 'SIDI MANSOUR',
      'GHANNOUCHE': 'GHANNOUCHE',
      'MONASTIR': 'MONASTIR',
      'SOUSSE': 'SOUSSE',
      'TOZEUR': 'TOZEUR',
      'TUNIS': 'TUNIS',
      'FERIANA': 'FERIANA',
    };
    for (final entry in aliases.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    return '';
  }
}
