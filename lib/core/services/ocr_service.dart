import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

const Map<String, String> _locationAliases = {
  'SAKIET EZZIT': 'SFAX',
  'SAKIET': 'SFAX',
  'FOUSSANA': 'KASSERINE',
  'KASSERINE': 'KASSERINE',
  'DOUALY': 'GAFSA',
  'GAFSA': 'GAFSA',
  'KAIROUAN': 'KAIROUAN',
  'DJERBA': 'MEDENINE',
  'GABES': 'GABES',
  'GABES MEDINA': 'GABES',
  'MEDNIN': 'MEDENINE',
  'MEDNINE': 'MEDENINE',
  'MEDENIN': 'MEDENINE',
  'MEDENINE': 'MEDENINE',
  'ELLOUZA': 'SFAX',
  'SFAX': 'SFAX',
  'REDEYEF': 'GAFSA',
  'REDEYIF': 'GAFSA',
  'KEBELI': 'KEBELI',
  'KEBILI': 'KEBELI',
  'KBELI': 'KEBELI',
  'KBELLI': 'KEBELI',
  'BOUHEL': 'SOUSSE',
  'BOUHELL': 'SOUSSE',
  'MSSAKEN': 'SOUSSE',
  'MSAKEN': 'SOUSSE',
  'HAFFOUZ': 'KAIROUAN',
  'SIDI MANSOUR': 'SFAX',
  'GHANNOUCHE': 'GABES',
  'GHANNOUCH': 'GABES',
  'MONASTIR': 'MONASTIR',
  'SOUSSE': 'SOUSSE',
  'TOZEUR': 'TOZEUR',
  'TUNIS': 'TUNIS',
  'FERIANA': 'KASSERINE',
  'EL HANCHA': 'SFAX',
  'HANCHA': 'SFAX',
  'REGUEB': 'SIDI BOUZID',
  'REGEUB': 'SIDI BOUZID',
  'BOUMERDESS': 'MAHDIA',
  'BOU MERDES': 'MAHDIA',
  'MAHDIA': 'MAHDIA',
  'NABEUL': 'NABEUL',
  'NABUL': 'NABEUL',
  'ARIANA': 'ARIANA',
  'BEN AROUS': 'BEN AROUS',
  'BENAROUS': 'BEN AROUS',
  'BIZERTE': 'BIZERTE',
  'BIZERTA': 'BIZERTE',
  'BEJA': 'BEJA',
  'JENDOUBA': 'JENDOUBA',
  'JANDOUBA': 'JENDOUBA',
  'EL KEF': 'KEF',
  'LE KEF': 'KEF',
  'KEF': 'KEF',
  'MANOUBA': 'MANOUBA',
  'MANUBA': 'MANOUBA',
  'SIDI BOUZID': 'SIDI BOUZID',
  'SIDI BOU ZID': 'SIDI BOUZID',
  'SIDIBOUZID': 'SIDI BOUZID',
  'SILIANA': 'SILIANA',
  'TATAOUINE': 'TATAOUINE',
  'TATAOUIN': 'TATAOUINE',
  'TATAWIN': 'TATAOUINE',
  'ZAGHOUAN': 'ZAGHOUAN',
  'ZAGHOUEN': 'ZAGHOUAN',
};

const List<String> _addressMarkers = [
  'RUE',
  'AV',
  'AVENUE',
  'CITE',
  'ROUTE',
  'RTE',
  'KM',
  'PLACE',
  'RES',
  'RESD',
  'RESIDENCE',
  'IMM',
  'IMMEUBLE',
  'APP',
  'ETAGE',
];

String guessCityFromAddress(String? address) {
  final value = _normalizeComparable(address ?? '');
  for (final entry in _locationAliases.entries) {
    final pattern = RegExp(
      r'(^|\s)' + RegExp.escape(entry.key) + r'(\s|$)',
    );
    if (pattern.hasMatch(value)) return entry.value;
  }
  return '';
}

