import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/dashboard_snapshot.dart';
import '../models/visit.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_sync_gateway.dart';
import '../services/isar_local_database.dart';
import '../services/local_database.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/sync_engine.dart';
import '../utils/id_generator.dart';
import 'customer_repository.dart';
import 'offline_customer_repository.dart';
import 'offline_visit_repository.dart';
import 'visit_repository.dart';

final idGeneratorProvider = Provider((_) => const IdGenerator());
final localDatabaseProvider = Provider<LocalDatabase>(
  (_) => IsarLocalDatabase(),
);
final connectivityServiceProvider = Provider(
  (_) => ConnectivityService(Connectivity()),
);
final firebaseSyncGatewayProvider = Provider(
  (_) => FirebaseSyncGateway(FirebaseFirestore.instance, FirebaseAuth.instance),
);
final syncEngineProvider = Provider((ref) {
  return SyncEngine(
    database: ref.watch(localDatabaseProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    gateway: ref.watch(firebaseSyncGatewayProvider),
  );
});
final notificationServiceProvider = Provider(
  (_) => NotificationService(FlutterLocalNotificationsPlugin()),
);
final ocrServiceProvider = Provider((_) => OcrService());

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return OfflineCustomerRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(idGeneratorProvider),
  );
});

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return OfflineVisitRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(idGeneratorProvider),
  );
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
