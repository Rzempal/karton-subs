# Ledger Glass -- Design System

> **Powiazane:** [Architektura](architecture.md) | [Baza Danych](database.md) |
> [Design Review](standards/design-review.md)

---

## Filozofia

**"Gestosc danych bez wizualnego chaosu."**

Ledger Glass laczy precyzje ksiegowych ledgerow z przejrzystoscia szkla. Kazdy piksel sluzy informacji.
Bloomberg Terminal meets Material Design 3.

### Dlaczego nie neumorfizm

Neumorfizm jest dekoracyjny -- buduje hierarchie przez glebokosc cieni. Aplikacja finansowa wymaga:

- **Hierarchii przez kolor i whitespace** -- liczby musza byc czytelne natychmiast
- **Gestosc danych** -- kompaktowe tabele, wykresy, breakdowny wydatkow
- **Kolor jako znaczenie** -- zielony/czerwony/amber to uniwersalny jezyk finansow
- **Zero custom widgetow** -- M3 native redukuje maintenance do zera

### Zasady projektowe

| Zasada | Realizacja |
|--------|------------|
| Flat surfaces | 1px border zamiast cieni (separacja bez dekoracji) |
| Tabular figures | Monospaced cyfry dla wyrownania kwot w kolumnach |
| Kolor = znaczenie | Zielony (oszczednosc), czerwony (przekroczenie), amber (ostrzezenie) |
| Wysoka gestosc | 12px padding w kartach danych, tight spacing wewnatrz blokow |
| Precyzja geometryczna | Symetryczne radii, zero organic shapes |
| M3 native | Wbudowane komponenty Flutter, zero custom decoration |

---

## Paleta kolorystyczna

### Light Mode: "Clean Ledger"

Chlodna, neutralna paleta ewokujaca czysta ksiegowosc. Bez cieplych tonow (to nie apteczka).

| Token | HEX | RGB | Opis |
|-------|-----|-----|------|
| `--bg-app` | `#FAFAFA` | 250, 250, 250 | Tlo aplikacji -- chlodny neutral |
| `--surface` | `#FFFFFF` | 255, 255, 255 | Powierzchnia kart -- pure white |
| `--primary` | `#1B2A4A` | 27, 42, 74 | Deep Navy -- autorytet, zaufanie, stabilnosc |
| `--secondary` | `#3D6B9E` | 61, 107, 158 | Steel Blue -- akcje drugorzedne, linki |
| `--accent` | `#2563EB` | 37, 99, 235 | Bright Blue 600 -- CTA, aktywne stany |
| `--text-primary` | `#0F172A` | 15, 23, 42 | Slate near-black -- glowny tekst |
| `--text-secondary` | `#64748B` | 100, 116, 139 | Slate-500 -- opisy, etykiety |
| `--border` | `#E2E8F0` | 226, 232, 240 | Slate-200 -- obramowania kart, separatory |
| `--input-bg` | `#F8FAFC` | 248, 250, 252 | Slate-50 -- tlo pol formularzy |
| `--divider` | `#CBD5E1` | 203, 213, 225 | Slate-300 -- linie oddzielajace |

#### Kolory semantyczne (Light)

| Token | HEX | Cel |
|-------|-----|-----|
| `--positive` | `#16A34A` | Green-600 -- oszczednosci, pod budzetem |
| `--positive-bg` | `#F0FDF4` | Green-50 -- tlo kart pozytywnych |
| `--negative` | `#DC2626` | Red-600 -- przekroczenia, ghost subscriptions |
| `--negative-bg` | `#FEF2F2` | Red-50 -- tlo kart negatywnych |
| `--warning` | `#D97706` | Amber-600 -- zblizajace sie odnowienie |
| `--warning-bg` | `#FFFBEB` | Amber-50 -- tlo kart ostrzezeniowych |

#### Kolory wykresow (Light)

| Token | HEX | Nazwa | Uzycie |
|-------|-----|-------|--------|
| `--chart-1` | `#2563EB` | Blue-600 | Glowna seria |
| `--chart-2` | `#7C3AED` | Violet-600 | Drugorzedna seria |
| `--chart-3` | `#0891B2` | Cyan-600 | Trzeciorzedna seria |
| `--chart-4` | `#EA580C` | Orange-600 | Czwarta seria |
| `--chart-5` | `#16A34A` | Green-600 | Piata seria |
| `--chart-6` | `#DB2777` | Pink-600 | Szosta seria |

### Dark Mode: "Midnight Terminal"

Ciemna paleta z blue undertone -- precyzyjna, techniczna, bez zmeczenia oczu.

