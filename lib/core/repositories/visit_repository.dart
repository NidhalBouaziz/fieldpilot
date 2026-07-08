import '../models/visit.dart';

abstract interface class VisitRepository {
  Future<List<Visit>> list();
  Future<List<Visit>> forCustomer(String customerId);
  Future<void> save(Visit visit);
}
