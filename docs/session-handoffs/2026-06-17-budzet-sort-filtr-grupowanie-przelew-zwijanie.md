# Session Handoff — budzet: sortowanie/filtr/grupowanie, przelew, zwijanie Dashboardu

Data: 2026-06-17
Commit: Budzet sortowanie filtr grupowanie, sekcja przelewu wewnetrznego z korekta, sumy sekcji, zwijanie Dashboardu

## Kontekst

Rozbudowa ekranu Budzet o sortowanie, filtrowanie i grupowanie pozycji,
wydzielenie przelewu do domowego do osobnej sekcji z korekta kwoty, sumy w
naglowkach sekcji oraz zwijanie kalendarza i listy platnosci na Dashboardzie.

## Co zrobiono

- **Sortowanie** (A→Z / kwota malejaco) — ikona-przelacznik w AppBar (`arrow-down-a-z` / `arrow-down-1-0`).
- **Filtr typu pozycji** — pasek chipow pod filtrem kategorii; etykiety „Wszystkie typy" / „Wszystkie kategorie".
- **Grupowanie** wg typu — ikona wł/wył; pod-naglowki tylko w kubelkach z wieloma typami.
- **Sekcja „Przelew wewnetrzny"** — `householdTransfer` wydzielony z „Koszty cykliczne" (getter `internalTransfers`).
- **Korekta przelewu** — `monthOverrides` dla `householdTransfer`; kaskada do lustra w domowym; silnik liczy `overrideDeltaForMonth` ze znakiem (wplyw +, wydatek −).
- **Sumy sekcji** — naglowek z suma pozycji (po filtrach), znormalizowana przez cykl (jednorazowe pelna kwota), wyrownana do prawej.
- **Zwijanie Dashboardu** — kalendarz (nowy naglowek: ikona + nawigacja po srodku + chevron) i lista Platnosci full/kompakt, stan trwaly.
- Excel: korekty przelewu round-trip; rozpoznanie typu „Przelew".
- Testy: korekta przelewu (wydatek −) i lustra (wplyw +). Razem 70/70.
- Docs: `database.md`, `roadmap.md` (Faza 5g), `ADR-008` (aktualizacja 2).

## Decyzje

- Korekta przelewu kaskaduje do lustra (pelna spojnosc budzetu domowego); delta korekt uogolniona ze znakiem — patrz [ADR-008](../adr/ADR-008-rachunek-zmienny-surplus-vs-bilans.md).
- Sumy sekcji znormalizowane przez cykl (kwota/mies), jednorazowe pelna kwota.
- Grupowanie pomija pod-naglowki w kubelkach jednotypowych (mniej szumu).

## Otwarte kwestie

- Import przelewu z Excela nie odtwarza lustra w domowym (pelny transfer tylko przez backup) — znane ograniczenie.