String _cleanText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _normalizeComparable(String value) {
  return _cleanText(value)
      .toUpperCase()
      .replaceAll(RegExp(r'[().,;:-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

RegExpMatch? _addressMarkerMatch(String value) {
  final upper = value.toUpperCase();
  return RegExp(
    r'\b(' + _addressMarkers.map(RegExp.escape).join('|') + r')\b',
  ).firstMatch(upper);
}

bool _looksLikeLocationOnly(String value) {
  final normalized = _normalizeComparable(value);
  return normalized.isNotEmpty && _locationAliases.containsKey(normalized);
}

bool _looksLikeAddressLine(String value) {
  final normalized = _normalizeComparable(value);
  return _addressMarkerMatch(normalized) != null ||
      _looksLikeLocationOnly(normalized);
}

bool _isLikelyCustomerName(String value) {
  final normalized = _normalizeComparable(value);
  if (normalized.isEmpty) return false;
  if (_looksLikeAddressLine(normalized)) return false;
  if (_taxCode(normalized) != null) return false;
  if (_phone(normalized) != null && !RegExp(r'[A-Z]').hasMatch(normalized)) {
    return false;
  }

  final wordCount = RegExp(r'[A-Z]{2,}').allMatches(normalized).length;
  return wordCount >= 2;
}

({String? name, String? address}) _splitNameAndAddress(String value) {
  final cleaned = _cleanText(value);
  if (cleaned.isEmpty) return (name: null, address: null);

  final marker = _addressMarkerMatch(cleaned);
  if (marker != null && marker.start > 0) {
    final name = cleaned.substring(0, marker.start).trim();
    final address = cleaned.substring(marker.start).trim();
    if (_isLikelyCustomerName(name)) {
      return (
        name: name,
        address: address.isEmpty ? null : address,
      );
    }
  }

  final normalized = _normalizeNameAndAddress(cleaned, null);
  return (
    name: normalized.name.isEmpty ? null : normalized.name,
    address: normalized.address,
  );
}

({String name, String? address}) _normalizeNameAndAddress(
  String? name,
  String? address,
) {
  var normalizedName = _cleanText(name ?? '');
  var normalizedAddress = address == null ? null : _cleanText(address);
  if (normalizedName.isEmpty) {
    return (
      name: '',
      address: normalizedAddress?.isEmpty == true ? null : normalizedAddress,
    );
  }

  final parenthesizedCity = RegExp(r'\s+\(([A-Z ]+)\)$');
  final cityMatch = parenthesizedCity.firstMatch(normalizedName.toUpperCase());
  if (cityMatch != null) {
    final city = _normalizeComparable(cityMatch.group(1)!);
    if (_locationAliases.containsKey(city)) {
      normalizedName = normalizedName.substring(0, cityMatch.start).trim();
      normalizedAddress = [
        if (normalizedAddress?.isNotEmpty == true) normalizedAddress,
        _locationAliases[city],
      ].whereType<String>().join(' ').trim();
    }
  }

  final upperName = normalizedName.toUpperCase();
  for (final entry in _locationAliases.entries) {
    final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'$');
    final match = pattern.firstMatch(upperName);
    if (match == null) continue;

    final strippedName = normalizedName.substring(0, match.start).trim();
    if (strippedName.split(RegExp(r'\s+')).length < 2) {
      break;
    }

    final mergedAddress = [
      if (normalizedAddress?.isNotEmpty == true) normalizedAddress,
      normalizedName.substring(match.start, match.end).trim(),
    ].whereType<String>().join(' ').trim();

    return (
      name: strippedName,
      address: mergedAddress.isEmpty ? null : mergedAddress,
    );
  }

  return (
    name: normalizedName,
    address: normalizedAddress?.isEmpty == true ? null : normalizedAddress,
  );
}

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

  bool get isUsable => code.isNotEmpty && _isLikelyCustomerName(name);
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
          current.addInlineText(rest);
        }
        builders.add(current);
        continue;
      }

      if (current == null) continue;
      current.addInlineText(line);
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
    final firstLine = lines.isEmpty
        ? null
        : lines.first.replaceFirst(RegExp(r'^\d{5,6}\s*'), '');
    final normalized = _normalizeNameAndAddress(
      firstLine,
      lines.length > 2 ? lines.skip(1).take(2).join(', ') : null,
    );

    return ExtractedCustomerText(
      name: normalized.name.isEmpty ? null : normalized.name,
      phone: phone,
      email: email,
      address: normalized.address,
      city: guessCityFromAddress(
        normalized.address ?? (lines.length > 3 ? lines[3] : null),
      ),
      company: lines.length > 1 ? lines[1] : null,
      notes: null,
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

    final anchors = <_PositionedRowAnchor>[];
    final anchorLines = <TextLine>{};

    for (final line in lines) {
      final value = line.text.trim();
      if (value.isEmpty) continue;

      final x = line.boundingBox.left / pageWidth;
      final codeMatch = _rowStart(value);
      if (codeMatch != null && x < 0.46) {
        final builder = _CustomerRowBuilder(codeMatch.group(1)!);
        final rest = codeMatch.group(2)?.trim();
        if (rest != null && rest.isNotEmpty) {
          builder.addInlineText(rest);
        }
        anchors.add(_PositionedRowAnchor(line, builder));
        anchorLines.add(line);
      }
    }

    if (anchors.isEmpty) return extractRows(text.text);
    anchors.sort((a, b) => a.centerY.compareTo(b.centerY));

    for (final line in lines) {
      if (anchorLines.contains(line)) continue;
      final value = line.text.trim();
      if (value.isEmpty) continue;

      final anchor = _rowForLine(line, anchors);
      if (anchor == null) continue;

      final x = line.boundingBox.left / pageWidth;
      _assignColumn(anchor.builder, value, x);
    }

    final rows = anchors
        .map((anchor) => anchor.builder.build())
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

    if (x >= 0.80 || _taxCode(value) != null) {
      final taxCode = _taxCode(value);
      if (taxCode != null) row.taxCode = taxCode;
      return;
    }

    if (x < 0.38) {
      row.addInlineText(value);
      return;
    }

    if (x < 0.68) {
      row.addInlineText(value);
      return;
    }

    if (phone != null) {
      row.phone ??= phone;
    }
  }

  _PositionedRowAnchor? _rowForLine(
    TextLine line,
    List<_PositionedRowAnchor> anchors,
  ) {
    final y = line.boundingBox.top;
    for (var index = 0; index < anchors.length; index += 1) {
      final current = anchors[index];
      final next = index + 1 < anchors.length ? anchors[index + 1] : null;
      if (next == null) return current;

      final splitY = current.centerY + ((next.centerY - current.centerY) / 2);
      if (y < splitY) return current;
    }
    return anchors.last;
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
    final match = RegExp(r'^(\d{5,6})(?:\s+(.*)|$)').firstMatch(trimmed);
    if (match == null) return null;
    final rest = match.group(2)?.trim() ?? '';
    if (rest.isEmpty) return match;
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
}

