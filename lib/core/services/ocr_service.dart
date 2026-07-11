import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class OcrDocument {
  const OcrDocument({required this.rawText, required this.rows});

  final String rawText;
  final List<ExtractedCustomerRow> rows;
}

class PdfOcrProgress {
  const PdfOcrProgress({
    required this.completedPages,
    required this.totalPages,
    required this.pageNumber,
  });

  final int completedPages;
  final int totalPages;
  final int pageNumber;

  double get fraction => totalPages == 0 ? 0 : completedPages / totalPages;
}

class OcrScanCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class OcrScanCancelled implements Exception {
  const OcrScanCancelled();

  @override
  String toString() => 'OCR scan cancelled.';
}

class ExtractedCustomerRow {
  const ExtractedCustomerRow({
    required this.code,
    required this.name,
    this.address,
    this.phone,
    this.taxCode,
  });

  final String code;
  final String name;
  final String? address;
  final String? phone;
  final String? taxCode;

  bool get hasData =>
      name.trim().isNotEmpty ||
      address?.trim().isNotEmpty == true ||
      phone?.trim().isNotEmpty == true ||
      taxCode?.trim().isNotEmpty == true;

  bool get isUsable => code.isNotEmpty && hasData;
}

class ExtractedCustomerText {
  const ExtractedCustomerText({
    this.name,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.company,
    this.notes,
  });

  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? company;
  final String? notes;
}

class OcrService {
  Future<String> recognizeImage(String imagePath) async {
    return (await recognizeDocument(imagePath)).rawText;
  }

