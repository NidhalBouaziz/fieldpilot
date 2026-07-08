import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/customer.dart';
import '../models/sync_operation.dart';
import '../models/visit.dart';
import 'isar_entities.dart';
import 'local_database.dart';

class IsarLocalDatabase implements LocalDatabase {
  IsarLocalDatabase();

  Future<Isar>? _instance;

  Future<Isar> get _isar {
    return _instance ??= _open();
  }

  Future<Isar> _open() async {
    final directory = await getApplicationDocumentsDirectory();
    return Isar.open(
      [
        CustomerRecordSchema,
        VisitRecordSchema,
        SyncOperationRecordSchema,
      ],
      directory: directory.path,
      name: 'fieldpilot',
    );
  }

  @override
  Future<List<Customer>> customers() async {
    final isar = await _isar;
    final records = await isar.customerRecords.where().findAll();
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records.map(_customerFromRecord).toList();
  }

  @override
  Future<Customer?> customerById(String id) async {
    final isar = await _isar;
    final record =
        await isar.customerRecords.filter().domainIdEqualTo(id).findFirst();
    return record == null ? null : _customerFromRecord(record);
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      await isar.customerRecords.put(_customerToRecord(customer));
    });
  }

  @override
  Future<void> saveCustomers(List<Customer> customers) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      await isar.customerRecords
          .putAll(customers.map(_customerToRecord).toList());
    });
  }

  @override
  Future<void> deleteCustomer(String id) async {
    final current = await customerById(id);
    if (current == null) return;
    await saveCustomer(
      current.copyWith(
        status: CustomerStatus.archived,
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> restoreCustomer(String id) async {
    final current = await customerById(id);
    if (current == null) return;
    await saveCustomer(
      current.copyWith(
        status: CustomerStatus.neverVisited,
        updatedAt: DateTime.now(),
        clearDeletedAt: true,
      ),
    );
  }

  @override
  Future<List<Visit>> visits() async {
    final isar = await _isar;
    final records = await isar.visitRecords.where().findAll();
    records.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return records.map(_visitFromRecord).toList();
  }

  @override
  Future<List<Visit>> visitsForCustomer(String customerId) async {
    final isar = await _isar;
    final records = await isar.visitRecords
        .filter()
        .customerIdEqualTo(customerId)
        .findAll();
    records.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return records.map(_visitFromRecord).toList();
  }

  @override
  Future<void> saveVisit(Visit visit) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      await isar.visitRecords.put(_visitToRecord(visit));
    });
  }

  @override
  Future<List<SyncOperation>> queuedOperations() async {
    final isar = await _isar;
    final records = await isar.syncOperationRecords.filter().group((query) {
      return query
          .stateIndexEqualTo(SyncState.queued.index)
          .or()
          .stateIndexEqualTo(SyncState.failed.index);
    }).findAll();
    records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return records.map(_syncFromRecord).toList();
  }

  @override
  Future<void> enqueue(SyncOperation operation) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      await isar.syncOperationRecords.put(_syncToRecord(operation));
    });
  }

  @override
  Future<void> updateOperation(SyncOperation operation) async {
    await enqueue(operation);
  }

  Customer _customerFromRecord(CustomerRecord record) {
    return Customer(
      id: record.domainId,
      firstName: record.firstName,
      lastName: record.lastName,
      companyName: record.companyName,
      phone: record.phone,
      phone2: record.phone2,
      email: record.email,
      address: record.address,
      city: record.city,
      governorate: record.governorate,
      latitude: record.latitude,
      longitude: record.longitude,
      speciality: record.speciality,
      notes: record.notes,
      status: CustomerStatus.values[record.statusIndex],
      favorite: record.favorite,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      lastVisit: record.lastVisit,
      nextVisit: record.nextVisit,
      tags: record.tags,
      photo: record.photo,
      deletedAt: record.deletedAt,
    );
  }

  CustomerRecord _customerToRecord(Customer customer) {
    return CustomerRecord()
      ..domainId = customer.id
      ..firstName = customer.firstName
      ..lastName = customer.lastName
      ..companyName = customer.companyName
      ..phone = customer.phone
      ..phone2 = customer.phone2
      ..email = customer.email
      ..address = customer.address
      ..city = customer.city
      ..governorate = customer.governorate
      ..latitude = customer.latitude
      ..longitude = customer.longitude
      ..speciality = customer.speciality
      ..notes = customer.notes
      ..statusIndex = customer.status.index
      ..favorite = customer.favorite
      ..createdAt = customer.createdAt
      ..updatedAt = customer.updatedAt
      ..lastVisit = customer.lastVisit
      ..nextVisit = customer.nextVisit
      ..tags = customer.tags
      ..photo = customer.photo
      ..deletedAt = customer.deletedAt;
  }

  Visit _visitFromRecord(VisitRecord record) {
    return Visit(
      id: record.domainId,
      customerId: record.customerId,
      scheduledAt: record.scheduledAt,
      completedAt: record.completedAt,
      status: VisitStatus.values[record.statusIndex],
      notes: record.notes,
      voiceNotePath: record.voiceNotePath,
      attachments: record.attachments,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  VisitRecord _visitToRecord(Visit visit) {
    return VisitRecord()
      ..domainId = visit.id
      ..customerId = visit.customerId
      ..scheduledAt = visit.scheduledAt
      ..completedAt = visit.completedAt
      ..statusIndex = visit.status.index
      ..notes = visit.notes
      ..voiceNotePath = visit.voiceNotePath
      ..attachments = visit.attachments
      ..createdAt = visit.createdAt
      ..updatedAt = visit.updatedAt;
  }

  SyncOperation _syncFromRecord(SyncOperationRecord record) {
    return SyncOperation(
      id: record.domainId,
      entity: SyncEntity.values[record.entityIndex],
      entityId: record.entityId,
      action: SyncAction.values[record.actionIndex],
      payload: Map<String, dynamic>.from(jsonDecode(record.payloadJson) as Map),
      state: SyncState.values[record.stateIndex],
      attempts: record.attempts,
      error: record.error,
      createdAt: record.createdAt,
      lastAttemptAt: record.lastAttemptAt,
    );
  }

  SyncOperationRecord _syncToRecord(SyncOperation operation) {
    return SyncOperationRecord()
      ..domainId = operation.id
      ..entityIndex = operation.entity.index
      ..entityId = operation.entityId
      ..actionIndex = operation.action.index
      ..payloadJson = jsonEncode(operation.payload)
      ..stateIndex = operation.state.index
      ..attempts = operation.attempts
      ..error = operation.error
      ..createdAt = operation.createdAt
      ..lastAttemptAt = operation.lastAttemptAt;
  }
}
