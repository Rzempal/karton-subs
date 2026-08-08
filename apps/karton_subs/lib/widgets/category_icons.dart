import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;

/// Ikony kategorii — słownik wspólny dla subskrypcji, pozycji budżetu i ekranu
/// zarządzania kategoriami. Mieszkały przy karcie subskrypcji, ale z kategorii
/// korzysta dziś każda lista, a wiersz subskrypcji potrzebuje formatowania
/// z `budget_widgets` (import w drugą stronę zapętliłby oba pliki).
///
/// Dwie paczki Lucide: `lucide_icons` (starsza, większość zestawu) i
/// `lucide_icons_flutter` (nowsza — ma ikony, których tamta nie zna, np. `drill`,
/// `tent-tree`, `train-front`, `volleyball`). Obie fonty są w APK i aplikacja
/// używa ich obok siebie także poza tym plikiem.

/// Mapuje nazwę ikony na [IconData] (Lucide).
///
/// Nazwa kanoniczna to nazwa z Lucide w camelCase; warianty z myślnikiem
/// i skróty są przyjmowane jako aliasy, bo w bazie siedzą nazwy zapisane
/// wcześniej i nie ma po co ich migrować.
IconData categoryIcon(String? name) {
  return switch (name) {
    // ── Dom i wydatki bieżące ──
    'home' => LucideIcons.home,
    'bed' => LucideIcons.bed,
    'zap' => LucideIcons.zap,
    'wifi' => LucideIcons.wifi,
    'phone' => LucideIcons.phone,
    'mail' => LucideIcons.mail,
    'drill' || 'tools' => lucide.LucideIcons.drill,
    'soapDispenserDroplet' || 'soap-dispenser-droplet' || 'soap' =>
      lucide.LucideIcons.soapDispenserDroplet,
    'swatchBook' || 'swatch-book' || 'swatch' => lucide.LucideIcons.swatchBook,

    // ── Zakupy i jedzenie ──
    'shoppingCart' || 'cart' => LucideIcons.shoppingCart,
    'shopping' || 'shoppingBag' => LucideIcons.shoppingBag,
    'utensils' || 'food' => LucideIcons.utensils,
    'coffee' => LucideIcons.coffee,
    'shirt' || 'clothes' => LucideIcons.shirt,

    // ── Transport i podróże ──
    'car' => LucideIcons.car,
    'fuel' => LucideIcons.fuel,
    'bike' => LucideIcons.bike,
    'trainFront' || 'train-front' || 'train' => lucide.LucideIcons.trainFront,
    'plane' => LucideIcons.plane,
    'tentTree' || 'tent-tree' || 'tent' => lucide.LucideIcons.tentTree,
    'treePalm' || 'tree-palm' || 'palm' => lucide.LucideIcons.treePalm,
    'camera' => LucideIcons.camera,

    // ── Zdrowie, sport i rodzina ──
    'heart' => LucideIcons.heart,
    'fitness_center' || 'dumbbell' => LucideIcons.dumbbell,
    'volleyball' || 'ball' => lucide.LucideIcons.volleyball,
    'baby' || 'child' => LucideIcons.baby,
    'dog' || 'pet' || 'paw' => LucideIcons.dog,
    'flower2' || 'flower-2' || 'flower' => LucideIcons.flower2,
    'gift' => LucideIcons.gift,
    'partyPopper' || 'party-popper' || 'party' => LucideIcons.partyPopper,

    // ── Rozrywka i media ──
    'play_circle' || 'play-circle' => LucideIcons.playCircle,
    'tv' => LucideIcons.tv,
    'music' => LucideIcons.music,
    'headphones' => LucideIcons.headphones,
    'sports_esports' || 'gamepad-2' || 'gamepad2' => LucideIcons.gamepad2,
    'book' => LucideIcons.bookOpen,

    // ── Praca, nauka i technika ──
    'code' => LucideIcons.code,
    'cloud' => LucideIcons.cloud,
    'globe' => LucideIcons.globe,
    'brain' => LucideIcons.brain,
    'school' || 'graduation-cap' || 'graduationCap' => LucideIcons.graduationCap,
    'shield' => LucideIcons.shield,

    // ── Pozostałe ──
    'receipt' => LucideIcons.receipt,
    'star' => LucideIcons.star,
    _ => LucideIcons.folder,
  };
}

/// Ikony do wyboru w Ustawieniach — kolejność jest tematyczna (dom, zakupy,
/// transport, zdrowie, rozrywka, praca), żeby przy kilkudziesięciu pozycjach
/// dało się szukać wzrokiem, a nie tylko przewijać.
const List<String> availableIconNames = [
  // Dom i wydatki bieżące
  'home', 'bed', 'zap', 'wifi', 'phone', 'mail',
  'drill', 'soapDispenserDroplet', 'swatchBook',
  // Zakupy i jedzenie
  'shoppingCart', 'shopping', 'utensils', 'coffee', 'shirt',
  // Transport i podróże
  'car', 'fuel', 'bike', 'trainFront', 'plane', 'tentTree', 'treePalm', 'camera',
  // Zdrowie, sport i rodzina
  'heart', 'dumbbell', 'volleyball', 'baby', 'dog', 'flower2', 'gift',
  'partyPopper',
  // Rozrywka i media
  'play_circle', 'tv', 'music', 'headphones', 'gamepad2', 'book',
  // Praca, nauka i technika
  'code', 'cloud', 'globe', 'brain', 'graduationCap', 'shield',
  // Pozostałe
  'receipt', 'star', 'folder',
];
