/// Pojedyncza pozycja koperty „Na rachunki" (plan rezerwy na rachunki).
///
/// Koperta danego zakresu to lista takich pozycji; ich suma = rezerwa
/// „Na rachunki", która pomniejsza „zostaje/mies" (a w bilansie miesiąca jest
/// podmieniana na realne rachunki — patrz [BudgetService]). Bufor dodaje się
/// jako zwykła pozycja o nazwie „bufor".
///
/// Lokalne (jak `budgetLimit`) — poza backupem i synchronizacją domowego,
/// spójnie z dotychczasową koperta pojedynczej kwoty.
class BillsAllocationItem {
  final String id;
  final String name;
  final double amount;

  /// Metoda płatności (po nazwie, jak w [BudgetEntry]). `null` = brak.
  final String? paymentMethod;

  const BillsAllocationItem({
    required this.id,
    required this.name,
    required this.amount,
    this.paymentMethod,
  });

  factory BillsAllocationItem.fromJson(Map<String, dynamic> json) =>
      BillsAllocationItem(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: json['paymentMethod'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
  };

  BillsAllocationItem copyWith({
    String? name,
    double? amount,
    String? paymentMethod,
    bool clearPaymentMethod = false,
  }) => BillsAllocationItem(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    paymentMethod: clearPaymentMethod
        ? null
        : (paymentMethod ?? this.paymentMethod),
  );
}
