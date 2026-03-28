class UsageEvent {
  final String id;
  final DateTime date;
  final String? note;

  const UsageEvent({
    required this.id,
    required this.date,
    this.note,
  });

  factory UsageEvent.fromJson(Map<String, dynamic> json) {
    return UsageEvent(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        if (note != null) 'note': note,
      };

  UsageEvent copyWith({String? id, DateTime? date, String? note}) {
    return UsageEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}
