import '../models/sync_operation.dart';
import '../models/visit.dart';
import '../services/local_database.dart';
import '../utils/id_generator.dart';
import 'visit_repository.dart';

class OfflineVisitRepository implements VisitRepository {
  OfflineVisitRepository(this._database, this._ids);

  final LocalDatabase _database;
  final IdGenerator _ids;

  @override
  Future<List<Visit>> list() => _database.visits();

  @override
  Future<List<Visit>> forCustomer(String customerId) =>
      _database.visitsForCustomer(customerId);

  @override
  Future<void> save(Visit visit) async {
    await _database.saveVisit(visit);
    await _database.enqueue(
      SyncOperation(
        id: _ids(),
        entity: SyncEntity.visit,
        entityId: visit.id,
        action: SyncAction.upsert,
        payload: visit.toJson(),
        createdAt: DateTime.now(),
      ),
    );
  }
}
