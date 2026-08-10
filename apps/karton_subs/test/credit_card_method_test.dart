import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:karton_subs/models/subscription.dart';
import 'package:karton_subs/theme/app_theme.dart'
    show AppColors, AppSemanticColors;
import 'package:karton_subs/widgets/category_icons.dart';

/// Karta kredytowa jako metoda płatności (ADR-033). Pola są opcjonalne w JSON-ie,
/// bo metody jadą w paczce synchronizacji (ADR-025) — telefon na starszej wersji
/// musi dalej czytać metodę, której nowych pól nie zna.
void main() {
  group('PaymentMethod — karta kredytowa', () {
    test('zwykła metoda nie jest kartą i nie ma warunków kredytu', () {
      const pm = PaymentMethod(id: '1', name: 'Przelew zwykły');

      expect(pm.isCreditCard, isFalse);
      expect(pm.graceDays, isNull);
      expect(pm.hasCreditTerms, isFalse);
    });

    test('karta z dniami ma komplet warunków', () {
      const pm = PaymentMethod(
        id: '1',
        name: 'Karta Millennium',
        isCreditCard: true,
        graceDays: 50,
      );

      expect(pm.hasCreditTerms, isTrue);
    });

    test('karta BEZ dni nie ma warunków — automat nie ruszy', () {
      const pm = PaymentMethod(id: '1', name: 'Karta', isCreditCard: true);

      // Bez liczby dni nie da się wyliczyć terminu spłaty, więc automat musi
      // milczeć zamiast zgadywać.
      expect(pm.hasCreditTerms, isFalse);
    });

    test('zero i wartości ujemne nie są okresem bezodsetkowym', () {
      const zero = PaymentMethod(
        id: '1',
        name: 'K',
        isCreditCard: true,
        graceDays: 0,
      );

      expect(zero.hasCreditTerms, isFalse);
    });

    test('round-trip JSON zachowuje kartę i dni', () {
      const pm = PaymentMethod(
        id: '1',
        name: 'Karta',
        order: 3,
        isAutomatic: true,
        isCreditCard: true,
        graceDays: 50,
      );

      final back = PaymentMethod.fromJson(pm.toJson());

      expect(back.isCreditCard, isTrue);
      expect(back.graceDays, 50);
      expect(back.isAutomatic, isTrue);
      expect(back.order, 3);
    });

    test('metoda zapisana PRZED tą funkcją czyta się bez zmian', () {
      // Dokładnie taki JSON leży dziś na telefonach i w kopiach.
      final back = PaymentMethod.fromJson({
        'id': '1',
        'name': 'Przelew zwykły',
        'order': 0,
        'isAutomatic': false,
      });

      expect(back.isCreditCard, isFalse);
      expect(back.graceDays, isNull);
      expect(back.name, 'Przelew zwykły');
    });

    test('zwykła metoda nie zaśmieca zapisu nowymi polami', () {
      const pm = PaymentMethod(id: '1', name: 'Przelew zwykły');
      final json = pm.toJson();

      // Starsza aplikacja dostaje dokładnie to, co dotąd — bez nadmiarowych
      // kluczy, które mogłaby zapisać z powrotem i rozjechać scalanie.
      expect(json.containsKey('isCreditCard'), isFalse);
      expect(json.containsKey('graceDays'), isFalse);
    });

    test('cztery kombinacje toggli dają cztery różne wyglądy', () {
      const zwyklaManualna = PaymentMethod(id: '1', name: 'a');
      const zwyklaAuto = PaymentMethod(id: '2', name: 'b', isAutomatic: true);
      const kartaManualna = PaymentMethod(
        id: '3',
        name: 'c',
        isCreditCard: true,
        graceDays: 30,
      );
      const kartaAuto = PaymentMethod(
        id: '4',
        name: 'd',
        isCreditCard: true,
        graceDays: 30,
        isAutomatic: true,
      );

      // Kształt: skąd pieniądze. Karta ma własny, niezależnie od automatu.
      expect(paymentMethodIcon(zwyklaManualna), LucideIcons.hand);
      expect(paymentMethodIcon(zwyklaAuto), LucideIcons.zap);
      expect(paymentMethodIcon(kartaManualna), LucideIcons.creditCard);
      expect(paymentMethodIcon(kartaAuto), LucideIcons.creditCard);

      // Kolor: kto płaci. Rozróżnia dwie karty od siebie.
      final c = AppSemanticColors.of(AppColors.active);
      expect(paymentMethodIconColor(zwyklaManualna, c), isNull);
      expect(paymentMethodIconColor(zwyklaAuto, c), isNull);
      expect(paymentMethodIconColor(kartaManualna, c), c.negative);
      expect(paymentMethodIconColor(kartaAuto, c), c.warning);
      expect(
        paymentMethodIconColor(kartaManualna, c),
        isNot(paymentMethodIconColor(kartaAuto, c)),
      );
    });

    test('wyłączenie karty czyści dni', () {
      const pm = PaymentMethod(
        id: '1',
        name: 'Karta',
        isCreditCard: true,
        graceDays: 50,
      );

      final off = pm.copyWith(isCreditCard: false, clearGraceDays: true);

      expect(off.isCreditCard, isFalse);
      expect(off.graceDays, isNull);
      expect(off.hasCreditTerms, isFalse);
    });
  });
}