class _PositionedRowAnchor {
  _PositionedRowAnchor(this.line, this.builder);

  final TextLine line;
  final _CustomerRowBuilder builder;

  double get centerY => line.boundingBox.center.dy;
}

class _CustomerRowBuilder {
  _CustomerRowBuilder(this.code);

  final String code;
  final List<String> _name = [];
  final List<String> _address = [];
  String? phone;
  String? taxCode;

  String get name => _name.join(' ').trim();

  void addInlineText(String value) {
    var remaining = _cleanText(value);
    if (remaining.isEmpty) return;

    final tax = _taxCode(remaining);
    if (tax != null) {
      taxCode = tax;
      remaining = _cleanText(remaining.replaceFirst(tax, ''));
    }

    final linePhone = _phoneMatch(remaining);
    if (linePhone != null) {
      phone ??= linePhone.display;
      remaining = _cleanText(remaining.replaceFirst(linePhone.source, ''));
    }

    if (remaining.isEmpty) return;
    if (RegExp(r'^\d+$').hasMatch(remaining)) return;

    if (_name.isEmpty) {
      final split = _splitNameAndAddress(remaining);
      if (split.name != null) addName(split.name!);
      if (split.address != null) addAddress(split.address!);
      return;
    }

    if (_looksLikeAddressLine(remaining)) {
      addAddress(remaining);
      return;
    }

    final split = _splitNameAndAddress(remaining);
    if (split.address != null && split.name != null) {
      addAddress(split.address!);
      return;
    }

    addAddress(remaining);
  }

  void addName(String value) {
    final cleaned = _cleanText(value);
    if (cleaned.isEmpty || RegExp(r'^\d+$').hasMatch(cleaned)) return;
    if (_looksLikeAddressLine(cleaned)) {
      addAddress(cleaned);
      return;
    }
    _name.add(cleaned);
  }

  void addAddress(String value) {
    final cleaned = _cleanText(value);
    if (cleaned.isEmpty) return;
    _address.add(cleaned);
  }

  ExtractedCustomerRow build() {
    final normalized = _normalizeNameAndAddress(
      name,
      _address.isEmpty ? null : _address.join(' '),
    );
    return ExtractedCustomerRow(
      code: code,
      name: normalized.name,
      address: normalized.address,
      phone: phone,
      taxCode: taxCode,
    );
  }
}

String? _taxCode(String value) {
  return RegExp(
    r'(?<!\d)(\d{5,}(?:/[A-Z]|[A-Z])[A-Z0-9]*)(?![A-Z0-9])',
    caseSensitive: false,
  ).firstMatch(value.trim())?.group(1);
}

String? _phone(String value) {
  return _phoneMatch(value)?.display;
}

_PhoneMatch? _phoneMatch(String value) {
  final withoutTaxCodes = value.replaceAll(
    RegExp(
      r'(?<![A-Z0-9])\d{5,}(?:/[A-Z]|[A-Z])[A-Z0-9]*(?![A-Z0-9])',
      caseSensitive: false,
    ),
    ' ',
  );
  final expression = RegExp(r'(?<![A-Z0-9])(\d(?:[\s.-]?\d){7})(?![A-Z0-9])');
  for (final match in expression.allMatches(withoutTaxCodes)) {
    final source = match.group(1)!;
    final digits = source.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) continue;
    if (!_looksLikeTunisianPhone(digits)) continue;
    return _PhoneMatch(source: source, display: _cleanText(source));
  }
  return null;
}

bool _looksLikeTunisianPhone(String digits) {
  if (digits.length != 8) return false;
  final prefix = int.tryParse(digits.substring(0, 2));
  if (prefix == null) return false;
  return (prefix >= 20 && prefix <= 29) ||
      (prefix >= 30 && prefix <= 39) ||
      (prefix >= 40 && prefix <= 49) ||
      (prefix >= 50 && prefix <= 59) ||
      (prefix >= 70 && prefix <= 79) ||
      (prefix >= 90 && prefix <= 99);
}

class _PhoneMatch {
  const _PhoneMatch({required this.source, required this.display});

  final String source;
  final String display;
}
