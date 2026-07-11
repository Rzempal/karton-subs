# Session Handoff — Rachunki (realny log), statystyki w Planie, kompaktowe platnosci, ukrycie waluty, aktualizacje inline

Data: 2026-07-11
Commit: Rachunki realny log, statystyki w Planie, kompaktowe platnosci, ukrycie waluty domyslnej i aktualizacje inline

## Kontekst

Duza sesja „Rachunki": nowa domena realnego logu oplat (koniec miesiaca = analiza
rzeczywistych wydatkow), a nastepnie kilka rund poprawek UX na urzadzeniu (deploy dev
internal po kazdej). Poczatek prac i sam model danych opisuje tez handoff
[2026-07-09](2026-07-09-rachunki-realny-log-i-scalenie-typow.md); ten dokument zbiera
calosc do domkniecia. Decyzje modelu: [ADR-011](../adr/ADR-011-rachunki-realny-log-i-scalenie-typow-cyklicznych.md).

## Co zrobiono

### Model + silnik
- **Scalenie `bill` → `recurringCost`** (koszt cykliczny z opcjonalna korekta); `bill`
  usuniety z enuma, migracja darmowa (`fromJson orElse: recurringCost`).
- **Nowy typ `billPayment`** („Rachunek") — datowany, zasila bilans miesiaca, NIE plan.
- **Koperta „Na rachunki"** (`billsAllocation`, per zakres) — **planowany koszt**:
  pomniejsza `monthlySurplus`, a w `balanceForMonth` jest oddawana i podmieniana na
  realne rachunki (bez podwojnego liczenia; nowy `BalanceContributionKind.billsAllocation`).
- **Statystyki**: `expenseTrend`/`billsTrend` (6 mies.) + `billsBreakdownByCategory`.
- Test-straznik `billPayment` (bilans nie plan) + test koperty (surplus maleje, bilans bez zmian).

### Nawigacja + ekrany
- **5. zakladka Rachunki** (ikona `receipt-text` z `lucide_icons_flutter`); ekran =
  lista miesiaca + karta „Na rachunki" (read-only) + FAB; formularz `add_bill_payment_screen`.
- **Dashboard**: **Bilans miesiaca** to pierwsza/domyslna pod-zakladka, **Plan** druga.
  Plan = **hub statystyk** (segment Budzet / Subskrypcje / Rachunki: hero + trend +
  kategorie) + predykcja vs rzeczywisty (z przelacznikiem miesiaca wspolnym z kalendarzem).
- **Platnosci**: „Platnosci" + „Platnosci automatyczne" scalone w jedna sekcje z dwiema
  grupami rozdzielonymi separatorem; kompaktowe (jedna linia „opis: kwota"); przycisk
  „Odhacz wszystkie" tylko w wersji rozwinietej (`MonthPaymentsSection`, `setPaymentsDone`).
- **Budzet**: pozycja „Na rachunki" (edytowalna) przypieta na gorze listy wydatkow;
  przelacznik widoku szczegolowy vs scalony (Wplywy/Wydatki) — poprawka buga grupowania.
- **Subskrypcje**: sama lista (zakladka Statystyki przeniesiona do Planu jako `SubscriptionStatsView`).

### Poprawki przekrojowe
- **Ukrycie waluty domyslnej** na ekranach (`utils/money_format.dart`: globalna
  `appDefaultCurrency` + `curLabelSuffix`/`curSymbolSuffix`); etykieta tylko dla waluty
  innej niz domyslna (np. subskrypcja w EUR). Piker/eksporty/powiadomienia bez zmian.
- **Aktualizacje OTA inline** w Ustawieniach (`widgets/update_inline_section.dart`):
  wersja + status + „Sprawdz teraz" + instalacja bez osobnego ekranu; usuniety `updates_screen.dart`.

### Weryfikacja i wydania
- `flutter analyze` czysty, **122/122** testow (baza 115 → +7).
- 10 deployow dev (internal), aktualny **v0.10.26071102**; potwierdzane wizualnie na urzadzeniu.

## Decyzje

- **Rachunek = realny log (`billPayment`)**, nie przeniesiony `bill`. Patrz [ADR-011](../adr/ADR-011-rachunki-realny-log-i-scalenie-typow-cyklicznych.md).
- **Scalenie typow cyklicznych** (`bill`+`recurringCost`) — koniec duplikacji (koryguje podzial z ADR-008).
- **„Na rachunki" = planowany koszt** (pomniejsza „zostaje/mies", w bilansie podmiana na
  realne) — zmiana wzgledem pierwotnego pomyslu „osobna statystyka" (na zyczenie wlasciciela). ADR-011 pkt 3 zaktualizowany.
- **Osobisty/Domowy = pudelko (scope), nie pole** — nienaruszona granica synchronizacji (ADR-006/009).
- **Statystyki subskrypcji przeniesione do Planu** (Subskrypcje = sama lista) — jeden hub analityki.

## Otwarte kwestie

- **Do przemyslenia (wlasciciel):** czy `oneTimeExpense` (planowany jednorazowy) i
  `billPayment` (zalogowany rachunek) to duplikacja — strukturalnie tak, roznica intencyjna
  (planowany przyszly vs zalogowany). Ewentualne scalenie w przyszlosci.
- **OCR (Gemma E4B)** — kolejna iteracja: zdjecie/screenshot/PDF → auto-`billPayment`
  (miejsce na zalacznik w modelu do dodania).
- **Koperta „Na rachunki" nie jest w backupie** (spojnie z `budgetLimit`) — do rozwazenia
  dodanie, jesli ma przetrwac restore.
- **PROD:** kolejnosc deploy → commit → tag (deploy.ps1 taguje zbyt wczesnie) przy wydaniu produkcyjnym.
