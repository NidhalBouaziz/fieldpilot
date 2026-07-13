import '../models/customer.dart';

class CustomerImportResult {
  const CustomerImportResult({
    required this.customersToSave,
    required this.added,
    required this.updated,
    required this.skipped,
  });

  final List<Customer> customersToSave;
  final int added;
  final int updated;
  final int skipped;

  String get message {
    return 'Import complete: $added added, $updated updated, $skipped skipped';
  }
}

CustomerImportResult resolveCustomerImport(
  List<Customer> scannedCustomers,
  List<Customer> existingCustomers, {
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final known = [...existingCustomers];
  final customersToSave = <Customer>[];
  var added = 0;
  var updated = 0;
  var skipped = 0;

  for (final scanned in scannedCustomers) {
    final matchIndex = known.indexWhere(
      (customer) => _matchesImportedCustomer(scanned, customer),
    );

    if (matchIndex == -1) {
      known.add(scanned);
      customersToSave.add(scanned);
      added += 1;
      continue;
    }

    final existing = known[matchIndex];
    final merged = _mergeMissingCustomerFields(
      existing: existing,
      scanned: scanned,
      now: timestamp,
    );

    if (_sameCustomerData(existing, merged)) {
      skipped += 1;
      continue;
    }

    known[matchIndex] = merged;
    customersToSave.add(merged);
    updated += 1;
  }

  return CustomerImportResult(
    customersToSave: customersToSave,
    added: added,
    updated: updated,
    skipped: skipped,
  );
}

bool _matchesImportedCustomer(Customer scanned, Customer existing) {
  final scannedCode = _clientCode(scanned);
  if (scannedCode != null && scannedCode == _clientCode(existing)) {
    return true;
  }

  final scannedTaxCode = _taxCode(scanned);
  if (scannedTaxCode != null && scannedTaxCode == _taxCode(existing)) {
    return true;
  }

  final scannedPhones = _phones(scanned);
  if (scannedPhones.isNotEmpty &&
      scannedPhones.any((phone) => _phones(existing).contains(phone))) {
    return true;
  }

  final scannedName = _normalizeText(scanned.displayName);
  final existingName = _normalizeText(existing.displayName);
  final scannedCity = _normalizeText(scanned.city);
  final existingCity = _normalizeText(existing.city);

  return scannedName.isNotEmpty &&
      scannedName == existingName &&
      scannedCity.isNotEmpty &&
      scannedCity == existingCity;
}

Customer _mergeMissingCustomerFields({
  required Customer existing,
  required Customer scanned,
  required DateTime now,
}) {
  var changed = false;

  String fillString(String current, String incoming) {
    if (current.trim().isNotEmpty || incoming.trim().isEmpty) return current;
    changed = true;
    return incoming;
  }

  String? fillNullable(String? current, String? incoming) {
    if (current != null && current.trim().isNotEmpty) return current;
    if (incoming == null || incoming.trim().isEmpty) return current;
    changed = true;
    return incoming;
  }

  final notes = _mergeNotes(existing.notes, scanned.notes);
  if (notes != existing.notes) changed = true;

  final tags = _mergeTags(existing.tags, scanned.tags);
  if (!_sameStringList(tags, existing.tags)) changed = true;

  final firstName = fillString(existing.firstName, scanned.firstName);
  final lastName = fillString(existing.lastName, scanned.lastName);
  final companyName = fillString(existing.companyName, scanned.companyName);
  final phone = fillString(existing.phone, scanned.phone);
  final phone2 = fillNullable(existing.phone2, scanned.phone2);
  final email = fillNullable(existing.email, scanned.email);
  final address = fillNullable(existing.address, scanned.address);
  final city = fillString(existing.city, scanned.city);
  final governorate = fillString(existing.governorate, scanned.governorate);
  final speciality = fillNullable(existing.speciality, scanned.speciality);
  final photo = fillNullable(existing.photo, scanned.photo);
  final latitude = existing.latitude ?? scanned.latitude;
  if (latitude != existing.latitude) changed = true;
  final longitude = existing.longitude ?? scanned.longitude;
  if (longitude != existing.longitude) changed = true;

  if (!changed) return existing;

  return existing.copyWith(
    firstName: firstName,
    lastName: lastName,
    companyName: companyName,
    phone: phone,
    phone2: phone2,
    email: email,
    address: address,
    city: city,
    governorate: governorate,
    latitude: latitude,
    longitude: longitude,
    speciality: speciality,
    notes: notes,
    updatedAt: now,
    tags: tags,
    photo: photo,
  );
}

String? _clientCode(Customer customer) {
  for (final tag in customer.tags) {
    final value = tag.trim();
    if (RegExp(r'^\d{5,7}$').hasMatch(value)) return value;
  }
  return _firstNoteValue(customer.notes, 'Code client');
}

String? _taxCode(Customer customer) {
  return _firstNoteValue(customer.notes, 'Code TVA');
}

String? _firstNoteValue(String? notes, String label) {
  if (notes == null) return null;
  final pattern = RegExp(
    '${RegExp.escape(label)}\\s*:\\s*([^\\n\\r]+)',
    caseSensitive: false,
  );
  final value = pattern.firstMatch(notes)?.group(1)?.trim();
  return value == null || value.isEmpty ? null : value.toUpperCase();
}

Set<String> _phones(Customer customer) {
  return [
    customer.phone,
    customer.phone2,
  ]
      .whereType<String>()
      .map((value) => value.replaceAll(RegExp(r'\D'), ''))
      .where((value) => value.length >= 8)
      .toSet();
}

String _normalizeText(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
}

String? _mergeNotes(String? current, String? incoming) {
  final currentLines = _dedupeIdentifierLines(_noteLines(current));
  final incomingLines = _noteLines(incoming);
  if (incomingLines.isEmpty) return current;
  final merged = [...currentLines];
  final normalized = currentLines.map(_normalizeText).toSet();
  final existingIdentifiers = {
    for (final line in currentLines)
      if (_identifierLabel(line) != null) _identifierLabel(line)!: true,
  };

  for (final line in incomingLines) {
    final label = _identifierLabel(line);
    if (label != null && existingIdentifiers.containsKey(label)) {
      continue;
    }
    if (normalized.add(_normalizeText(line))) {
      merged.add(line);
      if (label != null) existingIdentifiers[label] = true;
    }
  }

  if (merged.isEmpty) return null;
  return merged.join('\n');
}

List<String> _dedupeIdentifierLines(List<String> lines) {
  final keptLabels = <String>{};
  final kept = <String>[];

  for (final line in lines) {
    final label = _identifierLabel(line);
    if (label != null && !keptLabels.add(label)) continue;
    kept.add(line);
  }

  return kept;
}

String? _identifierLabel(String line) {
  final normalized = _normalizeText(line);
  if (normalized.startsWith('CODE CLIENT:')) return 'CODE CLIENT';
  if (normalized.startsWith('CODE TVA:')) return 'CODE TVA';
  return null;
}

List<String> _noteLines(String? value) {
  return (value ?? '')
      .split(RegExp(r'[\n\r]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

List<String> _mergeTags(List<String> current, List<String> incoming) {
  final merged = [...current];
  final normalized = current.map(_normalizeText).toSet();
  var hasClientCode = current.any(
    (tag) => RegExp(r'^\d{5,7}$').hasMatch(tag),
  );
  for (final tag in incoming) {
    if (tag.trim().isEmpty) continue;
    if (hasClientCode && RegExp(r'^\d{5,7}$').hasMatch(tag)) continue;
    if (normalized.add(_normalizeText(tag))) {
      merged.add(tag);
      hasClientCode = hasClientCode || RegExp(r'^\d{5,7}$').hasMatch(tag);
    }
  }
  return merged;
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _sameCustomerData(Customer a, Customer b) {
  return a.toJson().toString() == b.toJson().toString();
}
