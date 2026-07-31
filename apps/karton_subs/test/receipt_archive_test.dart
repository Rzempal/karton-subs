import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/controllers/bill_scan_controller.dart';
import 'package:karton_subs/services/ai_engine_service.dart';
import 'package:karton_subs/services/notification_service.dart';
import 'package:karton_subs/services/storage_service.dart';
import 'package:karton_subs/services/text_ocr_service.dart';

import 'support/hive_test_env.dart';

// Publiczne archiwum zdjec rachunkow (`Documents/<podfolder>`).
//
// Luka zamykana tym testem: po docieciu zdjecia JUZ ZAPISANEGO rachunku
// podmieniala sie tylko prywatna kopia w apce, a w archiwum zostawala wersja
// nieprzycieta — czyli dokladnie ta, ktorej uzytkownik nie chcial.
//
// Warstwa natywna jest podstawiona (kanal `zostaje/ai_engine`), bo MediaStore
// zyje w Androidzie. Sprawdzamy KOLEJNOSC i argumenty wywolan: MediaStore nie
// nadpisuje po nazwie, tylko dokłada „nazwa (1).jpg", wiec stara wersja musi
// zostac skasowana PRZED zapisem nowej.

late StorageService _storage;
late BillScanController _controller;
late Directory _photos;

/// Slad wywolan kanalu natywnego.
final List<({String method, Map<Object?, Object?> args})> _calls = [];

const _channel = MethodChannel('zostaje/ai_engine');
// Prywatna kopia zdjecia ladzie w katalogu dokumentow aplikacji — w tescie
// podstawiamy katalog tymczasowy, bo wtyczki od sciezek tu nie ma.
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