| Token | HEX | RGB | Opis |
|-------|-----|-----|------|
| `--bg-app` | `#0F1419` | 15, 20, 25 | Near-black z blue undertone |
| `--surface` | `#1A2332` | 26, 35, 50 | Karty -- dark blue-gray |
| `--primary` | `#93C5FD` | 147, 197, 253 | Light Blue-300 -- czytelny na ciemnym |
| `--secondary` | `#60A5FA` | 96, 165, 250 | Blue-400 |
| `--accent` | `#3B82F6` | 59, 130, 246 | Blue-500 -- CTA |
| `--text-primary` | `#F1F5F9` | 241, 245, 249 | Slate-100 |
| `--text-secondary` | `#94A3B8` | 148, 163, 184 | Slate-400 |
| `--border` | `#1E3A5F` | 30, 58, 95 | Ciemny blue border |
| `--input-bg` | `#0D1520` | 13, 21, 32 | Glebszy niz surface |
| `--divider` | `#1E3A5F` | 30, 58, 95 | Jak border |

#### Kolory semantyczne (Dark)

| Token | HEX | Cel |
|-------|-----|-----|
| `--positive` | `#4ADE80` | Green-400 |
| `--positive-bg` | `#052E16` | Green-950 |
| `--negative` | `#F87171` | Red-400 |
| `--negative-bg` | `#450A0A` | Red-950 |
| `--warning` | `#FBBF24` | Amber-400 |
| `--warning-bg` | `#451A03` | Amber-950 |

#### Kolory wykresow (Dark)

Jasniejsze warianty dla czytelnosci na ciemnym tle:

| Token | HEX |
|-------|-----|
| `--chart-1` | `#60A5FA` (Blue-400) |
| `--chart-2` | `#A78BFA` (Violet-400) |
| `--chart-3` | `#22D3EE` (Cyan-400) |
| `--chart-4` | `#FB923C` (Orange-400) |
| `--chart-5` | `#4ADE80` (Green-400) |
| `--chart-6` | `#F472B6` (Pink-400) |

---

## Typografia

### Fontfeatures

**Kluczowe:** Kwoty finansowe uzywaja tabular figures -- monospaced cyfry dla wyrownania w kolumnach.

```dart
// Styl dla kwot finansowych
TextStyle amountStyle = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
  fontWeight: FontWeight.w700,
  fontSize: 24,
);

// Styl dla kwot w tabelach
TextStyle tableAmountStyle = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
  fontWeight: FontWeight.w600,
  fontSize: 14,
);
```

### Hierarchia typograficzna

| Rola | Rozmiar | Waga | Uzycie |
|------|---------|------|--------|
| Display Large | 32px | 700 | Laczny koszt miesieczny (glowna cyfra) |
| Headline | 20px | 600 | Naglowki sekcji |
| Title | 16px | 600 | Nazwy subskrypcji na kartach |
| Body | 14px | 400 | Opisy, etykiety |
| Label | 12px | 500 | Chipy, meta-dane, daty |
| Caption | 11px | 400 | Podpisy wykresow, footnotes |

### Formatowanie kwot

```dart
// Format: "487,50 PLN/mies."
// Duza kwota: "487,50" (Display Large, --text-primary)
// Waluta + okres: "PLN/mies." (Body, --text-secondary)
```

---

## Geometria i Layout

### Border Radius

| Element | Radius | Uzasadnienie |
|---------|--------|-------------|
| Karty (standard) | 12px | Czyste, nowoczesne, nie za okragle |
| Chipy, tagi | 8px | Kompaktowe elementy |
| Bottom sheets, dialogi | 16px (gora) | M3 standard |
| Przyciski | 12px | Spojnosc z kartami |
| Pola tekstowe | 8px | Nieco ostrzejsze niz karty |

**Zero asymetrycznych radii.** Finanse = precyzja geometryczna.

### Spacing (8px Grid)

| Token | Wartosc | Uzycie |
|-------|---------|--------|
| `xs` | 4px | Wewnatrz chipow, gap ikon |
| `sm` | 8px | Padding wewnatrz kompaktowych kart |
| `md` | 12px | Padding kart danych |
| `base` | 16px | Standardowy padding sekcji |
| `lg` | 24px | Odstep miedzy sekcjami |
| `xl` | 32px | Odstep miedzy blokami ekranu |

### Karty

```dart
// Karta subskrypcji -- flat + border
Card(
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(
      color: theme.colorScheme.outline.withOpacity(0.2),
      width: 1,
    ),
  ),
  child: Padding(
    padding: EdgeInsets.all(12), // 12px -- gestosc danych
    child: ...
  ),
)
```

