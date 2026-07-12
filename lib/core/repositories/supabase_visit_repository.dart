import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/visit.dart';
import 'visit_repository.dart';

class SupabaseVisitRepository implements VisitRepository {
  SupabaseVisitRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'visits';

  @override
  Future<List<Visit>> list() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('scheduled_at', ascending: true);
    return rows
        .map((row) => _visitFromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<List<Visit>> forCustomer(String customerId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('customer_id', customerId)
        .order('scheduled_at', ascending: false);
    return rows
        .map((row) => _visitFromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> save(Visit visit) async {
    await _client.from(_table).upsert(_visitToRow(visit));
  }

  Map<String, dynamic> _visitToRow(Visit visit) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before saving visits.');
    }
    return {
      'id': visit.id,
      'user_id': userId,
      'customer_id': visit.customerId,
      'scheduled_at': visit.scheduledAt.toIso8601String(),
      'completed_at': visit.completedAt?.toIso8601String(),
      'status': visit.status.name,
      'notes': visit.notes,
      'voice_note_path': visit.voiceNotePath,
      'attachments': visit.attachments,
      'created_at': visit.createdAt.toIso8601String(),
      'updated_at': visit.updatedAt.toIso8601String(),
    };
  }

  Visit _visitFromRow(Map<String, dynamic> row) {
    return Visit(
      id: row['id'] as String,
      customerId: row['customer_id'] as String,
      scheduledAt: _date(row['scheduled_at']) ?? DateTime.now(),
      completedAt: _date(row['completed_at']),
      status: VisitStatus.values.byName(
        row['status'] as String? ?? VisitStatus.planned.name,
      ),
      notes: row['notes'] as String?,
      voiceNotePath: row['voice_note_path'] as String?,
      attachments: List<String>.from(row['attachments'] as List? ?? const []),
      createdAt: _date(row['created_at']) ?? DateTime.now(),
      updatedAt: _date(row['updated_at']) ?? DateTime.now(),
    );
  }

  DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
