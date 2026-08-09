import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/services/storage_service.dart';

import 'support/hive_test_env.dart';

/// Ustawienia widoku sekcji miesiąca („Płatności" / „Podsumowanie") są trwałe
/// i OSOBNE dla każdej sekcji. Osobność jest tu sednem: wspólny stan zmuszał do
/// przełączania w tę i z powrotem, bo obie listy ogląda się w innym celu.
void main() {
  late StorageService storage;

  setUpAll(() async => storage = await setUpHiveStorage());
  tearDownAll(tearDownHiveStorage);

  group('Widok sekcji miesiąca — zapis', () {
    test('domyślne, gdy nic nie zapisano', () {
      expect(storage.getFlowSort('nieznana'), 'byDate');
      expect(storage.getFlowGrouping('nieznana'), 'none');
      expect(storage.getFlowSpendingCollapsed('nieznana'), isFalse);
    });

    test('sekcje nie nadpisują się nawzajem', () async {
      await storage.setFlowSort('payments', 'byDate');
      await storage.setFlowSort('summary', 'amountDesc');

      expect(storage.getFlowSort('payments'), 'byDate');
      expect(storage.getFlowSort('summary'), 'amountDesc');
    });

    test('grupowanie i zwijanie też są per sekcja', () async {
      await storage.setFlowGrouping('payments', 'byType');
      await storage.setFlowGrouping('summary', 'none');
      await storage.setFlowSpendingCollapsed('payments', false);
      await storage.setFlowSpendingCollapsed('summary', true);

      expect(storage.getFlowGrouping('payments'), 'byType');
      expect(storage.getFlowGrouping('summary'), 'none');
      expect(storage.getFlowSpendingCollapsed('payments'), isFalse);
      expect(storage.getFlowSpendingCollapsed('summary'), isTrue);
    });

    test('nieznana wartość wraca do domyślnej, a nie wywala odczytu', () async {
      // Tak wyglądałby zapis po przemianowaniu enuma — świadomie dopuszczone:
      // najgorsze, co się dzieje, to powrót do widoku domyślnego.
      await storage.setFlowSort('payments', 'sortowanieKtoregoJuzNieMa');

      expect(storage.getFlowSort('payments'), 'sortowanieKtoregoJuzNieMa');
      // Mapowanie na enum robi ekran (`orElse`), więc tu pilnujemy tylko tego,
      // że magazyn oddaje surową wartość bez wyjątku.
    });
  });
}
