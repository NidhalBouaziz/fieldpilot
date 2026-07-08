import 'package:isar/isar.dart';

part 'isar_entities.g.dart';

@collection
class CustomerRecord {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String domainId;

  late String firstName;
  late String lastName;
  late String companyName;
  late String phone;
  String? phone2;
  String? email;
  String? address;
  late String city;
  late String governorate;
  double? latitude;
  double? longitude;
  String? speciality;
  String? notes;
  late int statusIndex;
  late bool favorite;
  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? lastVisit;
  DateTime? nextVisit;
  late List<String> tags;
  String? photo;
  DateTime? deletedAt;
}

@collection
class VisitRecord {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String domainId;

  @Index()
  late String customerId;

  late DateTime scheduledAt;
  DateTime? completedAt;
  late int statusIndex;
  String? notes;
  String? voiceNotePath;
  late List<String> attachments;
  late DateTime createdAt;
  late DateTime updatedAt;
}

@collection
class SyncOperationRecord {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String domainId;

  late int entityIndex;
  late String entityId;
  late int actionIndex;
  late String payloadJson;

  @Index()
  late int stateIndex;

  late int attempts;
  String? error;
  late DateTime createdAt;
  DateTime? lastAttemptAt;
}
