import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../utils/id_generator.dart';
import 'customer_repository.dart';

class SupabaseCustomerRepository implements CustomerRepository {
  SupabaseCustomerRepository(this._client, this._ids);

  final SupabaseClient _client;
  final IdGenerator _ids;

  static const _table = 'customers';

  @override
  Future<List<Customer>> list({bool includeArchived = false}) async {
    final rows = await _client
        .from(_table)
        .select()
        .order('updated_at', ascending: false);
    final customers = rows
        .map((row) => _customerFromRow(Map<String, dynamic>.from(row)))
        .toList();
    if (includeArchived) return customers;
    return customers.where((customer) => !customer.isArchived).toList();
  }

  @override
  Future<Customer?> byId(String id) async {
    final row = await _client.from(_table).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return _customerFromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> save(Customer customer) async {
    await _client.from(_table).upsert(_customerToRow(customer));
  }

  @override
  Future<void> archive(String id) async {
    await _client.from(_table).update({
      'status': CustomerStatus.archived.name,
      'deleted_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> restore(String id) async {
    await _client.from(_table).update({
      'status': CustomerStatus.neverVisited.name,
      'deleted_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<List<Customer>> duplicatesFor(Customer customer) async {
    final all = await list(includeArchived: true);
    final normalizedPhone = _normalize(customer.phone);
    return all.where((candidate) {
      if (candidate.id == customer.id) return false;
      final samePhone = normalizedPhone.isNotEmpty &&
          _normalize(candidate.phone) == normalizedPhone;
      final sameEmail = customer.email != null &&
          candidate.email?.toLowerCase() == customer.email!.toLowerCase();
      final sameName = candidate.displayName.toLowerCase() ==
          customer.displayName.toLowerCase();
      return samePhone ||
          sameEmail ||
          (sameName &&
              candidate.city.toLowerCase() == customer.city.toLowerCase());
    }).toList();
  }

  @override
  Future<List<Customer>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list();
    final all = await list();
    return all.where((customer) {
      return [
        customer.displayName,
        customer.companyName,
        customer.phone,
        customer.phone2,
        customer.email,
        customer.address,
        customer.city,
        customer.governorate,
        customer.speciality,
        customer.tags.join(' '),
      ].whereType<String>().any((value) => value.toLowerCase().contains(q));
    }).toList();
  }

  Map<String, dynamic> _customerToRow(Customer customer) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before saving customers.');
    }
    return {
      'id': customer.id.isEmpty ? _ids() : customer.id,
      'user_id': userId,
      'first_name': customer.firstName,
      'last_name': customer.lastName,
      'company_name': customer.companyName,
      'phone': customer.phone,
      'phone2': customer.phone2,
      'email': customer.email,
      'address': customer.address,
      'city': customer.city,
      'governorate': customer.governorate,
      'latitude': customer.latitude,
      'longitude': customer.longitude,
      'speciality': customer.speciality,
      'notes': customer.notes,
      'status': customer.status.name,
      'favorite': customer.favorite,
      'created_at': customer.createdAt.toIso8601String(),
      'updated_at': customer.updatedAt.toIso8601String(),
      'last_visit': customer.lastVisit?.toIso8601String(),
      'next_visit': customer.nextVisit?.toIso8601String(),
      'tags': customer.tags,
      'photo': customer.photo,
      'deleted_at': customer.deletedAt?.toIso8601String(),
    };
  }

  Customer _customerFromRow(Map<String, dynamic> row) {
    return Customer(
      id: row['id'] as String,
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      companyName: row['company_name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      phone2: row['phone2'] as String?,
      email: row['email'] as String?,
      address: row['address'] as String?,
      city: row['city'] as String? ?? '',
      governorate: row['governorate'] as String? ?? '',
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      speciality: row['speciality'] as String?,
      notes: row['notes'] as String?,
      status: CustomerStatus.values.byName(
        row['status'] as String? ?? CustomerStatus.neverVisited.name,
      ),
      favorite: row['favorite'] as bool? ?? false,
      createdAt: _date(row['created_at']) ?? DateTime.now(),
      updatedAt: _date(row['updated_at']) ?? DateTime.now(),
      lastVisit: _date(row['last_visit']),
      nextVisit: _date(row['next_visit']),
      tags: List<String>.from(row['tags'] as List? ?? const []),
      photo: row['photo'] as String?,
      deletedAt: _date(row['deleted_at']),
    );
  }

  DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _normalize(String value) => value.replaceAll(RegExp(r'\D'), '');
}
