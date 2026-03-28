// REFERENCE: Ten plik pochodzi z "Karton z lekami" (APPteczka).
// NIE kopiowac do nowego projektu -- sluzy jako wzorzec wzorcow:
// - Immutable model + copyWith pattern
// - JSON serialization/deserialization (fromJson/toJson)
// - Computed properties z lazy caching (_cachedTerminWaznosci)
// - Backward-compatible migration (legacy field -> new structure)
// - Enum z helper methods (PackageUnit -> label)
// Nowy model: docs/database.md -> Subscription

// medicine.dart v0.004 Added capacity field for package total quantity
import 'package:uuid/uuid.dart';

/// Jednostka ilości w opakowaniu
enum PackageUnit {
  none, // Brak określonej ilości
  pieces, // Sztuki (tabletki, kapsułki)
  ml, // Mililitry (syropy, krople)
  grams, // Gramy (maści, kremy, żele)
  sachets, // Saszetki
  doses, // Dawki
}

/// Opakowanie leku z własną datą ważności
class MedicinePackage {
  final String id;
  final String expiryDate; // ISO8601 ("2027-03-31")
  final bool isOpen; // true = otwarte, false = zamknięte (default)
  final int? capacity; // Pojemność opakowania (całkowita ilość)
  final int? pieceCount; // Pozostała ilość (zależna od unit)
  final int? percentRemaining; // % pozostały (tylko dla otwartych)
  final PackageUnit unit; // Jednostka ilości
  final String? openedDate; // Data otwarcia (ISO8601, opcjonalne)

  MedicinePackage({
    String? id,
    required this.expiryDate,
    this.isOpen = false,
    this.capacity,
    this.pieceCount,
    this.percentRemaining,
    this.unit = PackageUnit.pieces,
    this.openedDate,
  }) : id = id ?? const Uuid().v4();

  /// Tworzy z formatu MM/YYYY → ISO ostatni dzień miesiąca
  factory MedicinePackage.fromMMYYYY(
    String mmyyyy, {
    bool isOpen = false,
    int? capacity,
    int? pieceCount,
    int? percentRemaining,
    PackageUnit unit = PackageUnit.pieces,
    String? openedDate,
  }) {
    final parts = mmyyyy.split('/');
    if (parts.length != 2) {
      throw FormatException('Invalid format: $mmyyyy. Expected MM/YYYY');
    }
    final month = int.parse(parts[0]);
    final year = int.parse(parts[1]);
    // Ostatni dzień miesiąca
    final lastDay = DateTime(year, month + 1, 0);
    return MedicinePackage(
      expiryDate: lastDay.toIso8601String().split('T')[0],
      isOpen: isOpen,
      capacity: capacity,
      pieceCount: pieceCount,
      percentRemaining: percentRemaining,
      unit: unit,
      openedDate: openedDate,
    );
  }

