import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_entry.dart';
import '../models/pending_bill_scan.dart';
import '../models/subscription.dart';
import '../services/ai_engine_service.dart';
import '../services/app_logger.dart';
import '../services/bill_scan_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'budget_controller.dart';

/// Skanowanie rachunków lokalnym silnikiem AI: kolejka pozycji oczekujących.
///
/// Przepływ: zdjęcie → kopia w katalogu apki → pozycja „processing" → OCR
/// w tle (usługa AIDL silnika, ~30–45 s) → pozycja „done" z rozpoznanymi polami
/// i miniaturą → użytkownik zatwierdza (powstaje zwykły [BudgetEntryType.billPayment])
/// albo odrzuca. Pozycje oczekujące są lokalne — poza bilansem, synchronizacją
/// i backupem; do budżetu wchodzą dopiero po zatwierdzeniu.
class BillScanController extends ChangeNotifier {
  static final _log = AppLogger.get('BillScanController');
  static const _uuid = Uuid();

  final StorageService _storage;
  final AiEngineService _engine;
  final NotificationService _notifications;

  List<PendingBillScan> _items = [];

  // Kolejka OCR: silnik robi jedno rozpoznanie naraz (wizja na CPU), więc
  // skany są serializowane — nowe czekają w kolejce jako „processing", a
  // przetwarzany jest tylko [_activeId]. Bez tego równoległe skany biłyby się
  // o ten sam silnik i marnowały połączenia z usługą.
  final List<String> _queue = [];
  bool _draining = false;
  String? _activeId;

  /// Skany zlecone warstwie natywnej, na których wynik czeka kolejka.
  final Map<String, Completer<void>> _awaiting = {};

  /// Zapas ponad limity warstwy natywnej (25 s na połączenie + 300 s pracy):
  /// gdyby usługa zginęła bez śladu, kolejka nie może stać w nieskończoność.
  static const _watchdog = Duration(seconds: 420);

  /// Id aktualnie rozpoznawanego skanu (reszta „processing" czeka w kolejce).
  String? get activeScanId => _activeId;

  BillScanController(this._storage, this._engine, this._notifications) {
    _items = List.of(_storage.getPendingBillScans());
    _engine.setScanResultsListener(() => unawaited(_drainResults()));
    unawaited(_recoverAfterStart());
  }

  /// Po starcie aplikacji: odbiera wyniki skanów policzonych, gdy aplikacja nie
  /// żyła (usługa pracuje niezależnie od ekranu), zostawia w spokoju te nadal
  /// przetwarzane, a resztę „processing" — sieroty po ubitym procesie —
  /// oznacza jako błąd z możliwością ponowienia.
  Future<void> _recoverAfterStart() async {
    // Sierotami mogą być tylko pozycje wczytane z dysku — skan rozpoczęty już
    // po starcie (gdyby użytkownik zdążył) idzie normalną drogą przez kolejkę.
    final known = _items.map((e) => e.id).toSet();
    final snapshot = await _engine.drainScanResults();
    for (final outcome in snapshot.results) {
      _applyOutcome(outcome);
    }
    final running = snapshot.inFlight.toSet();
    _items = _items
        .map(
          (e) => e.status == PendingScanStatus.processing &&
                  known.contains(e.id) &&
                  !running.contains(e.id)
              ? e.copyWith(
                  status: PendingScanStatus.error,
                  errorMessage:
                      'Rozpoznawanie przerwane (aplikacja została zamknięta) — ponów',
                )
              : e,
        )
        .toList();
    if (running.isNotEmpty) _activeId ??= running.first;
    await _persist();
    notifyListeners();
  }

  /// Odbiera gotowe wyniki ze skrzynki warstwy natywnej.
  Future<void> _drainResults() async {
    final snapshot = await _engine.drainScanResults();
    if (snapshot.results.isEmpty) return;
    for (final outcome in snapshot.results) {
      _applyOutcome(outcome);
    }
    await _persist();
    notifyListeners();
  }