Future<String> _makePhoto(String name) async {
  final file = File('${_photos.path}/$name');
  await file.writeAsBytes([0xFF, 0xD8, 0xFF]); // udawany JPEG
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _storage = await setUpHiveStorage();
    _photos = await Directory.systemTemp.createTemp('zostaje_photos_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, (call) async {
      return call.method == 'getApplicationDocumentsDirectory'
          ? _photos.path
          : null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      _calls.add((
        method: call.method,
        args: (call.arguments as Map?) ?? const {},
      ));
      return switch (call.method) {
        // Ścieżka, którą normalnie zwraca MediaStore.
        'archiveReceipt' =>
          '/Documents/Zostaje/${(call.arguments as Map)['filename']}',
        'deleteArchivedReceipt' => true,
        'drainScanResults' => {'results': const [], 'inFlight': const []},
        _ => null,
      };
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, null);
    await _photos.delete(recursive: true);
    await tearDownHiveStorage();
  });

  setUp(() async {
    await resetStorage(_storage);
    for (final id in _storage.getArchivedReceiptNames().keys.toList()) {
      await _storage.removeArchivedReceiptName(id);
    }
    _calls.clear();
    await _storage.setReceiptArchiveEnabled(true);
    _controller = BillScanController(
      _storage,
      AiEngineService(),
      const NotificationService(),
      TextOcrService(),
    );
  });

  group('Archiwum przy zatwierdzeniu rachunku', () {
    test('zapisuje plik i zapamietuje jego nazwe', () async {
      final photo = await _makePhoto('skan.jpg');

      final error = await _controller.finalizeApproval(
        entryId: 'e1',
        imagePath: photo,
        name: 'Prad Tauron',
        amount: 184.32,
        date: DateTime(2026, 7, 20),
      );

      expect(error, isNull);
      final archive = _calls.where((c) => c.method == 'archiveReceipt').single;
      expect(archive.args['filename'], '2026-07-20_Prad_Tauron_184.32.jpg');
      expect(
        _storage.getArchivedReceiptName('e1'),
        '2026-07-20_Prad_Tauron_184.32.jpg',
        reason: 'bez zapamietanej nazwy nie da sie potem podmienic pliku',
      );
    });

    test('pierwsza archiwizacja niczego nie kasuje', () async {
      await _controller.finalizeApproval(
        entryId: 'e1',
        imagePath: await _makePhoto('skan.jpg'),
        name: 'Woda',
        amount: 50,
        date: DateTime(2026, 7, 20),
      );
      expect(_calls.any((c) => c.method == 'deleteArchivedReceipt'), isFalse);
    });

    test('wylaczone archiwum nie dotyka plikow', () async {
      await _storage.setReceiptArchiveEnabled(false);
      await _controller.finalizeApproval(
        entryId: 'e1',
        imagePath: await _makePhoto('skan.jpg'),
        name: 'Woda',
        amount: 50,
        date: DateTime(2026, 7, 20),
      );
      expect(_calls.any((c) => c.method == 'archiveReceipt'), isFalse);
      expect(_storage.getArchivedReceiptName('e1'), isNull);
    });
  });

  group('Dociecie zdjecia zapisanego rachunku', () {
    test('stara wersja znika z archiwum, nowa wchodzi', () async {
      await _controller.finalizeApproval(
        entryId: 'e1',
        imagePath: await _makePhoto('skan.jpg'),
        name: 'Prad Tauron',
        amount: 184.32,
        date: DateTime(2026, 7, 20),
      );
      _calls.clear();

      final cropped = await _makePhoto('dociety.jpg');
      final saved = await _controller.replaceReceiptPhoto(
        'e1',
        cropped,
        name: 'Prad Tauron',
        amount: 184.32,
        date: DateTime(2026, 7, 20),
      );

      expect(saved, isNotNull, reason: 'prywatna kopia podmieniona');
      final methods = _calls.map((c) => c.method).toList();
      expect(
        methods.indexOf('deleteArchivedReceipt') <
            methods.indexOf('archiveReceipt'),
        isTrue,
        reason: 'MediaStore nie nadpisuje — stary plik musi zniknac pierwszy',
      );
      final deleted =
          _calls.firstWhere((c) => c.method == 'deleteArchivedReceipt');
      expect(deleted.args['filename'], '2026-07-20_Prad_Tauron_184.32.jpg');
    });

    test('bez danych rachunku archiwum zostaje nietkniete', () async {
      await _controller.finalizeApproval(
        entryId: 'e1',
        imagePath: await _makePhoto('skan.jpg'),
        name: 'Prad',
        amount: 10,
        date: DateTime(2026, 7, 20),
      );
      _calls.clear();

      // Wywolanie bez name/amount/date — np. z ekranu, ktory ich nie zna.
      await _controller.replaceReceiptPhoto('e1', await _makePhoto('d2.jpg'));

      expect(_calls.any((c) => c.method == 'archiveReceipt'), isFalse);
      expect(_calls.any((c) => c.method == 'deleteArchivedReceipt'), isFalse);
    });

    test('nieudany zapis do archiwum nie psuje podgladu w apce', () async {
      await _storage.setArchivedReceiptName('e1', 'stara.jpg');
      // Kolejny zapis do archiwum zwroci null (blad po stronie natywnej).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        _calls.add((
          method: call.method,
          args: (call.arguments as Map?) ?? const {},
        ));
        if (call.method == 'archiveReceipt') return null;
        if (call.method == 'drainScanResults') {
          return {'results': const [], 'inFlight': const []};
        }
        return true;
      });

      final saved = await _controller.replaceReceiptPhoto(
        'e1',
        await _makePhoto('d3.jpg'),
        name: 'Prad',
        amount: 10,
        date: DateTime(2026, 7, 20),
      );

      expect(
        saved,
        isNotNull,
        reason: 'archiwum to kopia dodatkowa — jej blad nie cofa dociecia',
      );
      expect(_storage.getReceiptPhotoPath('e1'), saved);
    });
  });

  group('Usuniecie rachunku', () {
    test('czysci pamiec o nazwie, ale NIE kasuje pliku z archiwum', () async {
      await _controller.finalizeApproval(
        entryId: 'e1',
        imagePath: await _makePhoto('skan.jpg'),
        name: 'Prad',
        amount: 10,
        date: DateTime(2026, 7, 20),
      );
      _calls.clear();

      await _controller.deletePhotoFor('e1');

      expect(_storage.getArchivedReceiptName('e1'), isNull);
      expect(
        _calls.any((c) => c.method == 'deleteArchivedReceipt'),
        isFalse,
        reason: 'archiwum to trwaly slad, nie kasujemy go za uzytkownika',
      );
    });
  });
}
