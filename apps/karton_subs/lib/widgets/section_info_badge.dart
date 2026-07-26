import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Ikona „i" przy tytule sekcji — tapnięcie tłumaczy, po co ta sekcja jest
/// i czym różni się od pozostałych.
///
/// Tap, nie długie przytrzymanie: domyślny wyzwalacz podpowiedzi na dotyku jest
/// praktycznie nieodkrywalny. Podpowiedź żyje 10 s, bo to kilka zdań do
/// przeczytania, a nie etykieta przycisku.
class SectionInfoBadge extends StatelessWidget {
  final String message;

  const SectionInfoBadge(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 10),
      preferBelow: true,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      child: Padding(
        // Powiększa cel dotyku bez rozpychania paska tytułu.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(
          LucideIcons.info,
          size: 18,
          color: AppColors.textSecondary,
          semanticLabel: 'O tej sekcji',
        ),
      ),
    );
  }
}

/// Opisy sekcji — trzymane razem, żeby czytały się jak jeden spójny podział
/// aplikacji, a nie pięć niezależnych zdań (ADR-019).
class SectionInfo {
  const SectionInfo._();

  static const budget =
      'Przegląd całości. „Bilans miesiąca" to kalendarz przepływów, płatności '
      'do odhaczenia i podsumowanie wpływów oraz wydatków wybranego miesiąca. '
      '„Plan" pokazuje, ile zostaje miesięcznie i jak przewidywania mają się '
      'do rzeczywistości.';

  static const incomes =
      'Skąd przychodzą pieniądze: wpływy cykliczne (pensja) i jednorazowe '
      '(premia). Cykliczne zasilają plan „zostaje miesięcznie", jednorazowe '
      'podbijają bilans swojego miesiąca.';

  static const bills =
      'Wydatki datowane: opłacone rachunki i zakupy oraz te zaplanowane na '
      'przyszłą datę. Uderzają w bilans konkretnego miesiąca, a nie w plan — '
      'więc trafia tu wszystko, czego nie chcesz rozkładać na miesięczną '
      'średnią. Tutaj też ustawiasz Planner (kwotę zarezerwowaną na rachunki) '
      'i skanujesz rachunki zdjęciem.';

  static const subscriptions =
      'Cyklicznie odnawiane usługi: streaming, software, karnety. Trzymane '
      'osobno od kosztów stałych, bo to wydatki uznaniowe — łatwiej ocenić, '
      'z czego zrezygnować. W planie liczą się jak koszty cykliczne.';

  static const recurringExpenses =
      'Koszty powtarzalne: stałe (czynsz, prąd), raty i przelew do budżetu '
      'domowego. Liczone jako średnia miesięczna (kwota × liczba płatności ÷ 12), '
      'więc miesiąc dodania pozycji nie ma znaczenia. Wydatek, którego nie chcesz '
      'uśredniać, dodaj w „Rachunkach".';
}
