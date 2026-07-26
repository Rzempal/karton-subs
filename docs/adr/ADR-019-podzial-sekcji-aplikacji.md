# ADR-019: Podział sekcji aplikacji — nazwy i właściciele tematów

Data: 2026-07-26
Status: zaakceptowany (wdrażany etapami)

## Kontekst

Nazwy zakładek rozjechały się ze znaczeniem:

- **„Dashboard"** — nazwa techniczna, a ekran jest przeglądem całego budżetu.
- **„Budżet"** — nazwa całej domeny na ekranie, który jest tylko *zarządzaniem
  pozycjami*. Skoro „Dashboard" pokazuje budżet, „Budżet" musiał znaczyć coś węższego.
- **Wpływy** siedziały w jednym worku z wydatkami, choć to przeciwna strona bilansu.
- **Koperta „Na rachunki"** (rezerwa planu na pulę rachunków) była edytowana na ekranie
  „Budżet", a realizowana i porównywana z rzeczywistością na ekranie „Rachunki" — temat
  rozdarty między dwa ekrany.

Osobno rozważany wariant z **szóstą zakładką „Wpływy"** został odrzucony: pasek
nawigacji ma 5 pozycji z podpisami w pływającej pigułce, a wpływy to 2–3 pozycje
ruszane raz na kwartał. Dostałyby najdroższą powierzchnię w aplikacji za najrzadsze
użycie.

## Decyzja

Pięć zakładek zostaje. Zmieniają się nazwy i właściciele tematów:

| Zakładka | Znaczenie |
|---|---|
| **Budżet** (dawny „Dashboard") | Przegląd całości: bilans miesiąca, płatności, podsumowanie, plan |
| **Rachunki** | Datowane wydatki jednorazowe (ADR-018) + **koperta „Na rachunki"** + skan AI |
| **Subskrypcje** | Bez zmian — świadomie oddzielone od kosztów stałych (koszty uznaniowe) |
| **Wydatki cykliczne** (dawny „Budżet") | Pozycje planowalne: koszty stałe, raty, przelew do domowego. Pod-zakładka **Wpływy** |
| **Ustawienia** | Bez zmian |

### 1. Koperta „Na rachunki" należy do Rachunków

Skład koperty i jej edycja przenoszą się na ekran „Rachunki" — tam, gdzie widać realne
rachunki tej samej puli i porównanie plan/rzeczywistość. Na ekranie wydatków zostaje
**sam wiersz z sumą** (bez edycji), bo rezerwa nadal pomniejsza „zostaje/mies" i suma
planu musi się tłumaczyć. Kod edytora wyprowadzony do `widgets/bills_allocation_editor.dart`,
żeby nie duplikować go między ekranami.

### 2. Wpływy jako pod-zakładka, nie szósta zakładka

Wzorzec już obecny w aplikacji (Dashboard: Bilans/Plan, Subskrypcje: Lista/Statystyki).
Pełna separacja wizualna, jedno przesunięcie palcem, zero kosztu w nawigacji.

### 3. Nazwy tylko w UI

`BudgetController`, `BudgetScope`, `BudgetEntry` itd. zostają bez zmian — „budget" jest
poprawną nazwą **domeny danych**, a myląca była wyłącznie etykieta zakładki. Refaktor
nazw w kodzie byłby ryzykiem bez zysku.

## Konsekwencje

- (+) Każdy temat ma jednego właściciela: rachunki (z ich rezerwą), koszty cykliczne,
  wpływy, subskrypcje, przegląd.
- (+) Nazwa „Wydatki cykliczne" jest prawdziwa dopiero po ADR-018 (datowane jednorazowe
  wyszły do Rachunków) — te dwie decyzje są ze sobą sprzęgnięte.
- (−) Zmiana nazw łamie pamięć mięśniową; jednorazowy koszt przy jednym użytkowniku.
- (−) Ekran „Rachunki" robi się gęsty (rachunki + koperta + skan) — jeśli zacznie
  przytłaczać, następnym krokiem są tam pod-zakładki, nie rozdzielanie tematu.

## Etapy wdrożenia

1. Scalenie typów — [ADR-018](ADR-018-scalenie-wydatku-jednorazowego-z-rachunkiem.md). ✅
2. Koperta „Na rachunki" → ekran Rachunki (wiersz sumy zostaje w wydatkach). ✅
3. Nazwy zakładek + pod-zakładka Wpływy.
4. Osobno, poza tym ADR: rozszerzenie cykli (co N miesięcy, konkretne miesiące roku).