  /// Pozycje oczekujące (wszystkie zakresy; ekran filtruje po aktywnym).
  List<PendingBillScan> get pending => List.unmodifiable(_items);

  /// Asystent AI (opt-in): steruje widocznością opcji skanowania.
  /// Zmiana przechodzi przez kontroler (notifyListeners), bo ekran Rachunki
  /// żyje w IndexedStack i sam z siebie nie przebuduje się po zmianie w storage.
  bool get aiAssistantEnabled => _storage.getAiAssistantEnabled();

  Future<void> setAiAssistantEnabled(bool value) async {
    await _storage.setAiAssistantEnabled(value);
    notifyListeners();
  }

  /// Stan lokalnego silnika AI (zainstalowany / model pobrany).
  Future<AiEngineStatus> engineStatus() => _engine.status();

  /// Przyjmuje zdjęcie rachunku: kopiuje do katalogu apki, dodaje pozycję
  /// „processing" i odpala OCR w tle. Wraca od razu (nie czeka na silnik).
  Future<void> startScan(String sourcePath, BudgetScope scope) async {
    final id = _uuid.v4();
    final dir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${dir.path}/bill_scans');
    await scansDir.create(recursive: true);
    final ext = sourcePath.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    final dest = '${scansDir.path}/$id.$safeExt';
    await File(sourcePath).copy(dest);

    _items = [
      ..._items,
      PendingBillScan(
        id: id,
        imagePath: dest,
        scope: scope,
        status: PendingScanStatus.processing,
        createdAt: DateTime.now(),
      ),
    ];
    await _persist();
    notifyListeners();
    _enqueue(id);
  }

  /// Ponawia rozpoznawanie pozycji zakończonej błędem.
  Future<void> retry(String id) async {
    final item = _byId(id);
    if (item == null || item.status == PendingScanStatus.processing) return;
    _replace(item.copyWith(status: PendingScanStatus.processing));
    await _persist();
    notifyListeners();
    _enqueue(id);
  }

