# Bezpieczenstwo

> **Powiazane:** [Architektura](architecture.md) | [Baza Danych](database.md)

---

## Zasada glowna

**Dane finansowe nigdy nie opuszczaja urzadzenia w czytelnej formie.**

Aplikacja dziala domyslnie 100% offline. Nie ma kont ani logowania. Dane opuszczaja
urzadzenie tylko w dwoch swiadomie wlaczonych przypadkach, zawsze **zaszyfrowane**:
1. **Eksport backupu** przez uzytkownika (`.zostaje`, dawniej `.subkarton`, AES-256-GCM).
2. **Synchronizacja budzetu domowego** (opcjonalna, po sparowaniu) — patrz nizej.

Budzety osobiste, subskrypcje i ustawienia **nigdy** nie opuszczaja urzadzenia.

---

## Synchronizacja budzetu domowego (relay E2E)

> **ADR:** [ADR-009 Synchronizacja budzetu domowego — relay E2E](adr/ADR-009-synchronizacja-budzetu-domowego-relay-e2e.md)

Synchronizacja jest **opcjonalna** i obejmuje **wylacznie** box `household_budget_entries`.
Po sparowaniu (QR + haslo) zmiany przeplywaja przez **skrzynke relay w chmurze**
(Supabase, darmowy tier). Model bezpieczenstwa:

| Aspekt | Rozwiazanie |
|--------|-------------|
| Szyfrowanie tresci | **End-to-end (E2E)** — AES-256-GCM, klucz z hasla (PBKDF2-SHA256, 100k) |
| Co widzi serwer | **Tylko zaszyfrowany blob + metadane** (rozmiar, znacznik czasu). NIE widzi kwot ani nazw |
| Gdzie jest klucz | Wylacznie na urzadzeniach (wyprowadzany z hasla). Nigdy na serwerze |
| Dostep do skrzynki | Po sekretnym `household_id` (z kodu QR), nie po koncie |
| Zakres | Tylko budzet domowy. Osobiste dane sie nie synchronizuja |

**Swiadomy wyjatek od „zero cloud":** wlaczenie synchronizacji oznacza, ze serwer relay
posredniczy w przesylaniu zaszyfrowanych paczek. Serwer nie odczytuje tresci, ale widzi
**metadane** (ze i kiedy nastapila wymiana, jej rozmiar). Bez wlaczonej synchronizacji
aplikacja dziala jak dotad — w pelni offline.

---

## Przechowywanie danych

| Aspekt | Rozwiazanie |
|--------|-------------|
| Lokalna baza | Hive (NoSQL) -- pliki na urzadzeniu |
| Szyfrowanie at-rest | Hive nie szyfruje domyslnie -- dane w plaintext na dysku |
| Dostepu do danych | Sandboxing Androida/iOS -- inne aplikacje nie maja dostepu |
| Backup szyfrowany | AES-256-GCM z kluczem urzadzenia lub haslem uzytkownika |

### Wrazliwosc danych

Dane subskrypcji sa **umiarkowanie wrazliwe** -- nie sa to dane bankowe, ale zdradzaja wzorce wydatkow.

| Dane | Wrazliwosc | Ochrona |
|------|-----------|---------|
| Nazwy subskrypcji | Niska | Sandbox OS |
| Kwoty | Umiarkowana | Sandbox OS + szyfrowany backup |
| Daty odnowien | Niska | Sandbox OS |
| Historia uzycia | Niska | Sandbox OS |

---

## Szyfrowanie backupow

Referencja: `reference-code/services/backup_crypto_service.dart`

### Format pliku backup

```
[4B Magic] [1B Version] [1B KeyType] [16B Salt] [12B IV] [NB Ciphertext] [16B GCM Auth Tag]
```

### Dwa tryby szyfrowania

| Tryb | Klucz | Przenosnosc | Uzycie |
|------|-------|-------------|--------|
| Device Key | Android Keystore / iOS Keychain | Tylko to urzadzenie | Automatyczny backup |
| Password | PBKDF2-SHA256 (100k iteracji) | Przenoszalny | Udostepnianie, migracja |

### Algorytm

- **Cipher:** AES-256-GCM (authenticated encryption)
- **Key derivation:** PBKDF2 z SHA-256, 100 000 iteracji, 32-byte key
- **IV:** 12 bajtow, losowy (SecureRandom)
- **Salt:** 16 bajtow, losowy

---

## Aktualizacje OTA

Referencja: `reference-code/services/update_service.dart`

| Aspekt | Rozwiazanie |
|--------|-------------|
| Zrodlo | Wlasny serwer (version.json + APK) |
| Weryfikacja | Porownanie versionCode |
| Transport | HTTPS |
| Integralnosc | Checksum w ota_update |

---

## Prywatnosc

### Co aplikacja NIE robi

- NIE zbiera danych analitycznych (zero telemetrii)
- NIE laczy sie z internetem (poza OTA check i opcjonalnym PDF exportem)
- NIE wymaga konta ani logowania
- NIE udostepnia danych podmiotom trzecim
- NIE uzywa reklam

### Uprawnienia Android

| Uprawnienie | Cel | Kiedy |
|-------------|-----|-------|
| `INTERNET` | Sprawdzanie aktualizacji OTA | Przy starcie (opcjonalne) |
| `REQUEST_INSTALL_PACKAGES` | Instalacja OTA update | Przy aktualizacji |
| `RECEIVE_BOOT_COMPLETED` | Wznowienie powiadomien po restarcie | Jesli notifications wlaczone |
| `POST_NOTIFICATIONS` | Przypomnienia o odnowieniach | Jesli notifications wlaczone |

---

## Disclaimer

> **Zostaje** jest narzedziem informacyjnym do sledzenia wydatkow na subskrypcje.
> Aplikacja NIE jest usluga finansowa, NIE udziela porad finansowych i NIE laczy sie
> z kontami bankowymi. Wszystkie dane sa wprowadzane recznie przez uzytkownika.

---

> **Ostatnia aktualizacja:** 2026-03-25