  factory MedicinePackage.fromJson(Map<String, dynamic> json) {
    // Parse unit with backward compatibility
    PackageUnit unit = PackageUnit.pieces;
    if (json['unit'] != null) {
      final unitStr = json['unit'] as String;
      unit = PackageUnit.values.firstWhere(
        (e) => e.name == unitStr,
        orElse: () => PackageUnit.pieces,
      );
    }

    // Capacity with fallback to pieceCount for backward compatibility
    final capacity = json['capacity'] as int? ?? json['pieceCount'] as int?;

    return MedicinePackage(
      id: json['id'] as String?,
      expiryDate: json['expiryDate'] as String,
      isOpen: json['isOpen'] as bool? ?? false,
      capacity: capacity,
      pieceCount: json['pieceCount'] as int?,
      percentRemaining: json['percentRemaining'] as int?,
      unit: unit,
      openedDate: json['openedDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expiryDate': expiryDate,
      if (isOpen) 'isOpen': isOpen,
      if (capacity != null) 'capacity': capacity,
      if (pieceCount != null) 'pieceCount': pieceCount,
      if (percentRemaining != null) 'percentRemaining': percentRemaining,
      'unit': unit.name,
      if (openedDate != null) 'openedDate': openedDate,
    };
  }

  MedicinePackage copyWith({
    String? id,
    String? expiryDate,
    bool? isOpen,
    int? capacity,
    int? pieceCount,
    int? percentRemaining,
    PackageUnit? unit,
    String? openedDate,
    bool clearCapacity = false,
    bool clearPieceCount = false,
    bool clearPercentRemaining = false,
    bool clearOpenedDate = false,
  }) {
    return MedicinePackage(
      id: id ?? this.id,
      expiryDate: expiryDate ?? this.expiryDate,
      isOpen: isOpen ?? this.isOpen,
      capacity: clearCapacity ? null : (capacity ?? this.capacity),
      pieceCount: clearPieceCount ? null : (pieceCount ?? this.pieceCount),
      percentRemaining: clearPercentRemaining
          ? null
          : (percentRemaining ?? this.percentRemaining),
      unit: unit ?? this.unit,
      openedDate: clearOpenedDate ? null : (openedDate ?? this.openedDate),
    );
  }

  /// Formatuje datę jako MM/YYYY
  String get displayDate {
    final date = DateTime.tryParse(expiryDate);
    if (date == null) return expiryDate;
    return '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Parsuje datę do DateTime
  DateTime? get dateTime => DateTime.tryParse(expiryDate);

  /// Opis statusu opakowania
  String get remainingDescription => getDescription();

  /// Opis statusu opakowania z opcjonalną datą "Zużyć przed"
  String getDescription({String? useByDate}) {
    // Helper: jednostka w odpowiednim formacie
    String getUnitLabel() {
      switch (unit) {
        case PackageUnit.pieces:
          return 'szt.';
        case PackageUnit.ml:
          return 'ml';
        case PackageUnit.grams:
          return 'g';
        case PackageUnit.sachets:
          return 'sasz.';
        case PackageUnit.doses:
          return 'dawki';
        case PackageUnit.none:
          return '';
      }
    }

    // Helper: formatuje datę otwarcia
    String? formatOpenedDate() {
      if (openedDate == null) return null;
      try {
        final date = DateTime.parse(openedDate!);
        return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      } catch (_) {
        return null;
      }
    }

    final unitLabel = getUnitLabel();
    final openedDateStr = formatOpenedDate();

    if (isOpen) {
      // Opakowanie otwarte - nowy format: Otwarte: *data* · Zużyć przed: *data* · Pozostało: X szt.
      final parts = <String>[];

      if (openedDateStr != null) {
        parts.add('Otwarte: $openedDateStr');
      } else {
        parts.add('Opakowanie otwarte');
      }

      if (useByDate != null) {
        parts.add('Zużyć przed: $useByDate');
      }

      if (percentRemaining != null) {
        parts.add('Pozostało: $percentRemaining%');
      } else if (pieceCount != null && unit != PackageUnit.none) {
        parts.add('Pozostało: $pieceCount $unitLabel');
      }

      return parts.join(' · ');
    } else {
      // Opakowanie zamknięte
      if (pieceCount != null && unit != PackageUnit.none) {
        return 'Zamknięte: $pieceCount $unitLabel';
      }
      return 'Opakowanie zamknięte';
    }
  }
}

/// Model leku - zgodny z wersją web
class Medicine {
  final String id;
  final String? nazwa;
  final String? power; // Moc leku (np. "500mg") z RPL
  final String opis;
  final List<String> wskazania;
  final List<String> tagi;
  final List<String> labels;
  final String? notatka;
  final List<MedicinePackage> packages;
  final String? _legacyTerminWaznosci; // For lazy migration
  final String? leafletUrl;
  final int? dailyIntake; // Dzienne zużycie tabletek
  final String dataDodania;
  final bool
  isVerifiedByBarcode; // Dane zweryfikowane po kodzie kreskowym (RPL)
  final String? verificationNote; // Monit o konflikcie nazwa/kod
  final String?
  shelfLifeAfterOpening; // Cytat z ulotki o terminie ważności po otwarciu
  final String?
  shelfLifeStatus; // "pending" | "completed" | "error" | "manual" | null
  final String?
  pharmaceuticalForm; // Postać farmaceutyczna z RPL (np. "Tabletka powlekana")
  final bool isPinned; // Przypięty na górę listy
  final bool isInUse; // Lek w użyciu (przyjmowany)
  final String?
      supplyEndDate; // Data końca zapasu (tryb manualny, ISO8601)
  final String?
      lastAutoDeductionDate; // Data ostatniej auto-dedukcji (ISO8601, tylko date)

  Medicine({
    required this.id,
    this.nazwa,
    this.power,
    required this.opis,
    required this.wskazania,
    required this.tagi,
    this.labels = const [],
    this.notatka,
    this.packages = const [],
    String? terminWaznosci,
    this.leafletUrl,
    this.dailyIntake,
    required this.dataDodania,
    this.isVerifiedByBarcode = false,
    this.verificationNote,
    this.shelfLifeAfterOpening,
    this.shelfLifeStatus,
    this.pharmaceuticalForm,
    this.isPinned = false,
    this.isInUse = false,
    this.supplyEndDate,
    this.lastAutoDeductionDate,
  }) : _legacyTerminWaznosci = terminWaznosci;

  /// Computed property - zwraca najkrótszą datę (wsteczna kompatybilność)
  /// Cached — Medicine jest immutable
  String? _cachedTerminWaznosci;
  bool _terminWaznosciComputed = false;

  String? get terminWaznosci {
    if (!_terminWaznosciComputed) {
      _cachedTerminWaznosci = _computeTerminWaznosci();
      _terminWaznosciComputed = true;
    }
    return _cachedTerminWaznosci;
  }

  String? _computeTerminWaznosci() {
    if (packages.isEmpty) return _legacyTerminWaznosci;
    return packages
        .map((p) => p.expiryDate)
        .reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  }

  /// Zwraca opakowania w kolejności dodawania (bez sortowania)
  /// Cached — Medicine jest immutable
  List<MedicinePackage>? _cachedSortedPackages;

  List<MedicinePackage> get sortedPackages {
    return _cachedSortedPackages ??= List<MedicinePackage>.from(packages);
  }

  /// Oblicza łączną ilość ze wszystkich opakowań (niezależnie od jednostki)
  int get totalPieceCount {
    int total = 0;
    for (final package in packages) {
      if (package.pieceCount != null && package.unit != PackageUnit.none) {
        total += package.pieceCount!;
      }
    }
    return total;
  }

  /// Dominująca jednostka opakowań jako label do UI (np. 'szt.', 'ml', 'g')
  /// Jeśli wszystkie opakowania mają tę samą jednostkę → jej label.
  /// Mieszane lub brak → 'szt.' (domyślnie).
  String get dominantUnitLabel {
    final units = packages
        .where((p) => p.unit != PackageUnit.none)
        .map((p) => p.unit)
        .toSet();
    if (units.length == 1) {
      switch (units.first) {
        case PackageUnit.pieces:
          return 'szt.';
        case PackageUnit.ml:
          return 'ml';
        case PackageUnit.grams:
          return 'g';
        case PackageUnit.sachets:
          return 'sasz.';
        case PackageUnit.doses:
          return 'daw.';
        case PackageUnit.none:
          return 'szt.';
      }
    }
    return 'szt.';
  }

  /// Kalkulator zapasu - oblicza do kiedy wystarczy leku (pierwszy dzien bez leku)
  /// Zwraca null jeśli brak danych (pieceCount lub dailyIntake)
  /// Działa dla wszystkich jednostek (pieces, ml, g, saszetki)
  DateTime? calculateSupplyEndDate() {
    if (dailyIntake == null || dailyIntake! <= 0) return null;
    final total = totalPieceCount;
    if (total <= 0) return null;

    // ceil - ostatnia dawka + 1 dzień = pierwszy dzień bez leku
    final daysRemaining = (total / dailyIntake!).ceil();
    return DateTime.now().add(Duration(days: daysRemaining));
  }

  /// Tworzy z JSON (import/backup) - z lazy migration
  factory Medicine.fromJson(Map<String, dynamic> json) {
    final packagesJson = json['packages'] as List?;
    final legacyTermin = json['terminWaznosci'] as String?;

    List<MedicinePackage> packages = [];
    if (packagesJson != null && packagesJson.isNotEmpty) {
      packages = packagesJson.map((p) => MedicinePackage.fromJson(p)).toList();
    } else if (legacyTermin != null) {
      // Lazy migration: stary terminWaznosci → nowe packages
      packages = [MedicinePackage(expiryDate: legacyTermin)];
    }

    return Medicine(
      id: json['id'] as String,
      nazwa: json['nazwa'] as String?,
      power: json['power'] as String?,
      opis: json['opis'] as String? ?? '',
      wskazania: List<String>.from(json['wskazania'] ?? []),
      tagi: List<String>.from(json['tagi'] ?? []),
      labels: List<String>.from(json['labels'] ?? []),
      notatka: json['notatka'] as String?,
      packages: packages,
      leafletUrl: json['leafletUrl'] as String?,
      dailyIntake: json['dailyIntake'] as int?,
      dataDodania:
          json['dataDodania'] as String? ?? DateTime.now().toIso8601String(),
      isVerifiedByBarcode: json['isVerifiedByBarcode'] as bool? ?? false,
      verificationNote: json['verificationNote'] as String?,
      shelfLifeAfterOpening: json['shelfLifeAfterOpening'] as String?,
      shelfLifeStatus: json['shelfLifeStatus'] as String?,
      pharmaceuticalForm: json['pharmaceuticalForm'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      // Migracja: isInUse domyślnie true gdy dailyIntake > 0
      isInUse: json['isInUse'] as bool? ??
          ((json['dailyIntake'] as int?) != null &&
              (json['dailyIntake'] as int?)! > 0),
      supplyEndDate: json['supplyEndDate'] as String?,
      lastAutoDeductionDate: json['lastAutoDeductionDate'] as String?,
    );
  }

  /// Eksport do JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nazwa': nazwa,
      if (power != null) 'power': power,
      'opis': opis,
      'wskazania': wskazania,
      'tagi': tagi,
      'labels': labels,
      'notatka': notatka,
      'packages': packages.map((p) => p.toJson()).toList(),
      // Zachowaj terminWaznosci dla wstecznej kompatybilności
      'terminWaznosci': terminWaznosci,
      'leafletUrl': leafletUrl,
      if (dailyIntake != null) 'dailyIntake': dailyIntake,
      'dataDodania': dataDodania,
      if (isVerifiedByBarcode) 'isVerifiedByBarcode': isVerifiedByBarcode,
      if (verificationNote != null) 'verificationNote': verificationNote,
      if (shelfLifeAfterOpening != null)
        'shelfLifeAfterOpening': shelfLifeAfterOpening,
      if (shelfLifeStatus != null) 'shelfLifeStatus': shelfLifeStatus,
      if (pharmaceuticalForm != null) 'pharmaceuticalForm': pharmaceuticalForm,
      if (isPinned) 'isPinned': isPinned,
      if (isInUse) 'isInUse': isInUse,
      if (supplyEndDate != null) 'supplyEndDate': supplyEndDate,
      if (lastAutoDeductionDate != null)
        'lastAutoDeductionDate': lastAutoDeductionDate,
    };
  }

  /// Kopiuje z nowymi wartościami
  Medicine copyWith({
    String? id,
    String? nazwa,
    String? power,
    String? opis,
    List<String>? wskazania,
    List<String>? tagi,
    List<String>? labels,
    String? notatka,
    List<MedicinePackage>? packages,
    String? terminWaznosci,
    String? leafletUrl,
    int? dailyIntake,
    String? dataDodania,
    bool? isVerifiedByBarcode,
    String? verificationNote,
    String? shelfLifeAfterOpening,
    String? shelfLifeStatus,
    String? pharmaceuticalForm,
    bool? isPinned,
    bool? isInUse,
    String? supplyEndDate,
    String? lastAutoDeductionDate,
    bool clearNotatka = false, // Explicite ustawia notatka na null
    bool clearDailyIntake = false, // Explicite ustawia dailyIntake na null
    bool clearSupplyEndDate = false,
    bool clearLastAutoDeductionDate = false,
  }) {
    return Medicine(
      id: id ?? this.id,
      nazwa: nazwa ?? this.nazwa,
      power: power ?? this.power,
      opis: opis ?? this.opis,
      wskazania: wskazania ?? this.wskazania,
      tagi: tagi ?? this.tagi,
      labels: labels ?? this.labels,
      notatka: clearNotatka ? null : (notatka ?? this.notatka),
      packages: packages ?? this.packages,
      terminWaznosci: terminWaznosci ?? _legacyTerminWaznosci,
      leafletUrl: leafletUrl ?? this.leafletUrl,
      dailyIntake: clearDailyIntake ? null : (dailyIntake ?? this.dailyIntake),
      dataDodania: dataDodania ?? this.dataDodania,
      isVerifiedByBarcode: isVerifiedByBarcode ?? this.isVerifiedByBarcode,
      verificationNote: verificationNote ?? this.verificationNote,
      shelfLifeAfterOpening:
          shelfLifeAfterOpening ?? this.shelfLifeAfterOpening,
      shelfLifeStatus: shelfLifeStatus ?? this.shelfLifeStatus,
      pharmaceuticalForm: pharmaceuticalForm ?? this.pharmaceuticalForm,
      isPinned: isPinned ?? this.isPinned,
      isInUse: isInUse ?? this.isInUse,
      supplyEndDate: clearSupplyEndDate
          ? null
          : (supplyEndDate ?? this.supplyEndDate),
      lastAutoDeductionDate: clearLastAutoDeductionDate
          ? null
          : (lastAutoDeductionDate ?? this.lastAutoDeductionDate),
    );
  }

  /// Sprawdza status terminu ważności (bazuje na najkrótszej dacie)
  ExpiryStatus get expiryStatus {
    final termin = terminWaznosci;
    if (termin == null) return ExpiryStatus.unknown;

    final expiry = DateTime.tryParse(termin);
    if (expiry == null) return ExpiryStatus.unknown;

    final now = DateTime.now();
    final daysUntilExpiry = expiry.difference(now).inDays;

    if (daysUntilExpiry < 0) return ExpiryStatus.expired;
    if (daysUntilExpiry <= 30) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.valid;
  }

  /// Liczba opakowań
  int get packageCount => packages.isEmpty
      ? (_legacyTerminWaznosci != null ? 1 : 0)
      : packages.length;
}

/// Status terminu ważności
enum ExpiryStatus { valid, expiringSoon, expired, unknown }
