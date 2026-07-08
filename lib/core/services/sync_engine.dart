import '../models/sync_operation.dart';
import 'connectivity_service.dart';
import 'firebase_sync_gateway.dart';
import 'local_database.dart';

class SyncEngine {
  SyncEngine({
    required LocalDatabase database,
    required ConnectivityService connectivity,
    required FirebaseSyncGateway gateway,
  })  : _database = database,
        _connectivity = connectivity,
        _gateway = gateway;

  final LocalDatabase _database;
  final ConnectivityService _connectivity;
  final FirebaseSyncGateway _gateway;

  Future<void> flush() async {
    if (!await _connectivity.isOnline) return;

    final operations = await _database.queuedOperations();
    for (final operation in operations) {
      final started = operation.copyWith(
        state: SyncState.syncing,
        attempts: operation.attempts + 1,
        lastAttemptAt: DateTime.now(),
      );
      await _database.updateOperation(started);

      try {
        await _gateway.push(operation);
        await _database.updateOperation(
          started.copyWith(state: SyncState.synced),
        );
      } catch (error) {
        await _database.updateOperation(
          started.copyWith(state: SyncState.failed, error: error.toString()),
        );
      }
    }
  }
}
