import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../utils/credit_group.dart';
import '../utils/money_format.dart';
import 'budget_widgets.dart' show budgetNf;

/// Wcięcie pozycji rozwiniętej grupy karty.
///
/// 22 px to nie jest liczba z powietrza: tyle zajmuje strzałka rozwinięcia
/// w wierszu grupy (16 px ikony + 6 px odstępu), więc ikony pozycji ustawiają
/// się dokładnie pod ikoną karty, a strzałka zostaje jedyną rzeczą wystającą
/// w lewo. Widać wtedy, co jest nagłówkiem, a co jego zawartością.
const double kCreditGroupIndent = 22;

/// Zwinięty wiersz pozycji jednej karty: nazwa karty, licznik i SUMA składników.
///
/// Ten sam widget obsługuje oba ekrany, bo problem jest ten sam: model karty
/// jest 1:1 (zakup → własna spłata i własne lustro), a z konta schodzi jedna
/// kwota za okres. Różni się tylko opis i znak kwoty. Rozwinięcie odsłania te
/// same pozycje co wcześniej; nic tu nie zmienia danych ani sum sekcji.
class CreditGroupRow extends StatelessWidget {
  final CreditGroup group;
  final bool expanded;

  /// `null` = zwijanie wyłączone (tryb zaznaczania trzyma grupy rozwinięte).
  final VoidCallback? onToggle;

  const CreditGroupRow({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;
    final isIncome = group.kind == CreditGroupKind.cardLoan;
    final color = isIncome ? c.positive : c.negative;
    final sign = isIncome ? '+' : '−';
    final label = isIncome ? 'Zakupy kartą' : 'Spłaty karty';

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(
              expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
              size: 16,
              color: c.textSecondary,
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.creditCard, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.card,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$sign${budgetNf.format(group.total)}'
                        '${curLabelSuffix(group.currency.label)}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$label · ${group.entries.length} poz.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
