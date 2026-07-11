import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrDocument {
  const OcrDocument({required this.rawText, required this.rows});

  final String rawText;
  final List<ExtractedCustomerRow> rows;
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

  bool get isUsable => code.isNotEmpty && name.trim().length >= 3;
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

  List<ExtractedCustomerRow> extractRows(String rawText) {
    final builders = <_CustomerRowBuilder>[];
    _CustomerRowBuilder? current;

    for (final line in rawText
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)) {
      if (_isHeaderLine(line)) continue;
      final codeMatch = RegExp(r'^(\d{5,6})\s*(.*)$').firstMatch(line);
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
      if (_phone(line) != null && current.phone == null) {
        current.phone = _phone(line);
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
      final codeMatch = RegExp(r'^(\d{5,6})\s*(.*)$').firstMatch(value);
      if (codeMatch != null && x < 0.24) {
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
    return rows.length > 1 ? rows : extractRows(text.text);
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

  bool _isHeaderLine(String line) {
    final value = line.toLowerCase();
    return value.contains('etat des clients') ||
        value.contains('représentant') ||
        value.contains('representant') ||
        value == 'code' ||
        value.contains('raison sociale') ||
        value == 'adresse' ||
        value == 'tél' ||
        value == 'tel' ||
        value == 'fax' ||
        value.contains('code tva') ||
        value.contains('page :') ||
        value.contains('edité le') ||
        value.contains('edite le') ||
        value.contains('distrimed 2025');
  }

  String? _phone(String value) {
    final match = RegExp(r'(?<!\d)(\d[\d\s]{6,12}\d)(?!\d)').firstMatch(value);
    return match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _looksLikeTaxCode(String value) {
    return RegExp(r'\d{5,}[A-Z]{1,4}\d{0,4}', caseSensitive: false)
        .hasMatch(value.trim());
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
    _name.add(cleaned);
  }

  void addAddress(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    _address.add(cleaned);
  }

  ExtractedCustomerRow build() {
    return ExtractedCustomerRow(
      code: code,
      name: name,
      address: _address.isEmpty ? null : _address.join(' '),
      phone: phone,
      taxCode: taxCode,
    );
  }
}
