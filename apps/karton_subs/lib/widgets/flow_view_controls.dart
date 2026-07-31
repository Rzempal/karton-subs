import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'budget_widgets.dart' show MonthFlowSort, MonthFlowGrouping;

/// Sortowanie i grupowanie sekcji miesiąca — dwie ikony przy nagłówku sekcji,
/// której dotyczą („Płatności", „Podsumowanie miesiąca").
///
/// Wcześniej stały w pasku tytułu ekranu: daleko od list, na które działały,
/// i widoczne także wtedy, gdy nie było czego sortować. Tutaj są przy samej
/// treści, więc związek jest oczywisty bez tłumaczenia.
class FlowViewControls extends StatelessWidget {
  final MonthFlowSort sort;
  final MonthFlowGrouping grouping;
  final ValueChanged<MonthFlowSort> onSortChanged;
  final ValueChanged<MonthFlowGrouping> onGroupingChanged;

  const FlowViewControls({
    super.key,
    required this.sort,
    required this.grouping,
    required this.onSortChanged,
    required this.onGroupingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.semanticColors;
    final grouped = grouping == MonthFlowGrouping.byType;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: sort == MonthFlowSort.byName
              ? 'Sortuj: A→Z (nazwa)'
              : 'Sortuj: po dacie',
          icon: Icon(
            sort == MonthFlowSort.byName
                ? LucideIcons.arrowDownAZ
                : LucideIcons.arrowDown01,
            size: 18,
          ),
          onPressed: () => onSortChanged(
            sort == MonthFlowSort.byName
                ? MonthFlowSort.byDate
                : MonthFlowSort.byName,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          isSelected: grouped,
          tooltip: grouped
              ? 'Grupowanie po typie (włączone)'
              : 'Grupuj po typie: rachunki / subskrypcje / budżet',
          // Aktywny stan = wypełniona pigułka (widoczna też w motywie mono,
          // gdzie akcent jest bezbarwny) + ikona w kolorze akcentu.
          style: grouped
              ? IconButton.styleFrom(
                  backgroundColor: c.primary.withValues(alpha: 0.25),
                  foregroundColor: c.primary,
                )
              : null,
          icon: const Icon(LucideIcons.layers, size: 18),
          onPressed: () => onGroupingChanged(
            grouped ? MonthFlowGrouping.none : MonthFlowGrouping.byType,
          ),
        ),
      ],
    );
  }
}
