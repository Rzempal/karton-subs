import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/budget_controller.dart';
import '../services/sync_service.dart';
import 'sync_now_button.dart' show showSyncResultSnack;

/// Przeciągnięcie w dół = odświeżenie: standardowy gest zamiast przycisku
/// „Synchronizuj teraz" w pasku (wcześniej trzeba było o nim wiedzieć).
///
/// Gest działa ZAWSZE, także bez sparowania z drugim telefonem — wtedy tylko
/// przelicza dane lokalne. Inaczej użytkownik bez budżetu domowego pociągnąłby
/// listę i nie stałoby się nic, co wygląda na zepsutą aplikację.
///
/// Komunikat pokazujemy wyłącznie, gdy naprawdę była synchronizacja: przy samym
/// odświeżeniu lokalnym pasek na dole ekranu byłby hałasem.
class SyncRefresh extends StatelessWidget {
  final Widget child;

  const SyncRefresh({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => refreshNow(context),
      child: child,
    );
  }

  /// Wspólna akcja odświeżenia — także do wywołania spoza gestu.
  static Future<void> refreshNow(BuildContext context) async {
    final sync = context.read<SyncService>();
    final budget = context.read<BudgetController>();

    if (!sync.isPaired) {
      budget.refresh();
      return;
    }

    final result = await sync.syncNow();
    if (!context.mounted) return;
    if (result.changedLocal) budget.refresh();
    showSyncResultSnack(context, result);
  }
}
