import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pigułka „Anuluj │ Zapisz" — jedno miejsce zapisu dla WSZYSTKICH formularzy.
///
/// Wcześniej przycisk zapisu był ostatnią pozycją przewijanej listy: żeby
/// zapisać, trzeba było przewinąć formularz do końca, a w arkuszach wysuwanych
/// potrafił w ogóle nie zmieścić się na ekranie. Teraz stoi w stałym miejscu
/// i jest widoczny niezależnie od tego, jak długi jest formularz.
///
/// **Nad klawiaturą** ląduje bez własnej obsługi insetów:
///   * na ekranie — jako `floatingActionButton` z [FloatingActionButtonLocation.centerFloat];
///     Scaffold podnosi go o wysokość klawiatury sam,
///   * w arkuszu — przez [FormSheet], które dokłada `viewInsets.bottom`.
class FormActionBar extends StatelessWidget {
  /// `null` = akcja zablokowana (np. trwa zapis) — obie stają się szare.
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  /// Krótko, bo pigułka jest wąska. „Dodaj wydatek" się tu nie mieści, a i tak
  /// nie mówiło nic ponad tytuł ekranu.
  final String saveLabel;
  final String cancelLabel;

  const FormActionBar({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'Zapisz',
    this.cancelLabel = 'Anuluj',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.semanticColors;

    // To samo szkło co pasek nawigacji: bez rozmycia pigułka była tylko
    // półprzezroczysta i treść pod nią prześwitywała, przez co obie warstwy
    // były nieczytelne. Jedna warstwa `BackdropFilter` na ekran — formularze
    // nie mają paska nawigacji, więc limit z docs/design.md zostaje dotrzymany.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.navGlass,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _action(
                theme,
                label: cancelLabel,
                onTap: onCancel,
                color: c.textSecondary,
              ),
              // Kreska rozdzielająca, jak w pigułce systemowej — bez niej dwa
              // teksty obok siebie czytają się jak jedna etykieta.
              Container(width: 1, height: 24, color: c.border),
              _action(
                theme,
                label: saveLabel,
                onTap: onSave,
                color: c.primary,
                bold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    ThemeData theme, {
    required String label,
    required VoidCallback? onTap,
    required Color color,
    bool bold = false,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: onTap == null ? color.withValues(alpha: 0.4) : color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

/// Odstęp na dole formularza, żeby ostatnie pole nie chowało się pod pigułką.
const double kFormActionBarSpace = 88;

/// Arkusz wysuwany z formularzem: treść się przewija, pigułka PŁYWA nad nią.
///
/// Bez tego wysoki formularz (np. kategoria z paletą kolorów i siatką ikon)
/// wypychał przycisk zapisu poza ekran — arkusz jechał z klawiaturą, ale sam
/// przycisk bywał już poza widokiem.
///
/// Pigułka leży w [Stack], a nie we własnym wierszu [Column]: własny wiersz
/// zabierał całą wysokość rzędu i zasłaniał siatkę ikon, choć sama pigułka
/// zajmuje tylko jej środek. Tak samo zachowuje się na ekranach (tam jako
/// `floatingActionButton`), więc oba miejsca wyglądają jednakowo.
class FormSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final FormActionBar actions;

  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // Klawiatura podnosi CAŁY arkusz — inaczej pigułka zniknęłaby pod nią.
      padding: EdgeInsets.only(bottom: insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          ),
          // Elastyczna, nie sztywna: krótki formularz zostaje niski, długi
          // przewija się zamiast rozpychać arkusz poza ekran.
          Flexible(
            child: Stack(
              children: [
                SingleChildScrollView(
                  // Zapas pod pigułkę — ostatni rząd ikon musi dać się kliknąć.
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    kFormActionBarSpace,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Center(child: actions),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
