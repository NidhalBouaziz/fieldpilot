import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/customer.dart';
import '../../../core/repositories/providers.dart';
import '../../../core/services/customer_import_resolver.dart';
import '../../../core/services/ocr_service.dart';
import '../../../shared/widgets/logout_button.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage>
    with WidgetsBindingObserver {
  final _rawText = TextEditingController();
  final _picker = ImagePicker();
  Customer? _reviewCustomer;
  List<Customer> _bulkCustomers = const [];
  String? _sourceLabel;
  String? _scanProgressLabel;
  double? _scanProgress;
  OcrScanCancellationToken? _pdfScanToken;
  bool _busy = false;
  bool _savingBulk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _cancelPdfScan(showMessage: false);
    WidgetsBinding.instance.removeObserver(this);
    _rawText.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cancelPdfScan(showMessage: false);
    }
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
        maxWidth: 4096,
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

      if (mounted) {
        setState(() => _busy = false);
      }
      if (!mounted) return;

      final range = await _choosePdfPageRange(file.name);
      if (range == null) return;

      setState(() {
        _busy = true;
        _sourceLabel = 'Reading PDF: ${file.name}';
        _scanProgress = 0;
        _scanProgressLabel =
            'Scanning pages ${range.firstPage}-${range.lastPage}';
        _reviewCustomer = null;
        _bulkCustomers = const [];
      });

      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) {
        throw StateError('Could not read PDF bytes.');
      }

      final token = OcrScanCancellationToken();
      setState(() {
        _pdfScanToken = token;
      });
      final document = await ref.read(ocrServiceProvider).recognizePdf(
        bytes,
        pages: range.zeroBasedPages,
        cancellationToken: token,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _scanProgress = progress.fraction;
            _scanProgressLabel = 'Scanned page ${progress.pageNumber} '
                '(${progress.completedPages}/${progress.totalPages})';
          });
        },
      );
      _pdfScanToken = null;
      _rawText.text = document.rawText;
      _sourceLabel = 'PDF: ${file.name}';

      if (document.rawText.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No readable text found in this PDF.')),
        );
        setState(() {
          _reviewCustomer = null;
          _bulkCustomers = const [];
        });
        return;
      }

      if (document.rows.length > 1) {
        _setBulkCustomers(document.rows);
      } else {
        await _extract();
      }
      setState(() {
        _sourceLabel = 'PDF: ${file.name}';
      });
    } on OcrScanCancelled {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF scan cancelled.')),
      );
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
      if (mounted) {
        setState(() {
          _busy = false;
          _scanProgress = null;
          _scanProgressLabel = null;
          _pdfScanToken = null;
        });
      } else {
        _pdfScanToken = null;
      }
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
    if (rows.isNotEmpty) {
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
    if (_savingBulk || _bulkCustomers.isEmpty) return;
    setState(() => _savingBulk = true);
    final repository = ref.read(customerRepositoryProvider);
    try {
      final existingCustomers = await repository.list(includeArchived: true);
      final importResult = resolveCustomerImport(
        _bulkCustomers,
        existingCustomers,
      );

      for (final customer in importResult.customersToSave) {
        await repository.save(customer);
      }
      ref.invalidate(customersProvider);
      ref.invalidate(dashboardSnapshotProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(importResult.message)),
      );
      setState(() {
        _bulkCustomers = const [];
        _reviewCustomer = null;
        _rawText.clear();
        _sourceLabel = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save customers: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingBulk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bulkWarningCount = _bulkCustomers
        .where((customer) => _customerWarnings(customer).isNotEmpty)
        .length;

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
            LinearProgressIndicator(value: _scanProgress),
            if (_scanProgressLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                _scanProgress == null
                    ? _scanProgressLabel!
                    : '$_scanProgressLabel '
                        '(${(_scanProgress! * 100).round()}%)',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_pdfScanToken != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _cancelPdfScan(),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Cancel scan'),
              ),
            ],
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
                    if (bulkWarningCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$bulkWarningCount rows need review before saving',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    for (final entry
                        in _bulkCustomers.take(20).toList().asMap().entries)
                      _BulkCustomerTile(
                        index: entry.key,
                        customer: entry.value,
                        warnings: _customerWarnings(entry.value),
                        onRemove: _savingBulk
                            ? null
                            : () => _removeBulkCustomer(entry.key),
                      ),
                    if (_bulkCustomers.length > 20)
                      Text('+ ${_bulkCustomers.length - 20} more'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _savingBulk ? null : _saveBulk,
                      icon: _savingBulk
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.playlist_add_check),
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

  List<String> _customerWarnings(Customer customer) {
    final warnings = <String>[];
    final name = customer.displayName.trim();
    if (name.isEmpty) {
      warnings.add('Missing name');
    }
    if (RegExp(r'\d').hasMatch(name)) {
      warnings.add('Name has digits');
    }
    if (RegExp(
      r'\b(RUE|AV|AVENUE|RTE|ROUTE|IMM|RES|KM|CITE)\b',
      caseSensitive: false,
    ).hasMatch(name)) {
      warnings.add('Name looks like address');
    }
    if ((customer.address == null || customer.address!.trim().isEmpty) &&
        customer.city.trim().isEmpty) {
      warnings.add('Missing location');
    }
    if (customer.address != null &&
        RegExp(
          r'\d{5,}(?:/[A-Z]|[A-Z])[A-Z0-9]*',
          caseSensitive: false,
        ).hasMatch(customer.address!)) {
      warnings.add('Address has identifier');
    }
    final notes = customer.notes ?? '';
    final tvaCount = RegExp(
      'Code TVA:',
      caseSensitive: false,
    ).allMatches(notes).length;
    if (tvaCount > 1) {
      warnings.add('Multiple TVA codes');
    }
    return warnings;
  }

  void _setBulkCustomers(List<ExtractedCustomerRow> rows) {
    final now = DateTime.now();
    final customers = rows.map((row) {
      final nameParts = row.name.trim().split(RegExp(r'\s+'));
      final city = guessCityFromAddress(row.address);
      final notes = [
        if (row.code.isNotEmpty) 'Code client: ${row.code}',
        if (row.taxCode != null) 'Code TVA: ${row.taxCode}',
      ];
      return Customer(
        id: ref.read(idGeneratorProvider)(),
        firstName: nameParts.isEmpty ? row.name : nameParts.first,
        lastName: nameParts.length > 1 ? nameParts.skip(1).join(' ') : '',
        companyName: row.name,
        phone: row.phone ?? '',
        address: row.address,
        city: city,
        governorate: city,
        notes: notes.isEmpty ? null : notes.join('\n'),
        status: CustomerStatus.neverVisited,
        createdAt: now,
        updatedAt: now,
        tags: ['bulk-scan', if (row.code.isNotEmpty) row.code],
      );
    }).toList();

    setState(() {
      _reviewCustomer = null;
      _bulkCustomers = customers;
    });
  }

  void _removeBulkCustomer(int index) {
    setState(() {
      _bulkCustomers = [
        for (var i = 0; i < _bulkCustomers.length; i += 1)
          if (i != index) _bulkCustomers[i],
      ];
    });
  }

  void _cancelPdfScan({bool showMessage = true}) {
    final token = _pdfScanToken;
    if (token == null) return;
    token.cancel();
    if (!mounted) return;
    setState(() {
      _scanProgressLabel = 'Cancelling scan...';
    });
    if (showMessage) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Cancelling PDF scan...')),
        );
    }
  }

  Future<_PdfPageRange?> _choosePdfPageRange(String fileName) async {
    final firstPage = TextEditingController(text: '1');
    final lastPage = TextEditingController(text: '1');
    String? error;

    try {
      return await showDialog<_PdfPageRange>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Choose PDF pages'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstPage,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'From page',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: lastPage,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'To'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Use printed page numbers. Example: 75 to 80.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final first = int.tryParse(firstPage.text.trim());
                    final last = int.tryParse(lastPage.text.trim());
                    if (first == null || last == null) {
                      setDialogState(() {
                        error = 'Enter valid page numbers.';
                      });
                      return;
                    }
                    if (first < 1 || last < first) {
                      setDialogState(() {
                        error = 'The page range must start at 1 or higher.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(
                      _PdfPageRange(firstPage: first, lastPage: last),
                    );
                  },
                  child: const Text('Scan range'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      firstPage.dispose();
      lastPage.dispose();
    }
  }
}

class _BulkCustomerTile extends StatelessWidget {
  const _BulkCustomerTile({
    required this.index,
    required this.customer,
    required this.warnings,
    required this.onRemove,
  });

  final int index;
  final Customer customer;
  final List<String> warnings;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasWarnings = warnings.isNotEmpty;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: hasWarnings
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        child: Text('${index + 1}'),
      ),
      title: Text(customer.displayName),
      subtitle: Text(
        [
          if (hasWarnings) 'Review: ${warnings.join(', ')}',
          [
            if (customer.city.isNotEmpty) customer.city,
            if (customer.phone.isNotEmpty) customer.phone,
            if (customer.address != null) customer.address!,
          ].join(' | '),
        ].where((part) => part.isNotEmpty).join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.close),
        tooltip: 'Remove row',
      ),
    );
  }
}

class _PdfPageRange {
  const _PdfPageRange({required this.firstPage, required this.lastPage});

  final int firstPage;
  final int lastPage;

  List<int> get zeroBasedPages {
    return [
      for (var page = firstPage; page <= lastPage; page++) page - 1,
    ];
  }
}
