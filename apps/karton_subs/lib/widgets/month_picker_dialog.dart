import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Wybór miesiąca: rok ze strzałkami + siatka dwunastu miesięcy.
///
/// Zamiast pełnego kalendarza (`showDatePicker`) — wybierany jest miesiąc, więc
/// pytanie o dzień byłoby puste. Skok o kilka lat wstecz zajmuje dwa tapnięcia
/// zamiast przewijania miesiąc po miesiącu strzałkami.
///
/// Zwraca pierwszy dzień wybranego miesiąca albo `null` (anulowane).
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required DateTime initialMonth,
  required DateTime today,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(
      initialMonth: initialMonth,
      today: today,
    ),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime today;

  const _MonthPickerDialog({required this.initialMonth, required this.today});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initialMonth.year;

  void _pick(int month) =>
      Navigator.pop(context, DateTime(_year, month));

  /// Przycisk miesiąca: wypełniony = wybrany, obramowany = miesiąc bieżący.
  Widget _monthButton(int month) {
    final raw = DateFormat('LLL', 'pl_PL').format(DateTime(_year, month));
    final label = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
    final selected = _year == widget.initialMonth.year &&
        month == widget.initialMonth.month;
    final isToday =
        _year == widget.today.year && month == widget.today.month;
    final style = ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    if (selected) {
      return FilledButton(onPressed: () => _pick(month), style: style, child: text);
    }
    if (isToday) {
      return OutlinedButton(
        onPressed: () => _pick(month),
        style: style,
        child: text,
      );
    }
    return TextButton(onPressed: () => _pick(month), style: style, child: text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Wybierz miesiąc'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Poprzedni rok',
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: () => setState(() => _year--),
                ),
                Text('$_year', style: theme.textTheme.titleMedium),
                IconButton(
                  tooltip: 'Następny rok',
                  icon: const Icon(LucideIcons.chevronRight),
                  onPressed: () => setState(() => _year++),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (var row = 0; row < 4; row++)
              Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _monthButton(row * 3 + col + 1),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            DateTime(widget.today.year, widget.today.month),
          ),
          child: const Text('Dzisiaj'),
        ),
      ],
    );
  }
}
