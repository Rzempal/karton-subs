// usage_event.dart v0.001 Model zdarzenia użycia subskrypcji

import 'package:uuid/uuid.dart';

/// Zdarzenie użycia subskrypcji ("Skorzystałem dziś")
class UsageEvent {
  final String id;
  final DateTime date;
  final String? note;

  const UsageEvent({
    required this.id,
    required this.date,
    this.note,
  });

  /// Tworzy nowe zdarzenie z wygenerowanym UUID
  factory UsageEvent.create({String? note}) {
    return UsageEvent(
      id: const Uuid().v4(),
      date: DateTime.now(),
      note: note,
    );
  }

  factory UsageEvent.fromJson(Map<String, dynamic> json) {
    return UsageEvent(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      if (note != null) 'note': note,
    };
  }
}
