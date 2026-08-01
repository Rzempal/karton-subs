import 'package:flutter_test/flutter_test.dart';
import 'package:karton_subs/widgets/category_icons.dart';

/// Słownik ikon kategorii. `categoryIcon` ma domyślkę („folder"), więc literówka
/// w nazwie nie wywala się — po prostu pokazuje folder. Te testy to wyłapują.
void main() {
  test('każda ikona z listy wyboru ma swoje odwzorowanie', () {
    final fallback = categoryIcon('nazwa-ktorej-nie-ma');
    final onFallback = availableIconNames
        .where((n) => n != 'folder' && categoryIcon(n) == fallback)
        .toList();
    expect(onFallback, isEmpty, reason: 'te nazwy spadają na domyślny folder');
  });

  test('lista wyboru nie powtarza nazw', () {
    expect(availableIconNames.toSet().length, availableIconNames.length);
  });

  test('żadne dwie pozycje listy nie pokazują tej samej ikony', () {
    final icons = availableIconNames.map(categoryIcon).toList();
    expect(icons.toSet().length, icons.length);
  });

  test('stare nazwy z bazy nadal działają (aliasy)', () {
    // Kategorie zapisane wcześniej trzymają nazwy w innym zapisie — migracji
    // nie ma, więc aliasy muszą trafiać w te same ikony co nazwy kanoniczne.
    expect(categoryIcon('play-circle'), categoryIcon('play_circle'));
    expect(categoryIcon('gamepad-2'), categoryIcon('gamepad2'));
    expect(categoryIcon('fitness_center'), categoryIcon('dumbbell'));
    expect(categoryIcon('school'), categoryIcon('graduationCap'));
    expect(categoryIcon('cart'), categoryIcon('shoppingCart'));
    expect(categoryIcon('shoppingBag'), categoryIcon('shopping'));
    expect(categoryIcon('food'), categoryIcon('utensils'));
    expect(categoryIcon('child'), categoryIcon('baby'));
    expect(categoryIcon('paw'), categoryIcon('dog'));
  });

  test('nowe ikony przyjmują zapis z myślnikiem (tak je podaje Lucide)', () {
    expect(categoryIcon('party-popper'), categoryIcon('partyPopper'));
    expect(categoryIcon('soap-dispenser-droplet'),
        categoryIcon('soapDispenserDroplet'));
    expect(categoryIcon('swatch-book'), categoryIcon('swatchBook'));
    expect(categoryIcon('tent-tree'), categoryIcon('tentTree'));
    expect(categoryIcon('tree-palm'), categoryIcon('treePalm'));
    expect(categoryIcon('train-front'), categoryIcon('trainFront'));
    expect(categoryIcon('flower-2'), categoryIcon('flower2'));
  });
}
