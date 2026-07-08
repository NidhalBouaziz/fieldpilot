import '../models/customer.dart';

abstract interface class CustomerRepository {
  Future<List<Customer>> list({bool includeArchived = false});
  Future<Customer?> byId(String id);
  Future<void> save(Customer customer);
  Future<void> archive(String id);
  Future<void> restore(String id);
  Future<List<Customer>> duplicatesFor(Customer customer);
  Future<List<Customer>> search(String query);
}
