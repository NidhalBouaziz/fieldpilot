import '../models/customer.dart';
import '../models/sync_operation.dart';
import '../services/local_database.dart';
import '../utils/id_generator.dart';
import 'customer_repository.dart';

class OfflineCustomerRepository implements CustomerRepository {
  OfflineCustomerRepository(this._database, this._ids);

  final LocalDatabase _database;
  final IdGenerator _ids;

  @override
  Future<List<Customer>> list({bool includeArchived = false}) async {
    final customers = await _database.customers();
    if (includeArchived) return customers;
    return customers.where((customer) => !customer.isArchived).toList();
  }

  @override
  Future<Customer?> byId(String id) => _database.customerById(id);

  @override
  Future<void> save(Customer customer) async {
    await _database.saveCustomer(customer);
    await _database.enqueue(
      SyncOperation(
        id: _ids(),
        entity: SyncEntity.customer,
        entityId: customer.id,
        action: SyncAction.upsert,
        payload: customer.toJson(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> archive(String id) async {
    await _database.deleteCustomer(id);
    await _database.enqueue(
      SyncOperation(
        id: _ids(),
        entity: SyncEntity.customer,
        entityId: id,
        action: SyncAction.delete,
        payload: {'id': id},
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> restore(String id) async {
    await _database.restoreCustomer(id);
    final customer = await _database.customerById(id);
    if (customer == null) return;
    await save(customer);
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

  String _normalize(String value) => value.replaceAll(RegExp(r'\D'), '');
}
