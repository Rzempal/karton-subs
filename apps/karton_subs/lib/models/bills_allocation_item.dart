/// Pojedyncza pozycja koperty „Na rachunki" (plan rezerwy na rachunki).
///
/// Koperta danego zakresu to lista takich pozycji; ich suma = rezerwa
/// „Na rachunki", która pomniejsza „zostaje/mies" (a w bilansie miesiąca jest
/// podmieniana na realne rachunki — patrz [BudgetService]). Bufor dodaje się
/// jako zwykła pozycja o nazwie „bufor".
///
/// Wchodzi do backupu (format v6+) oraz — w zakresie DOMOWYM — do synchronizacji
/// (ADR-022). Dlatego pozycja nosi [updatedAt] i [deleted]: scalanie między
/// telefonami działa per pozycja („ostatnia zmiana wygrywa" + nagrobki), tak jak
/// dla pozycji budżetu. Zakres osobisty zostaje lokalny.
class BillsAllocationItem {
  final String id;
  final String name;
  final double amount;

  /// Znacznik ostatniej zmiany — klucz scalania przy synchronizacji.
  /// `null` w pozycjach zapisanych przed ADR-022 (traktowane jako najstarsze).
  final DateTime? updatedAt;

  /// Nagrobek: pozycja usunięta, ale zachowana, by usunięcie dotarło do drugiego
  /// telefonu. Pomijana w UI i w sumie koperty.
  final bool deleted;

  /// Metoda płatności (po nazwie, jak w [BudgetEntry]). `null` = brak.
  final String? paymentMethod;

  /// Kategoria (jak w [BudgetEntry]) — na liście objawia się tylko kolorem
  /// kropki przed nazwą pozycji, bez wypisywania nazwy kategorii. `null` = brak.
  final String? categoryId;

  const BillsAllocationItem({
    required this.id,
    required this.name,
    required this.amount,
    this.paymentMethod,
    this.categoryId,
    this.updatedAt,
    this.deleted = false,
  });

  factory BillsAllocationItem.fromJson(Map<String, dynamic> json) =>
      BillsAllocationItem(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: json['paymentMethod'] as String?,
        categoryId: json['categoryId'] as String?,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        deleted: json['deleted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (categoryId != null) 'categoryId': categoryId,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (deleted) 'deleted': true,
  };

  BillsAllocationItem copyWith({
    String? name,
    double? amount,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? updatedAt,
    bool? deleted,
  }) => BillsAllocationItem(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    paymentMethod: clearPaymentMethod
        ? null
        : (paymentMethod ?? this.paymentMethod),
    categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
}
