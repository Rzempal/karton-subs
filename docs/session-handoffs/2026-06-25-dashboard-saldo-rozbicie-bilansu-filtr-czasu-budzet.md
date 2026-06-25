# Session Handoff — Dashboard: karta Saldo, rozbicie bilansu, filtr czasu w Budzecie

Data: 2026-06-25
Commit: Dashboard karta Saldo, rozbicie bilansu i filtr czasu w Budzecie

## Kontekst

Poprawa czytelnosci Dashboardu (sekcja „zostaje miesiecznie") i dodanie dwoch nowych
funkcji budzetowych: rozbicia roznicy bilans−saldo oraz filtrowania pozycji po czasie
w zakladce Budzet. Wydane na PROD (v0.10.26062500).

## Co zrobiono

- **Karta „Saldo: zostaje miesiecznie"** — scalono trojke kafelek (hero + Wplywy + Koszty)
  w jedna karte. Kwota + linia wplywy/koszty zawsze widoczne; tap rozwija/zwija opis
  „jak liczone jest saldo" + przypis subskrypcji. Usunieto osierocony `BudgetFlowCard`.
- **Opis bilansu miesiaca** — zamiast ogolnika nowy tekst wspominajacy korekty + podpowiedz
  gestu.
- **Rozbicie bilansu (bottom sheet)** — przytrzymanie kwoty bilansu otwiera sheet z pozycjami,
  ktore roznia bilans od salda: jednorazowe wplywy/wydatki, korekty kwot, korekty rat
  (grupy z naglowkami, kwoty ze znakiem). Silnik: `BudgetService.balanceBreakdownForMonth`
  (suma delt = `balanceForMonth − monthlySurplus`, pilnowane testem).
- **Filtr czasu w Budzecie** — pasek lat, po wybraniu roku pasek miesiecy. Snapshot miesiaca:
  cykliczne zawsze, jednorazowe danego miesiaca, raty w oknie splaty. Logika: nowy
  `BudgetEntry.appliesToMonth` (przetestowany). Pasek widoczny tylko gdy sa pozycje
  jednorazowe lub raty.
- Testy: +3 (rozbicie bilansu), +3 (appliesToMonth). Calosc: analyze czysto, 115 testow zielonych.
- Dokumentacja: `docs/design.md` (Dashboard + Budzet), `docs/architecture.md` (model czasu).

## Decyzje

- **Filtr czasu = pelny snapshot miesiaca** (cykliczne + jednorazowe + raty), a nie tylko
  filtr pozycji jednorazowych. Swiadomie, na zyczenie wlasciciela — mimo ze czesciowo
  dubluje widok miesiaca z Dashboardu. Reguly przynaleznosci w `appliesToMonth`.
- **Granularnosc rok → miesiac** zamiast plaskiej listy miesiecy — skaluje sie, gdy
  jednorazowych przybywa przez lata.
- **Bez nowego ADR** — funkcje sa derywacja istniejacego modelu czasu (ADR-008); brak
  zmian architektury, technologii ani konwencji.
- **Kolejnosc wydania:** deploy PROD bez `-CreateTag` (bo tag tworzy sie na biezacym HEAD,
  jeszcze przed commitem zmian), nastepnie commit+push, na koncu tag na commicie wydania.

## Otwarte kwestie

- Brak.
