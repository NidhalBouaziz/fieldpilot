import 'package:fieldpilot/core/models/customer.dart';
import 'package:fieldpilot/core/services/customer_import_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skips scanned customer when client code already exists', () {
    final existing = _customer(
      id: 'existing',
      name: 'TRIGUI WIEM',
      city: 'SFAX',
      phone: '74665345',
      address: '18 RUE ABDERRAHMEN EL GAFSI',
      notes: 'Code client: 411001',
      tags: ['bulk-scan', '411001'],
    );
    final scanned = _customer(
      id: 'new-scan',
      name: 'TRIGUI WIEM',
      city: 'SFAX',
      phone: '74665345',
      address: 'Wrong OCR address',
      notes: 'Code client: 411001',
      tags: ['bulk-scan', '411001'],
    );

    final result = resolveCustomerImport([scanned], [existing]);

    expect(result.added, 0);
    expect(result.updated, 0);
    expect(result.skipped, 1);
    expect(result.customersToSave, isEmpty);
  });

  test('updates existing duplicate only with missing scanned fields', () {
    final now = DateTime(2026, 7, 13, 12);
    final existing = _customer(
      id: 'existing',
      name: 'TRIFA EMNA',
      city: 'SFAX',
      notes: 'Code client: 411058',
      tags: ['bulk-scan', '411058'],
    );
    final scanned = _customer(
      id: 'new-scan',
      name: 'TRIFA EMNA',
      city: 'SFAX',
      phone: '74661163',
      address: 'RTE AFRAN KM 3 RESD GHADA APP1.4',
      notes: 'Code client: 411058\nCode TVA: 1594044V',
      tags: ['bulk-scan', '411058'],
    );

    final result = resolveCustomerImport([scanned], [existing], now: now);

    expect(result.added, 0);
    expect(result.updated, 1);
    expect(result.skipped, 0);
    expect(result.customersToSave, hasLength(1));
    expect(result.customersToSave.single.id, 'existing');
    expect(result.customersToSave.single.phone, '74661163');
    expect(
      result.customersToSave.single.address,
      'RTE AFRAN KM 3 RESD GHADA APP1.4',
    );
    expect(result.customersToSave.single.notes, contains('Code TVA: 1594044V'));
    expect(result.customersToSave.single.updatedAt, now);
  });

  test('uses phone to avoid duplicates inside the same import', () {
    final first = _customer(
      id: 'scan-1',
      name: 'WALHA AYMEN',
      city: 'SFAX',
      phone: '74853941',
      notes: 'Code client: 411045',
      tags: ['bulk-scan', '411045'],
    );
    final repeated = _customer(
      id: 'scan-2',
      name: 'WALHA AYMEN',
      city: 'SFAX',
      phone: '74 853 941',
      notes: 'Code client: 411045',
      tags: ['bulk-scan', '411045'],
    );

    final result = resolveCustomerImport([first, repeated], const []);

    expect(result.added, 1);
    expect(result.updated, 0);
    expect(result.skipped, 1);
    expect(result.customersToSave, [first]);
  });

  test('uses name and city when code and phone are missing', () {
    final existing = _customer(
      id: 'existing',
      name: 'WOUROUD ABBES MAALOUL',
      city: 'GABES',
      address: 'GABES',
    );
    final scanned = _customer(
      id: 'new-scan',
      name: 'WOUROUD ABBES MAALOUL',
      city: 'GABES',
      address: 'GABES',
    );

    final result = resolveCustomerImport([scanned], [existing]);

    expect(result.added, 0);
    expect(result.updated, 0);
    expect(result.skipped, 1);
    expect(result.customersToSave, isEmpty);
  });

  test('does not merge conflicting scanned identifiers into notes', () {
    final now = DateTime(2026, 7, 13, 12);
    final existing = _customer(
      id: 'existing',
      name: 'TRIFA EMNA',
      city: 'SFAX',
      phone: '74661163',
      notes: '''
Code client: 411058
Code TVA: 1594044V
Code TVA: WRONGOLD
''',
      tags: ['bulk-scan', '411058'],
    );
    final scanned = _customer(
      id: 'new-scan',
      name: 'TRIFA EMNA',
      city: 'SFAX',
      phone: '74661163',
      address: 'RTE AFRAN KM 3 RESD GHADA APP1.4',
      notes: '''
Code client: 999999
Code TVA: WRONGNEW
''',
      tags: ['bulk-scan', '999999'],
    );

    final result = resolveCustomerImport([scanned], [existing], now: now);

    expect(result.updated, 1);
    expect(result.customersToSave.single.notes, contains('Code TVA: 1594044V'));
    expect(result.customersToSave.single.notes, isNot(contains('WRONGOLD')));
    expect(result.customersToSave.single.notes, isNot(contains('WRONGNEW')));
    expect(result.customersToSave.single.notes, isNot(contains('999999')));
    expect(result.customersToSave.single.tags, ['bulk-scan', '411058']);
  });
}

Customer _customer({
  required String id,
  required String name,
  String city = '',
  String phone = '',
  String? address,
  String? notes,
  List<String> tags = const [],
}) {
  final parts = name.split(RegExp(r'\s+'));
  return Customer(
    id: id,
    firstName: parts.first,
    lastName: parts.skip(1).join(' '),
    companyName: name,
    phone: phone,
    address: address,
    city: city,
    governorate: city,
    notes: notes,
    status: CustomerStatus.neverVisited,
    createdAt: DateTime(2026, 7, 13),
    updatedAt: DateTime(2026, 7, 13),
    tags: tags,
  );
}
