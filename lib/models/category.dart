// category.dart v0.001 Model kategorii z predefiniowanymi wartościami

import 'package:uuid/uuid.dart';

/// Kategoria subskrypcji
class Category {
  final String id;
  final String name;
  final String color;
  final String iconName;
  final int order;

  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.iconName,
    required this.order,
  });

  /// Tworzy nową kategorię z wygenerowanym UUID
  factory Category.create({
    required String name,
    required String color,
    required String iconName,
    required int order,
  }) {
    return Category(
      id: const Uuid().v4(),
      name: name,
      color: color,
      iconName: iconName,
      order: order,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      iconName: json['iconName'] as String,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'iconName': iconName,
      'order': order,
    };
  }

  Category copyWith({
    String? name,
    String? color,
    String? iconName,
    int? order,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      order: order ?? this.order,
    );
  }
}

/// Predefiniowane kategorie (seed data)
class PredefinedCategories {
  static const List<Category> all = [
    Category(
      id: 'cat-streaming',
      name: 'Streaming',
      color: '#2563EB',
      iconName: 'play-circle',
      order: 0,
    ),
    Category(
      id: 'cat-music',
      name: 'Muzyka',
      color: '#7C3AED',
      iconName: 'headphones',
      order: 1,
    ),
    Category(
      id: 'cat-cloud',
      name: 'Chmura',
      color: '#0891B2',
      iconName: 'cloud',
      order: 2,
    ),
    Category(
      id: 'cat-software',
      name: 'Oprogramowanie',
      color: '#EA580C',
      iconName: 'code',
      order: 3,
    ),
    Category(
      id: 'cat-fitness',
      name: 'Fitness',
      color: '#16A34A',
      iconName: 'dumbbell',
      order: 4,
    ),
    Category(
      id: 'cat-gaming',
      name: 'Gaming',
      color: '#DB2777',
      iconName: 'gamepad-2',
      order: 5,
    ),
    Category(
      id: 'cat-education',
      name: 'Edukacja',
      color: '#D97706',
      iconName: 'graduation-cap',
      order: 6,
    ),
    Category(
      id: 'cat-other',
      name: 'Inne',
      color: '#64748B',
      iconName: 'folder',
      order: 7,
    ),
  ];
}
