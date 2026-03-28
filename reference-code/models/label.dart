/// Model etykiety użytkownika - zgodny z wersją web
/// Etykiety pozwalają użytkownikowi kategoryzować leki według własnych potrzeb
library;

/// Dostępne kolory etykiet
enum LabelColor { red, orange, yellow, green, blue, purple, pink, gray }

/// Informacje o kolorze
class LabelColorInfo {
  final String name;
  final int hexValue;

  const LabelColorInfo(this.name, this.hexValue);

  /// Konwertuje na Color dla Flutter
  int get colorValue => hexValue;
}

/// Mapa kolorów z nazwami i wartościami hex
const Map<LabelColor, LabelColorInfo> labelColors = {
  LabelColor.red: LabelColorInfo('Czerwony', 0xFFef4444),
  LabelColor.orange: LabelColorInfo('Pomarańczowy', 0xFFf97316),
  LabelColor.yellow: LabelColorInfo('Żółty', 0xFFeab308),
  LabelColor.green: LabelColorInfo('Zielony', 0xFF22c55e),
  LabelColor.blue: LabelColorInfo('Niebieski', 0xFF3b82f6),
  LabelColor.purple: LabelColorInfo('Fioletowy', 0xFFa855f7),
  LabelColor.pink: LabelColorInfo('Różowy', 0xFFec4899),
  LabelColor.gray: LabelColorInfo('Szary', 0xFF6b7280),
};

/// Limity etykiet
const int maxLabelsPerMedicine = 5;
const int maxLabelsGlobal = 15;

/// Etykieta użytkownika
class UserLabel {
  final String id;
  final String name;
  final LabelColor color;
  final int order;

  const UserLabel({
    required this.id,
    required this.name,
    required this.color,
    this.order = 0,
  });

  /// Tworzy z JSON
  factory UserLabel.fromJson(Map<String, dynamic> json) {
    return UserLabel(
      id: json['id'] as String,
      name: json['name'] as String,
      color: LabelColor.values.firstWhere(
        (c) => c.name == json['color'],
        orElse: () => LabelColor.gray,
      ),
      order: json['order'] as int? ?? 0,
    );
  }

  /// Eksport do JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'color': color.name, 'order': order};
  }

  /// Kopiuje z nowymi wartościami
  UserLabel copyWith({
    String? id,
    String? name,
    LabelColor? color,
    int? order,
  }) {
    return UserLabel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      order: order ?? this.order,
    );
  }

  /// Pobiera informacje o kolorze
  LabelColorInfo get colorInfo => labelColors[color]!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLabel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
