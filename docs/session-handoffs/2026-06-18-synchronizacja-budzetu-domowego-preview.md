# Session Handoff — synchronizacja budzetu domowego (preview)

Data: 2026-06-18
Commit: Synchronizacja budzetu domowego (parowanie QR + haslo, relay E2E) — preview

## Kontekst

Zaprojektowano i zaimplementowano wspoldzielenie **budzetu domowego** miedzy telefonami
bez kont: parowanie kodem QR + haslo, synchronizacja przez relay w chmurze z szyfrowaniem
end-to-end. Budzety osobiste zostaja lokalne. Funkcja wydana na DEV jako **preview**
(wymaga walidacji na dwoch fizycznych urzadzeniach).

## Co zrobiono

- **Model** ([budget_entry.dart](../../apps/karton_subs/lib/models/budget_entry.dart)): dodano
  `updatedAt` (znacznik zmiany, LWW) i `deleted` (nagrobek) — addytywnie, wstecznie zgodne.
- **Kryptografia** ([sync_crypto_service.dart](../../apps/karton_subs/lib/services/sync_crypto_service.dart)):
  klucz wspolny z hasla (PBKDF2-SHA256 100k), szyfrowanie paczki AES-256-GCM (format transportowy).
- **Scalanie** ([sync_merge.dart](../../apps/karton_subs/lib/services/sync_merge.dart)):
  Last-Write-Wins per pozycja + nagrobki, deterministyczne (merge(a,b)==merge(b,a)) + snapshot.
- **Orkiestracja** ([sync_service.dart](../../apps/karton_subs/lib/services/sync_service.dart)):
  pull → scal → zapis → push z compare-and-swap (ponawia przy konflikcie); parowanie (QR codec),
  przechowywanie pary w bezpiecznym magazynie; skrot bez-zmian (anty-ping-pong).
- **Skrzynka** (Supabase `karton-subs-sync`): tabela `sync_envelopes` zamknieta RLS, dostep
  wylacznie przez funkcje RPC `sync_pull`/`sync_push` po sekretnym `household_id`.
- **UI** ([household_sync_screen.dart](../../apps/karton_subs/lib/screens/household_sync_screen.dart)):
  „Dodaj czlonka" (haslo → QR), „Dolacz" (skan → haslo), „Synchronizuj teraz", „Rozlacz";
  badge **PREVIEW** w Ustawieniach + disclaimer na ekranie.
- **Wyzwalacze** ([main.dart](../../apps/karton_subs/lib/main.dart)): sync przy starcie +
  po zmianie domowego (debounce 2s) + reczny.
- **Pakiety:** `mobile_scanner` (skan QR, uprawnienie CAMERA), `qr_flutter` (generowanie QR).
- **Testy:** +34 testy synchronizacji (crypto, merge, service, pola modelu) — razem 109, build APK OK.
- **Dokumentacja:** ADR-009, security.md (wyjatek od „zero cloud"), architecture.md, database.md,
  roadmap.md (Faza 7 = work in progress / preview), README.md.
- **Deploy:** DEV (kanal internal) v0.8.26061800.

## Decyzje

- **Relay w chmurze + E2E** zamiast P2P/pliku — jedyna opcja dajaca ciagla, automatyczna
  synchronizacje; serwer slepy na tresc. Patrz [ADR-009](../adr/ADR-009-synchronizacja-budzetu-domowego-relay-e2e.md).
- **QR niesie tylko household_id + salt; haslo poza QR** (przekazywane ustnie) — przechwycenie
  QR bez hasla nie ujawnia danych.
- **Scalanie LWW per pozycja + nagrobki** (nie CRDT) — wystarczajace dla 2-3 osob.
- **Dostep do skrzynki po sekrecie, nie po koncie** — RLS zamyka tabele, RPC SECURITY DEFINER;
  ostrzezenia advisora (anon moze wolac RPC) sa swiadome i nieuniknione w modelu bez kont.
- **Tombstone tylko dla domowego**, osobisty kasuje twardo (brak sync).

## Otwarte kwestie

- **Walidacja na dwoch fizycznych urzadzeniach** — skan QR kamera, obieg A↔B, zgoda na kamere,
  potwierdzenie ze osobisty sie NIE synchronizuje. To warunek wyjscia z „preview".
- **Darmowy tier Supabase** uspia projekt po ~tygodniu (pierwszy sync budzi z cold startem) —
  plan B: przeniesienie na wlasny DEPLOY_HOST.
- **Dlug techniczny:** prymitywy AES-GCM/PBKDF2 zduplikowane (backup + sync) — do ujednolicenia
  (osobny task, zero zmian funkcjonalnych).
- **Backup a nagrobki:** eksport domowego zawiera teraz nagrobki — do obejrzenia czy pozadane.
- Brak historii „kto co zmienil" (backlog).
