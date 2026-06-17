# ADR-007: Design tokens jako jedyne źródło prawdy + strażnik spójności

Data: 2026-06-17
Status: zaakceptowany

> **Powiązane:** [design.md](../design.md) | [ADR-002 Semantic color tokens](ADR-002-semantic-color-tokens.md)
> | [ADR-005 Aurora](ADR-005-aurora-jeden-ciemny-motyw.md) | [conventions.md](../standards/conventions.md)

## Kontekst

Po wdrożeniu Aurory (ADR-005) audyt warstwy UI wykazał ~64 zaszyte na sztywno
kolory i powtarzane literały promieni (np. `Color(0xFF1B1240)` w 5 plikach,
`Colors.red` na akcjach usuwania, `BorderRadius.circular(22)` rozsypane po
widgetach). Konkretny objaw rozjazdu: okno wyboru daty (`showDatePicker`) było
półprzezroczyste, bo korzysta z osobnego `DatePickerThemeData`, a nie z
`dialogTheme` — brak wpisu = domyślny, niespójny wygląd.

Zaszyte literały i niekompletne pokrycie motywem powodują, że każda kolejna
zmiana stylu rozjeżdża design (trzeba ją powtórzyć w wielu miejscach, łatwo
przeoczyć), a nowe komponenty „wyglądają inaczej" zanim ktoś je ręcznie dostyluje.

## Decyzja

1. **Jedno źródło prawdy:** `lib/theme/app_theme.dart` — `AppColors`, `AppRadii`,
   `AppSemanticColors` + `ThemeData`. Komponenty czytają tokeny, nigdy literały.
2. **Pełne pokrycie motywem:** każdy stockowy komponent Material ma swój wpis w
   `ThemeData` (dialog, datePicker, timePicker, menu/popup/dropdown, snackBar,
   tooltip, progressIndicator, textSelection). Nowy komponent stylujemy **raz**
   centralnie, nigdy per-wywołanie — wtedy każdy przyszły ekran jest Aurora „za darmo".
3. **Tokeny zamiast literałów:** `AppColors.onAccent` (tekst na akcencie),
   `AppRadii.*` (promienie marki), akcje destrukcyjne → `AppColors.negative` /
   `context.semanticColors.negative`.
4. **Strażnik automatyczny:** `scripts/check_design_tokens.ps1` blokuje surowe
   `Color(0x…)` i nazwane kolory semantyczne poza allowlistą (`lib/theme/**`,
   `pdf_export_service.dart`). Reguła „Design tokens" w
   [conventions.md](../standards/conventions.md).
5. **Dozwolone prymitywy:** `Colors.transparent` / `white` / `black` (obramowania,
   cienie, zasłony) — nie są kolorami marki.

## Konsekwencje

- **Pozytywne:**
  - Zmiana wyglądu = jedno miejsce; brak rozjazdu między ekranami.
  - Nowe dialogi/pickery/menu dziedziczą Aurorę bez stylowania per-wywołanie.
  - Strażnik wyłapuje regresje zanim trafią do repo (już znalazł 1 zwis: `Colors.grey`).
- **Negatywne / ryzyka:**
  - Strażnik to skrypt uruchamiany ręcznie/w pre-commit — nie blokuje commita
    automatycznie, dopóki nie wpięty w hook/CI (świadomy kompromis: zero zależności,
    zero kosztu).
  - Promienie poboczne (8/10/20 px) i odstępy (`EdgeInsets`) celowo nie są
    tokenizowane (niski zysk, duży szum) — mogą lekko dryfować.

## Rozważane alternatywy

- **Plugin analizatora (`custom_lint`)** — odrzucony na ten etap: nowa zależność
  dev i więcej konfiguracji; skrypt grep daje 90% efektu przy zerowym koszcie.
- **Tylko reguła w docs (bez automatu)** — odrzucona: egzekwowanie ręczne zawodzi,
  dług wraca.
- **Pełna tokenizacja odstępów (`AppSpacing`)** — odłożona: duża liczba edycji i
  ryzyko regresji layoutu nieproporcjonalne do zysku.
