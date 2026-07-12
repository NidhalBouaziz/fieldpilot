import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/dashboard_snapshot.dart';
import '../models/visit.dart';
import '../services/isar_local_database.dart';
import '../services/local_database.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/supabase_bootstrap.dart';
import '../utils/id_generator.dart';
import 'customer_repository.dart';
import 'supabase_customer_repository.dart';
import 'supabase_visit_repository.dart';
import 'visit_repository.dart';

final idGeneratorProvider = Provider((_) => const IdGenerator());
final localDatabaseProvider = Provider<LocalDatabase>(
  (_) => IsarLocalDatabase(),
);
final supabaseClientProvider = Provider((_) => SupabaseBootstrap.client);
final notificationServiceProvider = Provider(
  (_) => NotificationService(FlutterLocalNotificationsPlugin()),
);
final ocrServiceProvider = Provider((_) => OcrService());

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return SupabaseCustomerRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(idGeneratorProvider),
  );
});

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return SupabaseVisitRepository(ref.watch(supabaseClientProvider));
});

final customersProvider = FutureProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).list();
});

final visitsProvider = FutureProvider<List<Visit>>((ref) {
  return ref.watch(visitRepositoryProvider).list();
});

final dashboardSnapshotProvider = FutureProvider<DashboardSnapshot>((
  ref,
) async {
  final customers = await ref.watch(customerRepositoryProvider).list();
  final visits = await ref.watch(visitRepositoryProvider).list();
  return DashboardSnapshot.fromData(customers, visits);
});