---

## Mapowanie komponentow na M3

### Strategia: zero custom widgetow na poziomie design systemu

| Komponent | Implementacja M3 | Uwagi |
|-----------|-------------------|-------|
| Karty | `Card` (outlined variant) | `elevation: 0`, `side: BorderSide(1px)` |
| Przyciski glowne | `FilledButton` | Deep Navy bg, white text |
| Przyciski drugorzedne | `OutlinedButton` | Border color = `--secondary` |
| Nawigacja dolna | `NavigationBar` | 3-4 destinacji: Dashboard, Dodaj, Subskrypcje, Ustawienia |
| Filtry kategorii | `FilterChip` | M3 native |
| Wybor okresu | `SegmentedButton` | Mies/Rok/Tydzien toggle |
| Pola tekstowe | `TextField` + `OutlineInputBorder` | 8px radius |
| Bottom sheets | `showModalBottomSheet` | M3 z `DragHandle` |
| Dialogi | `AlertDialog` | M3 native |
| Chipy statusu | `Badge` lub custom `Container` | Kolorowanie semantyczne |
| Date picker | `showDatePicker` | M3 native |
| Snackbary | `SnackBar` | Feedback uzytkownika |

### Custom widgety (tylko logika domenowa)

| Widget | Cel | Nie jest czescia design systemu |
|--------|-----|-------------------------------|
| `SubscriptionCard` | Karta subskrypcji z kwota, ikona, status | Logika domenowa |
| `SpendingChart` | Wykres wydatkow (fl_chart) | Wizualizacja danych |
| `CategoryBreakdown` | Podzial na kategorie (bar/pie) | Wizualizacja danych |
| `BudgetProgressBar` | Pasek postępu budżetu | Logika domenowa |
| `GhostAlert` | Alert "placisz ale nie korzystasz" | Logika domenowa |

---

## Stany kart subskrypcji

Karty uzywaja kolorow semantycznych do komunikowania statusu:

| Stan | Tlo Light | Tlo Dark | Border | Ikona |
|------|-----------|----------|--------|-------|
| Aktywna (OK) | `--surface` | `--surface` | `--border` | -- |
| Odnowienie wkrotce | `--warning-bg` | `--warning-bg` | `--warning` 20% | Timer |
| Ghost (nieuzywana) | `--negative-bg` | `--negative-bg` | `--negative` 20% | Alert |
| Anulowana | `--surface` 60% opacity | `--surface` 60% opacity | `--border` dashed | Strikethrough |

---

## Ikony

Lucide Icons (`lucide_icons_flutter`) -- ten sam zestaw co w APPteczka.

| Kontekst | Ikona | Nazwa Lucide |
|----------|-------|-------------|
| Subskrypcja | Powtarzajacy sie symbol | `repeat` |
| Dodaj | Plus | `plus` |
| Dashboard | Wykres | `bar-chart-3` |
| Ustawienia | Zebatka | `settings` |
| Odnowienie | Zegar | `clock` |
| Ostrzezenie | Trojkat | `alert-triangle` |
| Ghost alert | Duch / Banknot | `banknote` lub `ghost` |
| Kategoria: Streaming | Play | `play-circle` |
| Kategoria: Cloud | Chmura | `cloud` |
| Kategoria: Muzyka | Sluchawki | `headphones` |
| Kategoria: Fitness | Silownia | `dumbbell` |
| Kategoria: Software | Kod | `code` |
| Kategoria: Inne | Folder | `folder` |

---

## Dostepnosc (WCAG 2.1)

| Aspekt | Realizacja |
|--------|-----------|
| Kontrast tekstu | Min 4.5:1 (AA). Deep Navy na bialym = 12:1 |
| Kontrast w Dark Mode | Slate-100 na surface = 11:1 |
| Kolory semantyczne | Nigdy sam kolor -- zawsze ikona + label |
| Focus states | Border accent (2px) na :focus |
| Touch targets | Min 48x48dp (M3 standard) |
| Screen reader | Wszystkie kwoty z semantycznym opisem ("Netflix, 49 zlotych miesiecznie") |

---

## Animacje i UX

| Interakcja | Animacja | Czas |
|------------|----------|------|
| Przejscie miedzy tabami | `PageTransitionSwitcher` | 300ms |
| Zmiana filtrow | `AnimatedContainer` | 200ms |
| Ladowanie danych | Skeleton shimmer | -- |
| Dodanie subskrypcji | Slide in from bottom | 250ms |
| Usuniecie | Slide out + fade | 200ms |
| Feedback taktylny | `HapticFeedback.lightImpact()` | Natychmiastowy |

