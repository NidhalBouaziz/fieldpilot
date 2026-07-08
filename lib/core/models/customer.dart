enum CustomerStatus {
  neverVisited,
  planned,
  followUp,
  interested,
  customer,
  notInterested,
  archived,
}

extension CustomerStatusLabel on CustomerStatus {
  String get label => switch (this) {
        CustomerStatus.neverVisited => 'Never visited',
        CustomerStatus.planned => 'Planned',
        CustomerStatus.followUp => 'Follow up',
        CustomerStatus.interested => 'Interested',
        CustomerStatus.customer => 'Customer',
        CustomerStatus.notInterested => 'Not interested',
        CustomerStatus.archived => 'Archived',
      };
}

class Customer {
  const Customer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.companyName,
    required this.phone,
    required this.city,
    required this.governorate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.phone2,
    this.email,
    this.address,
    this.latitude,
    this.longitude,
    this.speciality,
    this.notes,
    this.favorite = false,
    this.lastVisit,
    this.nextVisit,
    this.tags = const [],
    this.photo,
    this.deletedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String companyName;
  final String phone;
  final String? phone2;
  final String? email;
  final String? address;
  final String city;
  final String governorate;
  final double? latitude;
  final double? longitude;
  final String? speciality;
  final String? notes;
  final CustomerStatus status;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastVisit;
  final DateTime? nextVisit;
  final List<String> tags;
  final String? photo;
  final DateTime? deletedAt;

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? companyName : fullName;
  }

  bool get isArchived => status == CustomerStatus.archived || deletedAt != null;

  Customer copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? companyName,
    String? phone,
    String? phone2,
    String? email,
    String? address,
    String? city,
    String? governorate,
    double? latitude,
    double? longitude,
    String? speciality,
    String? notes,
    CustomerStatus? status,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastVisit,
    DateTime? nextVisit,
    List<String>? tags,
    String? photo,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Customer(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      governorate: governorate ?? this.governorate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speciality: speciality ?? this.speciality,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVisit: lastVisit ?? this.lastVisit,
      nextVisit: nextVisit ?? this.nextVisit,
      tags: tags ?? this.tags,
      photo: photo ?? this.photo,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      phone2: json['phone2'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String? ?? '',
      governorate: json['governorate'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      speciality: json['speciality'] as String?,
      notes: json['notes'] as String?,
      status: CustomerStatus.values.byName(
        json['status'] as String? ?? 'neverVisited',
      ),
      favorite: json['favorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastVisit: _date(json['lastVisit']),
      nextVisit: _date(json['nextVisit']),
      tags: List<String>.from(json['tags'] as List? ?? const []),
      photo: json['photo'] as String?,
      deletedAt: _date(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'companyName': companyName,
        'phone': phone,
        'phone2': phone2,
        'email': email,
        'address': address,
        'city': city,
        'governorate': governorate,
        'latitude': latitude,
        'longitude': longitude,
        'speciality': speciality,
        'notes': notes,
        'status': status.name,
        'favorite': favorite,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastVisit': lastVisit?.toIso8601String(),
        'nextVisit': nextVisit?.toIso8601String(),
        'tags': tags,
        'photo': photo,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
