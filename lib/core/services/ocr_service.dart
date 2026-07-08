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
}