  Future<OcrDocument> recognizeDocument(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(image);
      return OcrDocument(
        rawText: recognizedText.text,
        rows: _rowsFromRecognizedText(recognizedText),
      );
    } finally {
      await recognizer.close();
    }
  }

  Future<OcrDocument> recognizePdf(
    Uint8List pdfBytes, {
    required List<int> pages,
    void Function(PdfOcrProgress progress)? onProgress,
    OcrScanCancellationToken? cancellationToken,
  }) async {
    if (pages.isEmpty) {
      throw ArgumentError.value(pages, 'pages', 'Choose at least one page.');
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final tempDirectory = await getTemporaryDirectory();
    final session = DateTime.now().microsecondsSinceEpoch;
    final rawPages = <String>[];
    final positionedRows = <ExtractedCustomerRow>[];
    var pageIndex = 0;

    try {
      await for (final page in Printing.raster(
        pdfBytes,
        pages: pages,
        dpi: 220,
      )) {
        _throwIfCancelled(cancellationToken);
        pageIndex += 1;
        final pageNumber = pages[pageIndex - 1] + 1;
        final pageFile = File(
          '${tempDirectory.path}/fieldpilot_pdf_${session}_$pageIndex.png',
        );
        final pngBytes = await page.toPng();
        _throwIfCancelled(cancellationToken);
        await pageFile.writeAsBytes(pngBytes, flush: true);

        try {
          _throwIfCancelled(cancellationToken);
          final image = InputImage.fromFilePath(pageFile.path);
          final recognizedText = await recognizer.processImage(image);
          _throwIfCancelled(cancellationToken);
          if (recognizedText.text.trim().isNotEmpty) {
            rawPages.add(recognizedText.text);
          }
          positionedRows.addAll(_rowsFromRecognizedText(recognizedText));
        } finally {
          if (await pageFile.exists()) {
            await pageFile.delete();
          }
        }
        onProgress?.call(
          PdfOcrProgress(
            completedPages: pageIndex,
            totalPages: pages.length,
            pageNumber: pageNumber,
          ),
        );
      }

      final rawText = rawPages.join('\n');
      return OcrDocument(
        rawText: rawText,
        rows: _bestRows(positionedRows, extractRows(rawText)),
      );
    } finally {
      await recognizer.close();
    }
  }

  void _throwIfCancelled(OcrScanCancellationToken? token) {
    if (token?.isCancelled == true) {
      throw const OcrScanCancelled();
    }
  }

  List<ExtractedCustomerRow> extractRows(String rawText) {
    final builders = <_CustomerRowBuilder>[];
    _CustomerRowBuilder? current;

    for (final line in _logicalLines(rawText)) {
      if (_isHeaderLine(line)) continue;
      final codeMatch = _rowStart(line);
      if (codeMatch != null) {
        current = _CustomerRowBuilder(codeMatch.group(1)!);
        final rest = codeMatch.group(2)?.trim();
        if (rest != null && rest.isNotEmpty) {
          current.addName(rest);
        }
        builders.add(current);
        continue;
      }

      if (current == null) continue;
      final phone = _phone(line);
      if (phone != null && current.phone == null) {
        current.phone = phone;
      } else if (_looksLikeTaxCode(line)) {
        current.taxCode = line;
      } else if (current.name.isEmpty) {
        current.addName(line);
      } else {
        current.addAddress(line);
      }
    }

    return builders
        .map((builder) => builder.build())
        .where((row) => row.isUsable)
        .toList();
  }

  Future<ExtractedCustomerText> extract(String rawText) async {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final email = RegExp(
      r'[\w.+-]+@[\w.-]+\.\w+',
    ).firstMatch(rawText)?.group(0);
    final phone = RegExp(
      r'(\+?\d[\d\s().-]{7,}\d)',
    ).firstMatch(rawText)?.group(0);

    return ExtractedCustomerText(
      name: lines.isEmpty ? null : lines.first,
      phone: phone,
      email: email,
      address: lines.length > 2 ? lines.skip(1).take(2).join(', ') : null,
      city: lines.length > 3 ? lines[3] : null,
      company: lines.length > 1 ? lines[1] : null,
      notes: rawText,
    );
  }

  List<ExtractedCustomerRow> _rowsFromRecognizedText(RecognizedText text) {
    final lines = [
      for (final block in text.blocks)
        for (final line in block.lines)
          if (!_isHeaderLine(line.text)) line,
    ]..sort((a, b) {
        final top = a.boundingBox.top.compareTo(b.boundingBox.top);
        return top == 0
            ? a.boundingBox.left.compareTo(b.boundingBox.left)
            : top;
      });

    if (lines.isEmpty) return const [];
    final pageWidth = lines
        .map((line) => line.boundingBox.right)
        .fold<double>(1, (max, value) => value > max ? value : max);

    final builders = <_CustomerRowBuilder>[];
    _CustomerRowBuilder? current;

    for (final line in lines) {
      final value = line.text.trim();
      if (value.isEmpty) continue;

      final x = line.boundingBox.left / pageWidth;
      final codeMatch = _rowStart(value);
      if (codeMatch != null && x < 0.46) {
        current = _CustomerRowBuilder(codeMatch.group(1)!);
        final rest = codeMatch.group(2)?.trim();
        if (rest != null && rest.isNotEmpty) {
          current.addName(rest);
        }
        builders.add(current);
        continue;
      }

      if (current == null) continue;
      _assignColumn(current, value, x);
    }

    final rows = builders
        .map((builder) => builder.build())
        .where((row) => row.isUsable)
        .toList();
    final textRows = extractRows(text.text);
    return _bestRows(rows, textRows);
  }

  void _assignColumn(_CustomerRowBuilder row, String value, double x) {
    final phone = _phone(value);
    if (phone != null && x > 0.55 && x < 0.82) {
      row.phone ??= phone;
      return;
    }

    if (x >= 0.80 || _looksLikeTaxCode(value)) {
      if (_looksLikeTaxCode(value)) row.taxCode = value;
      return;
    }

    if (x < 0.38) {
      row.addName(value);
      return;
    }

    if (x < 0.68) {
      row.addAddress(value);
      return;
    }

    if (phone != null) {
      row.phone ??= phone;
    }
  }

  List<String> _logicalLines(String rawText) {
    final lines = <String>[];
    final rowBreak = RegExp(r'\s+(?=\d{5,6}\s+[A-Z][A-Z(])');
    for (final sourceLine in rawText.split(RegExp(r'\r?\n'))) {
      final normalized = sourceLine.trim();
      if (normalized.isEmpty) continue;
      lines.addAll(
        normalized
            .replaceAll(rowBreak, '\n')
            .split('\n')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    }
    return lines;
  }

  RegExpMatch? _rowStart(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^(\d{5,6})\s*(.*)$').firstMatch(trimmed);
    if (match == null) return null;
    final rest = match.group(2)?.trim() ?? '';
    if (rest.isEmpty) return match;
    if (_looksLikeTaxCode(trimmed)) return null;
    if (RegExp(r'^\d[\d\s]{5,}$').hasMatch(trimmed)) return null;
    return match;
  }

  List<ExtractedCustomerRow> _bestRows(
    List<ExtractedCustomerRow> positionedRows,
    List<ExtractedCustomerRow> textRows,
  ) {
    final winner =
        positionedRows.length >= textRows.length ? positionedRows : textRows;
    final fallback =
        identical(winner, positionedRows) ? textRows : positionedRows;
    final merged = <ExtractedCustomerRow>[];
    final seen = <String>{};

    for (final row in [...winner, ...fallback]) {
      final key = '${row.code}|${row.name.toUpperCase()}';
      if (seen.add(key)) merged.add(row);
    }
    return merged;
  }

  bool _isHeaderLine(String line) {
    final value = line.toLowerCase();
    return value.contains('etat des clients') ||
        value.contains('repr') ||
        value == 'code' ||
        value.contains('raison sociale') ||
        value == 'adresse' ||
        value == 'tel' ||
        value == 'fax' ||
        value.contains('code tva') ||
        value.contains('page :') ||
        value.contains('edite le') ||
        value.contains('distrimed 2025');
  }

  String? _phone(String value) {
    final match = RegExp(r'(?<!\d)(\d[\d\s]{6,12}\d)(?!\d)').firstMatch(value);
    return match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _looksLikeTaxCode(String value) {
    return RegExp(
      r'\d{5,}[A-Z]{1,4}\d{0,4}',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }
}

class _CustomerRowBuilder {
  _CustomerRowBuilder(this.code);

  final String code;
  final List<String> _name = [];
  final List<String> _address = [];
  String? phone;
  String? taxCode;

  String get name => _name.join(' ').trim();

  void addName(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || RegExp(r'^\d+$').hasMatch(cleaned)) return;
    if (RegExp(
      r'^(RUE|AV|AVENUE|CITE|ROUTE|RTE|KM|PLACE|RES|RESIDENCE)\b',
    ).hasMatch(cleaned.toUpperCase())) {
      addAddress(cleaned);
      return;
    }
    _name.add(cleaned);
  }

  void addAddress(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    _address.add(cleaned);
  }

  ExtractedCustomerRow build() {
    final displayName = name.isEmpty ? 'Client $code' : name;
    return ExtractedCustomerRow(
      code: code,
      name: displayName,
      address: _address.isEmpty ? null : _address.join(' '),
      phone: phone,
      taxCode: taxCode,
    );
  }
}