---

## Porownanie z APPteczka (co sie zmienilo)

| Aspekt | APPteczka (Neumorphism) | Karton na subskrypcje (Ledger Glass) |
|--------|------------------------|--------------------------------------|
| Filozofia | Glebokosc i dotykalnosc | Gestosc danych i precyzja |
| Cienie | Dual shadows (light + dark) | Zero cieni, 1px border |
| Radii | Asymetryczne (50/50/20/80) | Symetryczne (12/8/16) |
| Kolory primary | Smoky Green / Neon Mint | Deep Navy / Light Blue |
| Kolory bg | Bone White / Deep Indigo | Cool Neutral / Near-black |
| Custom widgets | 9 neumorficznych komponentow | Zero (M3 native) |
| Ikony | Lucide | Lucide (bez zmian) |
| Grid | 8px | 8px (bez zmian) |
| Padding kart | 16px | 12px (gestosc danych) |
| Accessibility | Outline kompensacja | Natywny kontrast M3 |

---

## Implementacja w Flutter (AppColors)

```dart
class AppColors {
  // ===== LIGHT MODE: Clean Ledger =====
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1B2A4A);    // Deep Navy
  static const Color lightSecondary = Color(0xFF3D6B9E);   // Steel Blue
  static const Color lightAccent = Color(0xFF2563EB);      // Bright Blue
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightInputBg = Color(0xFFF8FAFC);

  // Semantyczne (Light)
  static const Color lightPositive = Color(0xFF16A34A);
  static const Color lightPositiveBg = Color(0xFFF0FDF4);
  static const Color lightNegative = Color(0xFFDC2626);
  static const Color lightNegativeBg = Color(0xFFFEF2F2);
  static const Color lightWarning = Color(0xFFD97706);
  static const Color lightWarningBg = Color(0xFFFFFBEB);

  // Wykresy (Light)
  static const List<Color> lightChartColors = [
    Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF0891B2),
    Color(0xFFEA580C), Color(0xFF16A34A), Color(0xFFDB2777),
  ];

  // ===== DARK MODE: Midnight Terminal =====
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1A2332);
  static const Color darkPrimary = Color(0xFF93C5FD);      // Light Blue
  static const Color darkSecondary = Color(0xFF60A5FA);
  static const Color darkAccent = Color(0xFF3B82F6);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF1E3A5F);
  static const Color darkInputBg = Color(0xFF0D1520);

  // Semantyczne (Dark)
  static const Color darkPositive = Color(0xFF4ADE80);
  static const Color darkPositiveBg = Color(0xFF052E16);
  static const Color darkNegative = Color(0xFFF87171);
  static const Color darkNegativeBg = Color(0xFF450A0A);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkWarningBg = Color(0xFF451A03);

  // Wykresy (Dark)
  static const List<Color> darkChartColors = [
    Color(0xFF60A5FA), Color(0xFFA78BFA), Color(0xFF22D3EE),
    Color(0xFFFB923C), Color(0xFF4ADE80), Color(0xFFF472B6),
  ];
}
```

---

## Semantic Color Tokens (`AppSemanticColors`)

> **ADR:** [ADR-002 Semantic Color Tokens](adr/ADR-002-semantic-color-tokens.md)

Od wersji 0.2 kolory statusowe i kontekstowe sa dostarczane przez `ThemeExtension<AppSemanticColors>`,
co eliminuje reczne sprawdzanie `isDark` w widgetach. Dostep: `context.semanticColors`.

| Token | Light | Dark | Uzycie |
|-------|-------|------|--------|
| `positive` / `positiveBg` | Green-600 / `#F0FDF4` | Green-400 / Green@10% | Sukces, aktualna apka |
| `negative` / `negativeBg` | Red-600 / `#FEF2F2` | Red-400 / Red@10% | Bledy, ghost alert |
| `warning` / `warningBg` | Amber-600 / `#FFFBEB` | Amber-400 / Amber@10% | Odnowienie, trial expiring |
| `trial` / `trialBg` | Blue-600 / `#EFF6FF` | Blue-400 / Blue@10% | Free trial |
| `heroCardBg/Text` | Deep Navy / white | Primary@15% / Slate-100 | Glowna karta summary |
| `textPrimary/Secondary/Muted` | Slate-900/500/400 | Slate-100/400/500 | Hierarchia tekstu |

Dark mode: statusowe foregroundy jasniejsze (shade 400 vs 600), tla = kolor@10% opacity.

---

> **Ostatnia aktualizacja:** 2026-04-05
