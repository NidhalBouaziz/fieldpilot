enum VisitStatus {
  planned,
  visited,
  followUp,
  interested,
  customer,
  notInterested,
}

extension VisitStatusLabel on VisitStatus {
  String get label => switch (this) {
        VisitStatus.planned => 'Planned',
        VisitStatus.visited => 'Visited',
        VisitStatus.followUp => 'Follow up',
        VisitStatus.interested => 'Interested',
        VisitStatus.customer => 'Customer',
        VisitStatus.notInterested => 'Not interested',
      };
}

class Visit {
  const Visit({
    required this.id,
    required this.customerId,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.notes,
    this.voiceNotePath,
    this.attachments = const [],
  });

  final String id;
  final String customerId;
  final DateTime scheduledAt;
  final DateTime? completedAt;
  final VisitStatus status;
  final String? notes;
  final String? voiceNotePath;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOverdue =>
      completedAt == null && scheduledAt.isBefore(DateTime.now());

  Visit copyWith({
    String? id,
    String? customerId,
    DateTime? scheduledAt,
    DateTime? completedAt,
    VisitStatus? status,
    String? notes,
    String? voiceNotePath,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Visit(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      completedAt: _date(json['completedAt']),
      status: VisitStatus.values.byName(json['status'] as String? ?? 'planned'),
      notes: json['notes'] as String?,
      voiceNotePath: json['voiceNotePath'] as String?,
      attachments: List<String>.from(json['attachments'] as List? ?? const []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'status': status.name,
        'notes': notes,
        'voiceNotePath': voiceNotePath,
        'attachments': attachments,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
