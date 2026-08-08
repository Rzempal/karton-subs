import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/models/budget_entry.dart';
import 'package:karton_subs/models/pending_receipt_scan.dart';

// Test-strażnik przycinania rachunku: akcja „Przytnij" podmienia zdjęcie
// pozycji oczekującej na docięte (ReceiptScanController.recrop). Cała podmiana
// stoi na dwóch rzeczach — copyWith musi umieć zmienić [imagePath], a nowa
// ścieżka musi przeżyć zapis pozycji. Gdyby któraś z nich cicho przestała
// działać, użytkownik zobaczyłby z powrotem nieprzycięte zdjęcie (albo pustą
// miniaturę po skasowaniu starego pliku).

PendingReceiptScan _pending({String imagePath = '/scans/oryginal.jpg'}) =>
    PendingReceiptScan(
      id: 'scan-1',
      imagePath: imagePath,
      scope: BudgetScope.personal,
      status: PendingScanStatus.done,
      createdAt: DateTime(2026, 7, 24, 12, 30),
      name: 'Biedronka',
      amount: 19.99,
      currency: 'PLN',
      date: DateTime(2026, 7, 24),
      rodzaj: 'zakupy',
    );

void main() {
  group('PendingReceiptScan — podmiana zdjęcia po przycięciu', () {
    test('copyWith(imagePath) zmienia zdjęcie i nie rusza rozpoznanych pól', () {
      final item = _pending();

      final cropped = item.copyWith(imagePath: '/scans/dociety.jpg');

      expect(cropped.imagePath, '/scans/dociety.jpg');
      // Przycięcie to operacja na obrazie — OCR się nie powtarza (decyzja
      // projektowa), więc odczytane pola muszą zostać nietknięte.
      expect(cropped.id, item.id);
      expect(cropped.name, 'Biedronka');
      expect(cropped.amount, 19.99);
      expect(cropped.currency, 'PLN');
      expect(cropped.date, item.date);
      expect(cropped.rodzaj, 'zakupy');
      expect(cropped.status, PendingScanStatus.done);
      expect(cropped.scope, BudgetScope.personal);
      expect(cropped.createdAt, item.createdAt);
    });

    test('copyWith bez imagePath zostawia dotychczasowe zdjęcie', () {
      final item = _pending();

      final retried = item.copyWith(status: PendingScanStatus.processing);

      expect(retried.imagePath, '/scans/oryginal.jpg');
      expect(retried.status, PendingScanStatus.processing);
    });

    test('przycięta ścieżka przeżywa zapis i odczyt pozycji', () {
      final cropped = _pending().copyWith(imagePath: '/scans/dociety.jpg');

      final restored = PendingReceiptScan.fromJson(cropped.toJson());

      // Bez tego po restarcie apki wróciłaby ścieżka do skasowanego pliku.
      expect(restored.imagePath, '/scans/dociety.jpg');
      expect(restored.id, cropped.id);
      expect(restored.amount, 19.99);
      expect(restored.status, PendingScanStatus.done);
    });
  });
}
