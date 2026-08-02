import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pasek „ile z planu" — jeden język dla wszystkich porównań plan vs realny
/// (rachunki wobec koperty, rok wobec planu rocznego, subskrypcje wobec limitu).
///
/// Do wysokości planu pasek rośnie na zielono na neutralnym torze. Po
/// przekroczeniu **nie zatrzymuje się na pełnym, czerwonym pasku** — ten mówi
/// tylko „przekroczono" i wygląda tak samo przy 1% i przy 200% nadwyżki.
/// Zamiast tego cały tor dzieli się w proporcji: zielona część to plan,
/// czerwona to nadwyżka. Im czerwieńszy pasek, tym mocniej plan przebity.
///
/// ```
/// w planie:      [■■■■■■□□□□□□]   zielone = wydane, szare = zostało
/// ponad plan:    [■■■■■■■■□□□□]   zielone = plan, czerwone = nadwyżka
/// ```
class PlanProgressBar extends StatelessWidget {
  /// Kwota wydana (realna).
  final double value;

  /// Kwota zaplanowana. `<= 0` = nie ma z czym porównywać, pasek znika.
  final double plan;

  final double height;

  const PlanProgressBar({
    super.key,
    required this.value,
    required this.plan,
    this.height = 8,
  });

  /// Udziały odcinków paska (sumują się do 1): część mieszcząca się w planie,
  /// nadwyżka ponad plan i wolne miejsce do końca planu.
  ///
  /// Wydzielone z widoku, bo to jedyna arytmetyka tego paska — i jedyne
  /// miejsce, które da się sprawdzić testem zamiast oglądaniem.
  static ({double within, double over, double free}) shares(
    double value,
    double plan,
  ) {
    if (plan <= 0) return (within: 0, over: 0, free: 1);
    final spent = value < 0 ? 0.0 : value;
    if (spent <= plan) {
      return (within: spent / plan, over: 0, free: (plan - spent) / plan);
    }
    // Skala rośnie razem z wydatkiem: plan zajmuje tyle, ile go jest w całości.
    return (within: plan / spent, over: (spent - plan) / spent, free: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (plan <= 0) return const SizedBox.shrink();
    final c = context.semanticColors;
    final s = shares(value, plan);

    // Flex w promilach — Row dzieli szerokość w dokładnie tej proporcji,
    // bez liczenia pikseli i bez LayoutBuilder.
    int flex(double share) => (share * 1000).round();

    Widget segment(double share, Color color) =>
        Expanded(flex: flex(share), child: Container(color: color));

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            segment(s.within, c.positive),
            if (s.over > 0) segment(s.over, c.negative),
            if (s.free > 0) segment(s.free, c.border),
          ],
        ),
      ),
    );
  }
}
