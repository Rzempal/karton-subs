import 'package:flutter/material.dart';
// Ikona cloudSync jest tylko w nowszym pakiecie lucide_icons_flutter (glify
// nieużywane wycina tree-shaking, więc drugi font ikon nie waży w APK).
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';
import '../controllers/budget_controller.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// Przycisk „Synchronizuj teraz" do AppBarów (Dashboard, Budżet).
/// Widoczny tylko po sparowaniu; podczas synchronizacji pokazuje spinner.
/// Po zakończeniu odświeża budżet (gdy przyszły zmiany) i pokazuje wynik.
class SyncNowButton extends StatelessWidget {
  const SyncNowButton({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    if (!sync.isPaired) return const SizedBox.shrink();

    if (sync.isSyncing) {
      // Ten sam ślad co IconButton (48px), spinner w miejscu ikony.
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      tooltip: 'Synchronizuj budżet domowy',
      icon: const Icon(lucide.LucideIcons.cloudSync),
      onPressed: () async {
        final result = await context.read<SyncService>().syncNow();
        if (!context.mounted) return;
        if (result.changedLocal) {
          context.read<BudgetController>().refresh();
        }
        showSyncResultSnack(context, result);
      },
    );
  }
}

/// Wspólny komunikat wyniku synchronizacji (AppBary + ekran synchronizacji).
void showSyncResultSnack(BuildContext context, SyncResult result,
    {bool joined = false}) {
  switch (result.outcome) {
    case SyncOutcome.ok:
      showAppSnack(
          context, joined ? 'Połączono i zsynchronizowano' : 'Zsynchronizowano');
    case SyncOutcome.offline:
      showAppSnack(
          context,
          'Serwer synchronizacji nie odpowiada. Sprawdź internet lub spróbuj '
          'za chwilę — zmiany wyślą się przy następnej synchronizacji.',
          isError: true);
    case SyncOutcome.error:
      showAppSnack(context, result.message ?? 'Nie udało się zsynchronizować',
          isError: true);
    case SyncOutcome.notPaired:
      break;
  }
}

void showAppSnack(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: isError ? context.semanticColors.negative : null,
  ));
}
