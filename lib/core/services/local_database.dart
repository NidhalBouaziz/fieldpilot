import '../models/customer.dart';
import '../models/sync_operation.dart';
import '../models/visit.dart';

abstract interface class LocalDatabase {
  Future<List<Customer>> customers();
  Future<Customer?> customerById(String id);
  Future<void> saveCustomer(Customer customer);
  Future<void> saveCustomers(List<Customer> customers);
  Future<void> deleteCustomer(String id);
  Future<void> restoreCustomer(String id);
  Future<List<Visit>> visits();
  Future<List<Visit>> visitsForCustomer(String customerId);
  Future<void> saveVisit(Visit visit);
  Future<List<SyncOperation>> queuedOperations();
  Future<void> enqueue(SyncOperation operation);
  Future<void> updateOperation(SyncOperation operation);
}

class MemoryLocalDatabase implements LocalDatabase {
  final Map<String, Customer> _customers = {};
  final Map<String, Visit> _visits = {};
  final Map<String, SyncOperation> _operations = {};

  @override
  Future<List<Customer>> customers() async {
    final values = _customers.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values;
  }

  @override
  Future<Customer?> customerById(String id) async => _customers[id];

  @override
  Future<void> saveCustomer(Customer customer) async {
    _customers[customer.id] = customer;
  }

  @override
  Future<void> saveCustomers(List<Customer> customers) async {
    for (final customer in customers) {
      _customers[customer.id] = customer;
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    final current = _customers[id];
    if (current == null) return;
    _customers[id] = current.copyWith(
      status: CustomerStatus.archived,
      updatedAt: DateTime.now(),
      deletedAt: DateTime.now(),
    );
  }

  @override
  Future<void> restoreCustomer(String id) async {
    final current = _customers[id];
    if (current == null) return;
    _customers[id] = current.copyWith(
      status: CustomerStatus.neverVisited,
      updatedAt: DateTime.now(),
      clearDeletedAt: true,
    );
  }

  @override
  Future<List<Visit>> visits() async {
    final values = _visits.values.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return values;
  }

  @override
  Future<List<Visit>> visitsForCustomer(String customerId) async {
    return _visits.values
        .where((visit) => visit.customerId == customerId)
        .toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  @override
  Future<void> saveVisit(Visit visit) async {
    _visits[visit.id] = visit;
  }

  @override
  Future<List<SyncOperation>> queuedOperations() async {
    return _operations.values
        .where(
          (operation) =>
              operation.state == SyncState.queued ||
              operation.state == SyncState.failed,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> enqueue(SyncOperation operation) async {
    _operations[operation.id] = operation;
  }

  @override
  Future<void> updateOperation(SyncOperation operation) async {
    _operations[operation.id] = operation;
  }
}
