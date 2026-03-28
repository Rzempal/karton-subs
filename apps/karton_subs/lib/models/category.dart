import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String colorHex;
  final String iconName;
  final int order;

  const Category({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
    required this.order,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      colorHex: json['colorHex'] as String,
      iconName: json['iconName'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'iconName': iconName,
        'order': order,
      };

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Category copyWith({
    String? id,
    String? name,
    String? colorHex,
    String? iconName,
    int? order,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Category && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Predefiniowane kategorie wg database.md
final List<Category> defaultCategories = [
  const Category(id: 'cat_streaming', name: 'Streaming', colorHex: '#2563EB', iconName: 'play_circle', order: 0),
  const Category(id: 'cat_music', name: 'Muzyka', colorHex: '#7C3AED', iconName: 'headphones', order: 1),
  const Category(id: 'cat_cloud', name: 'Cloud', colorHex: '#0891B2', iconName: 'cloud', order: 2),
  const Category(id: 'cat_software', name: 'Software', colorHex: '#EA580C', iconName: 'code', order: 3),
  const Category(id: 'cat_fitness', name: 'Fitness', colorHex: '#16A34A', iconName: 'fitness_center', order: 4),
  const Category(id: 'cat_gaming', name: 'Gaming', colorHex: '#DB2777', iconName: 'sports_esports', order: 5),
  const Category(id: 'cat_education', name: 'Edukacja', colorHex: '#D97706', iconName: 'school', order: 6),
  const Category(id: 'cat_other', name: 'Inne', colorHex: '#64748B', iconName: 'folder', order: 7),
];
