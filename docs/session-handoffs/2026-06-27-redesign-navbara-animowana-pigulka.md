# Session Handoff — Redesign navbara: animowana pigulka aktywnej zakladki

Data: 2026-06-27
Commit: Redesign navbara animowana pigulka aktywnej zakladki i separator Ustawien

## Kontekst

Poprawa wygladu dolnego paska nawigacji (`GlassNavBar`) na wzor zalaczonych mockupow:
aktywna zakladka ma rozsuwac sie w pozioma pigulke z etykieta, reszta to same ikony.
Zmiana czysto wizualna jednego widgetu prezentacyjnego — bez wplywu na logike.

## Co zrobiono

- **`_NavCell` → pozioma animowana pigulka** (`glass_nav_bar.dart`): nieaktywna zakladka =
  sama ikona (`textSecondary`); aktywna = ikona + etykieta poziomo w kolorze `accentSolid`,
  na tincie akcentu @0.16 (subtelne „elevowane" tlo). Etykieta rozsuwa/zwija sie przez
  `ClipRect` + `AnimatedSize` (220 ms, `easeOutCubic`). Tekst w `ConstrainedBox(maxWidth:140)`
  + `ellipsis` — zabezpieczenie przed dlugimi etykietami PL.
- **Separator** (`_NavDivider`): pionowy hairline przed ostatnia pozycja (Ustawienia),
  oddziela ja od trojki funkcyjnej. Logika ogolna (`_dividerBefore = items.length - 1`).
- Usunieto nieuzywany `_activeText` (stary gradient-fill aktywnej zakladki).
- Dokumentacja: `docs/design.md` — opis navbara (sekcja Wspolne) + korekta tokenu
  `--accent-gradient` (nie jest juz uzywany w navbarze).
- Weryfikacja: `flutter analyze` czysty; dev deploy v0.10.26062700 (kanal internal),
  potwierdzony wizualnie na urzadzeniu przez wlasciciela.

## Decyzje

- **Styl aktywnej zakladki = „jak w mockupie"** (tint akcentu + tekst akcentu), a nie dawne
  wypelnienie gradientem z ciemnym tekstem. Swiadome odejscie od poprzedniej konwencji
  na zyczenie wlasciciela. Tint @0.16 to jeden token dzialajacy na wszystkich motywach
  (ciemny/jasny/mono/Material You).
- **Separator tylko przed Ustawieniami** — podzial funkcje vs ustawienia jest sensowny;
  separatory miedzy funkcjami byly by sztuczne.
- **Bez ADR** — zmiana wizualna jednego widgetu, brak zmian architektury, technologii ani
  konwencji projektowej.

## Otwarte kwestie

- Brak.