  /// Podmienia zdjęcie pozycji oczekującej na przycięte (akcja „Przytnij"
  /// w podglądzie miniatury). [croppedPath] równe dotychczasowej ścieżce
  /// oznacza anulowanie — nic się nie dzieje.
  ///
  /// Świadomie NIE uruchamia rozpoznawania od nowa: kto ma już poprawnie
  /// odczytane pola, nie czeka drugi raz ~45 s. Kto nie ma — użyje „Ponów",
  /// a silnik dostanie wtedy zdjęcie już docięte. Zatwierdzenie zabiera
  /// przycięty plik do prywatnej kopii i do archiwum.
  Future<void> recrop(String id, String croppedPath) async {
    final item = _byId(id);
    if (item == null || croppedPath == item.imagePath) return;
    // W trakcie rozpoznawania ani drgnij: [_process] trzyma własną kopię
    // pozycji sprzed OCR i po zakończeniu cofnąłby podmianę ścieżki, a stary
    // plik byłby już skasowany.
    if (item.status == PendingScanStatus.processing) return;
    final previous = item.imagePath;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${dir.path}/bill_scans');
      await scansDir.create(recursive: true);
      // Nowy plik zamiast nadpisania starego z dwóch powodów: to samo zdjęcie
      // bywa podpięte pod kilka pozycji (kilka rachunków z jednego kadru),
      // a Flutter trzyma wczytane obrazy pod kluczem ścieżki — zmiana ścieżki
      // wymusza odświeżenie miniatury.
      final dest = '${scansDir.path}/${_uuid.v4()}.jpg';
      await File(croppedPath).copy(dest);
      _replace(item.copyWith(imagePath: dest));

      // Poprzednie zdjęcie kasujemy tylko, gdy nie korzysta z niego inna pozycja.
      if (!_items.any((e) => e.imagePath == previous)) {
        try {
          await File(previous).delete();
        } catch (_) {
          // Brak pliku nie jest problemem.
        }
      }
      await _persist();
      notifyListeners();
    } catch (e, st) {
      _log.warning('Podmiana przyciętego zdjęcia: $e', e, st);
    }
  }

  /// Dokłada skan do kolejki OCR i uruchamia jej opróżnianie (jeśli nie działa).
  void _enqueue(String id) {
    if (!_queue.contains(id)) _queue.add(id);
    unawaited(_drainQueue());
  }

  /// Przetwarza kolejkę pojedynczo: jeden aktywny OCR naraz.
  Future<void> _drainQueue() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.removeAt(0);
        final item = _byId(id);
        // Pominięcie pozycji usuniętych/zmienionych w międzyczasie.
        if (item == null || item.status != PendingScanStatus.processing) continue;
        _activeId = id;
        notifyListeners(); // „W kolejce…" -> „Rozpoznaję…"
        // Powiadomienie postępu wystawia usługa natywna (jest jej warunkiem
        // pracy na pierwszym planie) — tutaj już go nie dublujemy.
        await _process(id);
      }
    } finally {
      _activeId = null;
      _draining = false;
    }
  }

  /// Zatwierdza rozpoznany rachunek (przycisk ✓): tworzy [billPayment], wiąże
  /// zdjęcie z pozycją (podgląd w edycji), archiwizuje (opt-in) i usuwa skan.
  /// Wymaga rozpoznanej kwoty — bez niej prowadź przez edycję (formularz).
  /// Zwraca komunikat błędu archiwum (do snackbara) albo null.
  Future<String?> approve(String id, BudgetController budget) async {
    final item = _byId(id);
    final amount = item?.amount;
    if (item == null || item.status != PendingScanStatus.done) return null;
    if (amount == null || amount <= 0) return null;

    final now = DateTime.now();
    final date = item.date ?? DateTime(now.year, now.month, now.day);
    final currency = Currency.values.firstWhere(
      (c) => c.name == (item.currency ?? 'PLN'),
      orElse: () => Currency.PLN,
    );
    final categoryId = BillScanParser.suggestCategoryId(
      item.rodzaj,
      _storage.getCategories(),
    );

    // Zakres wybiera pudełko danych (jak formularz rachunku).
    budget.setScope(item.scope);
    final entry = await budget.create(
      name: item.name ?? 'Rachunek',
      type: BudgetEntryType.billPayment,
      amount: amount,
      currency: currency,
      month: BudgetEntry.monthKeyOf(date),
      startDate: date,
      categoryId: categoryId,
    );
    final err = await finalizeApproval(
      entryId: entry.id,
      imagePath: item.imagePath,
      name: item.name ?? 'Rachunek',
      amount: amount,
      date: date,
    );
    await remove(id);
    return err;
  }

  /// Wspólny finał zatwierdzenia (dla ✓ i dla ścieżki edycji formularza):
  /// prywatna kopia zdjęcia powiązana z rachunkiem (podgląd) + archiwum (opt-in).
  /// [imagePath] to zdjęcie do zapisania — zwykle kopia skanu, ale jeśli
  /// użytkownik docił kadr w edycji, to już wersja przycięta.
  /// Zwraca komunikat błędu archiwum albo null.
  Future<String?> finalizeApproval({
    required String entryId,
    required String imagePath,
    required String name,
    required double amount,
    required DateTime date,
  }) async {
    await _linkPhoto(entryId, imagePath);
    if (_storage.getReceiptArchiveEnabled()) {
      return _archive(imagePath, name, amount, date);
    }
    return null;
  }

  /// Podmienia prywatną kopię zdjęcia ZAPISANEGO rachunku na przyciętą
  /// (akcja „Przytnij" w edycji istniejącej pozycji). Nowa nazwa pliku wymusza
  /// odświeżenie miniatury (Flutter cache'uje obraz po ścieżce). Zwraca nową
  /// ścieżkę albo null przy błędzie.
  ///
  /// Uwaga: dotyczy tylko podglądu w apce. Publiczne archiwum w `Documents`
  /// zapisane przy zatwierdzeniu nie jest tu ruszane.
  Future<String?> replaceReceiptPhoto(String entryId, String croppedPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${dir.path}/receipts');
      await receiptsDir.create(recursive: true);
      final previous = _storage.getReceiptPhotoPath(entryId);
      final dest = '${receiptsDir.path}/${entryId}_${_uuid.v4()}.jpg';
      await File(croppedPath).copy(dest);
      await _storage.setReceiptPhotoPath(entryId, dest);
      if (previous != null && previous != dest) {
        try {
          await File(previous).delete();
        } catch (_) {
          // Brak pliku nie jest problemem.
        }
      }
      return dest;
    } catch (e, st) {
      _log.warning('Podmiana zdjęcia zapisanego rachunku: $e', e, st);
      return null;
    }
  }

  /// Trwała, prywatna kopia zdjęcia w katalogu apki (`receipts/[entryId].jpg`)
  /// powiązana z rachunkiem — zawsze czytelna dla podglądu (niezależnie od
  /// publicznego archiwum i uprawnień do pamięci).
  Future<void> _linkPhoto(String entryId, String sourcePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${dir.path}/receipts');
      await receiptsDir.create(recursive: true);
      final ext = sourcePath.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      final dest = '${receiptsDir.path}/$entryId.$safeExt';
      await File(sourcePath).copy(dest);
      await _storage.setReceiptPhotoPath(entryId, dest);
    } catch (e, st) {
      _log.warning('Powiązanie zdjęcia z rachunkiem: $e', e, st);
    }
  }

  /// Usuwa powiązane zdjęcie rachunku (przy usuwaniu rachunku z listy).
  Future<void> deletePhotoFor(String entryId) async {
    final path = _storage.getReceiptPhotoPath(entryId);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {
        // Brak pliku nie jest problemem.
      }
      await _storage.removeReceiptPhotoPath(entryId);
    }
  }

  /// Zapisuje zdjęcie zatwierdzonego rachunku do publicznego archiwum.
  /// Zwraca komunikat błędu (do snackbara) albo null przy sukcesie.
  Future<String?> _archive(
    String sourcePath,
    String name,
    double amount,
    DateTime date,
  ) async {
    try {
      final ext = sourcePath.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final namePart = _sanitize(name);
      final amountPart = amount.toStringAsFixed(2);
      final filename = '${dateStr}_${namePart}_$amountPart.$safeExt';
      final saved = await _engine.archiveReceipt(
        imagePath: sourcePath,
        subfolder: _storage.getReceiptArchiveSubfolder(),
        filename: filename,
      );
      if (saved == null) {
        _log.warning('Archiwizacja rachunku nie powiodła się');
        return 'Nie udało się zapisać zdjęcia do archiwum';
      }
      return null;
    } catch (e, st) {
      _log.warning('Archiwizacja rachunku: $e', e, st);
      return 'Nie udało się zapisać zdjęcia do archiwum: $e';
    }
  }

  /// Bezpieczna nazwa pliku: litery/cyfry (w tym polskie) + spacje→_, reszta
  /// usunięta, obcięta do 40 znaków.
  String _sanitize(String s) {
    final cleaned = s
        .replaceAll(RegExp(r'[^0-9A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    if (cleaned.isEmpty) return 'rachunek';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  /// Sugestia kategorii dla pozycji (do prefillu formularza przy edycji).
  String? suggestCategoryId(PendingBillScan item) =>
      BillScanParser.suggestCategoryId(item.rodzaj, _storage.getCategories());

  /// Usuwa pozycję; kasuje miniaturę, jeśli nie dzieli jej inna pozycja
  /// (kilka rachunków z jednego zdjęcia).
  Future<void> remove(String id) async {
    final item = _byId(id);
    if (item == null) return;
    _queue.remove(id); // gdyby czekał jeszcze w kolejce OCR
    // Gdy kasujemy właśnie rozpoznawaną pozycję, kolejka rusza dalej od razu
    // (wynik z warstwy natywnej trafi w próżnię — nie ma już czego wypełniać).
    _awaiting.remove(id)?.complete();
    if (_activeId == id) _activeId = null;
    _items = _items.where((e) => e.id != id).toList();
    final shared = _items.any((e) => e.imagePath == item.imagePath);
    if (!shared) {
      try {
        await File(item.imagePath).delete();
      } catch (_) {
        // Brak pliku nie jest problemem.
      }
    }
    await _persist();
    notifyListeners();
  }

  /// Zleca rozpoznanie warstwie natywnej i czeka na wynik — nie dlatego, że
  /// wynik musi tu wrócić (przyjdzie skrzynką, choćby po ponownym otwarciu
  /// aplikacji), tylko po to, by kolejny skan z kolejki nie ruszył równolegle.
  Future<void> _process(String id) async {
    final item = _byId(id);
    if (item == null) return;
    final completer = Completer<void>();
    _awaiting[id] = completer;
    try {
      await _engine.startBillScan(scanId: id, imagePath: item.imagePath);
    } on AiEngineException catch (e) {
      _awaiting.remove(id);
      await _fail(id, e.message);
      return;
    } catch (e, st) {
      _awaiting.remove(id);
      _log.severe('Zlecenie rozpoznawania rachunku', e, st);
      await _fail(id, 'Błąd rozpoznawania — ponów');
      return;
    }
    try {
      await completer.future.timeout(_watchdog);
    } on TimeoutException {
      _awaiting.remove(id);
      if (_byId(id)?.status == PendingScanStatus.processing) {
        await _fail(id, 'Rozpoznawanie nie odpowiada — ponów');
      }
    }
  }

  /// Wynik jednego skanu z warstwy natywnej — także taki, który przyszedł
  /// w czasie, gdy aplikacja była zamknięta.
  void _applyOutcome(ScanOutcome outcome) {
    if (_activeId == outcome.scanId) _activeId = null;
    _awaiting.remove(outcome.scanId)?.complete();
    final item = _byId(outcome.scanId);
    if (item == null) return; // pozycję skasowano w międzyczasie

    final raw = outcome.rawJson;
    final bills = raw == null ? const <ParsedBill>[] : BillScanParser.parse(raw);
    if (bills.isEmpty) {
      _replace(
        item.copyWith(
          status: PendingScanStatus.error,
          errorMessage: outcome.errorMessage ??
              'Nie rozpoznano rachunku na zdjęciu — spróbuj wyraźniejszego ujęcia',
        ),
      );
      if (!outcome.nativeNotified) {
        unawaited(_notifications.showScanFailed(item.id));
      }
      return;
    }
    // Pierwszy rachunek aktualizuje pozycję; kolejne (kilka dokumentów na
    // jednym zdjęciu) stają się osobnymi pozycjami z tą samą miniaturą.
    final filled = _filled(item, bills.first);
    _replace(filled);
    if (!outcome.nativeNotified) {
      unawaited(_notifications.showScanDone(item.id, filled.name));
    }
    for (final extra in bills.skip(1)) {
      _items = [
        ..._items,
        _filled(
          PendingBillScan(
            id: _uuid.v4(),
            imagePath: item.imagePath,
            scope: item.scope,
            status: PendingScanStatus.processing,
            createdAt: item.createdAt,
          ),
          extra,
        ),
      ];
    }
  }

  /// Kończy skan błędem (zlecenie nieprzyjęte albo cisza z warstwy natywnej).
  Future<void> _fail(String id, String message) async {
    final item = _byId(id);
    if (item == null) return;
    if (_activeId == id) _activeId = null;
    _replace(
      item.copyWith(status: PendingScanStatus.error, errorMessage: message),
    );
    unawaited(_notifications.showScanFailed(id));
    await _persist();
    notifyListeners();
  }

  PendingBillScan _filled(PendingBillScan base, ParsedBill bill) => base.copyWith(
        status: PendingScanStatus.done,
        name: bill.name,
        amount: bill.amount,
        currency: bill.currency,
        date: bill.date,
        rodzaj: bill.rodzaj,
      );

  PendingBillScan? _byId(String id) {
    for (final e in _items) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _replace(PendingBillScan item) {
    _items = _items.map((e) => e.id == item.id ? item : e).toList();
  }

  Future<void> _persist() => _storage.savePendingBillScans(_items);
}
