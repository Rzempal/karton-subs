import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

// Przycisk „Synchronizuj teraz" w paskach ekranów zastąpił standardowy gest
// przeciągnięcia w dół (`SyncRefresh`) — użytkownik nie musi wiedzieć, że taka
// ikona istnieje. Ten plik trzyma już tylko wspólne komunikaty wyniku,
// używane też przez ekran „Budżet domowy".

/// Wspólny komunikat wyniku synchronizacji (gest odświeżania + ekran sync).
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
