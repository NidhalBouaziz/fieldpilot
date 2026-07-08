enum SyncEntity { customer, visit }

enum SyncAction { upsert, delete, restore, merge }

enum SyncState { queued, syncing, synced, failed, conflict }

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.state = SyncState.queued,
    this.attempts = 0,
    this.error,
    this.lastAttemptAt,
  });

  final String id;
  final SyncEntity entity;
  final String entityId;
  final SyncAction action;
  final Map<String, dynamic> payload;
  final SyncState state;
  final int attempts;
  final String? error;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;

  SyncOperation copyWith({
    SyncState? state,
    int? attempts,
    String? error,
    DateTime? lastAttemptAt,
  }) {
    return SyncOperation(
      id: id,
      entity: entity,
      entityId: entityId,
      action: action,
      payload: payload,
      createdAt: createdAt,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      error: error,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }
}
