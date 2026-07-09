# Session Handoff — Dashboard: podsumowanie miesiaca, platnosci automatyczne, sync w UI, fix animacji

Data: 2026-07-09
Commit: Dashboard podsumowanie miesiaca i platnosci automatyczne, sync w UI, ikona cloud-sync, fix animacji przejsc ekranow

## Kontekst

Sesja „Dashboard update" — rozbudowa Dashboardu (podsumowanie miesiaca w kalendarzu,
druga sekcja platnosci, dynamiczne sumy), wyeksponowanie synchronizacji budzetu domowego
w UI oraz naprawa dwoch bledow zglaszanych na urzadzeniu (mylacy komunikat sync, „duch"
tresci przy animacji powrotu). Przy okazji: obudzenie i przygotowanie do wspoldzielenia
projektu Supabase, plan portu synchronizacji do APPteczki.

## Co zrobiono

- **Podsumowanie miesiaca (kalendarz):** ikona listy przy „Bilans miesiaca" otwiera bottom
  sheet „Podsumowanie · miesiac" — pelne listy wplywow i wydatkow z kalendarza przeplywow
  (sortowane wg dnia, sumy sekcji, kwoty realne po korektach). `budget_widgets.dart`.
- **Sekcja „Platnosci automatyczne":** `PaymentsSection` sparametryzowana flaga `automatic`
  (manual = dawne „Platnosci", auto = nowa sekcja); jedna implementacja, dwie karty. Odstepy
  renderowane tylko gdy sekcja ma pozycje (`PaymentsSection.hasAny`). `storage_service.dart`
  — trwale zwijanie nowej sekcji.
- **Dynamiczna suma pozostala:** obie sekcje platnosci pokazuja „Pozostalo do rozliczenia"
  (suma nieodhaczonych, maleje przy odhaczaniu; po odhaczeniu wszystkiego → zielone
  „Wszystko rozliczone"); widoczne tez po zwinieciu listy.
- **Sync budzetu domowego w UI:** nowy `widgets/sync_now_button.dart` — przycisk w AppBarze
  Dashboardu i Budzetu (widoczny tylko po sparowaniu, spinner w trakcie, snackbar z wynikiem).
  Komunikaty wyniku sync wydzielone do wspolnego miejsca (byly zaszyte w ekranie ustawien).
- **Ikona cloud-sync:** dodano pakiet `lucide_icons_flutter` (alias) — ikona `cloudSync`
  zamiast kolowych strzalek (odroznienie od „Aktualizacji" OTA). Uzyta w AppBarach i na
  ekranie „Synchronizacja domowego".
- **Lepszy komunikat sync offline:** „Serwer synchronizacji nie odpowiada…" zamiast mylacego
  „Brak polaczenia" (uspiony projekt Supabase != brak internetu).
- **Fix animacji „ducha":** tlo Aurora montowane RAZ w `MaterialApp.builder` (usuniete z 10
  ekranow) + przejscia tras `FadeThroughPageTransitionsBuilder` (pakiet `animations`,
  `fillColor` transparent). Patrz lessons-learned 2026-07-09.
- **Supabase:** obudzono uspiony projekt relay (`restore_project`); ustalono wspoldzielenie
  z APPteczka (rename `karton-subs-sync` → `karton`, rename po stronie usera w dashboardzie).
- **Plan portu sync do APPteczki:** utworzono `C:\Users\rzemp\GitHub\APPteczka\docs\synchronization.md`
  (osobne repo) — pelny plan implementacji E2E sync apteczki wg wzorca ADR-009.
- **Dokumentacja:** `design.md` (podsumowanie miesiaca, regula AuroraBackground + fade-through),
  `architecture.md` (AuroraBackground w builderze), lessons-learned (bug animacji).
- **Weryfikacja:** `flutter analyze` czysty, 115/115 testow; kolejne dev deploye (internal)
  potwierdzane wizualnie na urzadzeniu przez wlasciciela (ostatnia wersja v0.10.26070900).

## Decyzje

- **Kwoty w podsumowaniu miesiaca = realne platnosci** (po korektach, z jednorazowymi), nie
  usrednione — lista pokazuje, co faktycznie schodzi z konta; suma moze roznic sie od bilansu
  (ktory usrednia koszty cykliczne). Czytelnie opisane w naglowku arkusza.
- **Tlo aplikacji montowane raz + fade-through** zamiast tla per ekran i domyslnego zoom —
  doprecyzowanie systemu Aurora (ADR-005/010). BEZ osobnego ADR: regula zapisana w `design.md`,
  docstringu `aurora_background.dart` i lessons-learned (trzy miejsca wystarcza).
- **Projekt Supabase `karton` wspoldzielony** miedzy budzetem a apteczka — kazda appka wlasna
  tabela + RPC (izolacja). Szczegoly w `APPteczka/docs/synchronization.md` (ADR powstanie tam).
- **Drugi pakiet ikon (`lucide_icons_flutter`)** tylko dla `cloudSync` — tree-shaking wycina
  nieuzywane glify, wiec koszt w rozmiarze APK pomijalny.

## Otwarte kwestie

- **Uspienie Supabase (free tier):** projekt `karton` usypia po ~7 dniach bez ruchu i NIE
  budzi sie sam — objaw to „Serwer nie odpowiada". Budzenie: MCP `restore_project`
  (id `yhcowgjxhbiyeraqdpor`). Opcjonalny cotygodniowy ping jako proteza (nie wdrozono).
- **Rename projektu Supabase** na `karton` — do zrobienia przez wlasciciela w dashboardzie
  (Settings → General); adres/klucze/dane bez zmian.
- **Port sync do APPteczki** — plan gotowy (`APPteczka/docs/synchronization.md`), realizacja
  w osobnej sesji w repo APPteczka.
- **Bug animacji „ducha" do przeniesienia do APPteczki** — prompt przekazany wlascicielowi
  (ta sama estetyka = ten sam bug).
