# Session Handoff — Faza 1 MVP: implementacja

Data: 2026-03-26
Commit: Faza 1 MVP: modele, storage, ekrany, Ledger Glass theme

## Kontekst

Pierwsza sesja implementacyjna. Zbudowalismy cala Faze 1 MVP od zera:
scaffolding struktury katalogow, wszystkie warstwy aplikacji (models → services → controllers → screens),
Ledger Glass theme i pierwszy dzialajacy debug APK.

## Co zrobiono

- Dodano zaleznosci: `hive_flutter`, `provider`, `uuid`, `intl`, `shared_preferences`, `path_provider`, `logging`
- Stworzono modele: `Subscription` (z `monthlyAmount`, `isGhost`, `costPerUse`), `Category` (8 predefiniowanych), `UsageEvent`
- Stworzono serwisy: `StorageService` (Hive JSON + cache), `ThemeProvider`, `AppLogger` (circular buffer)
- Stworzono `SubscriptionController` (CRUD + usage log + sort/filter + ghost/pin)
- Zaimplementowano `AppTheme` / `AppColors` wg Ledger Glass design system (Light + Dark Mode)
- Zbudowano 4 ekrany: Dashboard (total + breakdown + ghost alert), Lista (filtry kategorii + akcje), Dodaj/Edytuj, Ustawienia (motyw + waluta)
- `SubscriptionCard` z quick-log, ghost badge, renewal warning
- `dart analyze` → No issues found; `flutter build apk --debug` → sukces
- Zaktualizowano `README.md` i `docs/roadmap.md` (Faza 1 = ukonczona)

## Decyzje

- Hive JSON bez type adapters (zero code-gen) — patrz [ADR-001](../adr/ADR-001-hive-json-bez-code-gen.md)
- Provider + ChangeNotifier zamiast Riverpod/Bloc — wystarczajacy dla MVP, konsekwentny z APPteczka
- `RadioGroup` + `DropdownButtonFormField.initialValue` — nowe Flutter 3.32+/3.33+ API

## Otwarte kwestie

- Faza 1b (nie zaimplementowane w tej sesji): Quick Add templates, Backup (AES-256-GCM), OTA updates, deploy_apk.ps1
- Faza 2: fl_chart, AnalyticsService, PDF export, multi-waluta
- Test na fizycznym urzadzeniu (sprawdzic Hive path na Androidzie)
- `_categoryIcon()` w `subscription_card.dart` — switch na stringach, zamienic na const Map w Fazie 2
