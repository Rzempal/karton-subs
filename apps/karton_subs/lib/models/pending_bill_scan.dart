import 'budget_entry.dart';

/// Status pozycji oczekującej po skanie rachunku.
enum PendingScanStatus {
  /// Silnik AI pracuje w tle (OCR ~30–45 s).
  processing,

  /// Rozpoznano — czeka na zatwierdzenie przez użytkownika.
  done,

  /// Rozpoznanie się nie powiodło (można ponowić lub usunąć).
  error,
}

/// Rachunek rozpoznany ze zdjęcia, oczekujący na zatwierdzenie.
///
/// Pozycje oczekujące są LOKALNE (poza synchronizacją, backupem i bilansem) —
/// do budżetu ([BudgetEntryType.billPayment]) trafiają dopiero po zatwierdzeniu.
/// [imagePath] to kopia zdjęcia w katalogu aplikacji: miniatura do porównania
/// z rozpoznaniem; kasowana razem z pozycją.
class PendingBillScan {
  final String id;
  final String imagePath;
  final BudgetScope scope;
  final PendingScanStatus status;
  final DateTime createdAt;

  // Wynik OCR (status == done; pola mogą być null, gdy nieczytelne na zdjęciu).
  final String? name;
  final double? amount;
  final String? currency;
  final DateTime? date;

  /// Sugestia rodzaju z silnika (prad/gaz/woda/...) — do dopasowania kategorii.
  final String? rodzaj;

  // Status == error.
  final String? errorMessage;

  const PendingBillScan({
    required this.id,
    required this.imagePath,
    required this.scope,
    required this.status,
    required this.createdAt,
    this.name,
    this.amount,
    this.currency,
    this.date,
    this.rodzaj,
    this.errorMessage,
  });

  PendingBillScan copyWith({
    PendingScanStatus? status,
    String? name,
    double? amount,
    String? currency,
    DateTime? date,
    String? rodzaj,
    String? errorMessage,
  }) =>
      PendingBillScan(
        id: id,
        imagePath: imagePath,
        scope: scope,
        status: status ?? this.status,
        createdAt: createdAt,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        date: date ?? this.date,
        rodzaj: rodzaj ?? this.rodzaj,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  factory PendingBillScan.fromJson(Map<String, dynamic> json) => PendingBillScan(
        id: json['id'] as String,
        imagePath: json['imagePath'] as String,
        scope: BudgetScope.values.firstWhere(
          (s) => s.name == json['scope'],
          orElse: () => BudgetScope.personal,
        ),
        status: PendingScanStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => PendingScanStatus.error,
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        name: json['name'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String)
            : null,
        rodzaj: json['rodzaj'] as String?,
        errorMessage: json['errorMessage'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'scope': scope.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (name != null) 'name': name,
        if (amount != null) 'amount': amount,
        if (currency != null) 'currency': currency,
        if (date != null) 'date': date!.toIso8601String(),
        if (rodzaj != null) 'rodzaj': rodzaj,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };
}
