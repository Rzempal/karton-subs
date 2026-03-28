import 'subscription.dart';

/// Szablon Quick Add — dane do wstępnego wypełnienia formularza.
class SubscriptionTemplate {
  final String name;
  final double amount;
  final Currency currency;
  final BillingCycle billingCycle;
  final String categoryId;
  final String colorHex;
  final String? cancellationUrl;

  const SubscriptionTemplate({
    required this.name,
    required this.amount,
    this.currency = Currency.PLN,
    this.billingCycle = BillingCycle.monthly,
    required this.categoryId,
    required this.colorHex,
    this.cancellationUrl,
  });
}

/// Predefiniowane szablony z cenami w PLN (marzec 2026).
/// CategoryIds zgodne z defaultCategories w category.dart.
class QuickAddTemplates {
  static const List<SubscriptionTemplate> all = [
    // Streaming
    SubscriptionTemplate(name: 'Netflix',       amount: 43,  categoryId: 'cat_streaming', colorHex: '#E50914'),
    SubscriptionTemplate(name: 'HBO Max',        amount: 30,  categoryId: 'cat_streaming', colorHex: '#5822B4'),
    SubscriptionTemplate(name: 'Disney+',        amount: 38,  categoryId: 'cat_streaming', colorHex: '#113CCF'),
    SubscriptionTemplate(name: 'Amazon Prime',   amount: 49,  categoryId: 'cat_streaming', colorHex: '#00A8E1'),

    // Muzyka
    SubscriptionTemplate(name: 'Spotify',        amount: 24,  categoryId: 'cat_music',     colorHex: '#1DB954'),
    SubscriptionTemplate(name: 'YouTube Premium',amount: 27,  categoryId: 'cat_music',     colorHex: '#FF0000'),
    SubscriptionTemplate(name: 'Tidal',          amount: 20,  categoryId: 'cat_music',     colorHex: '#000000'),
    SubscriptionTemplate(name: 'Apple Music',    amount: 22,  categoryId: 'cat_music',     colorHex: '#FA243C'),

    // Cloud
    SubscriptionTemplate(name: 'iCloud+',        amount: 4,   categoryId: 'cat_cloud',     colorHex: '#3693F5'),
    SubscriptionTemplate(name: 'Google One',     amount: 9,   categoryId: 'cat_cloud',     colorHex: '#4285F4'),
    SubscriptionTemplate(name: 'Dropbox Plus',   amount: 48,  categoryId: 'cat_cloud',     colorHex: '#0061FF'),

    // Software
    SubscriptionTemplate(name: 'Microsoft 365', amount: 30,  categoryId: 'cat_software',  colorHex: '#D83B01'),
    SubscriptionTemplate(name: 'Adobe CC',       amount: 240, categoryId: 'cat_software',  colorHex: '#FF0000'),
    SubscriptionTemplate(name: 'ChatGPT Plus',   amount: 92,  categoryId: 'cat_software',  colorHex: '#10A37F'),

    // Gaming
    SubscriptionTemplate(name: 'Xbox Game Pass', amount: 55,  categoryId: 'cat_gaming',    colorHex: '#107C10'),
    SubscriptionTemplate(name: 'PS Plus',        amount: 35,  categoryId: 'cat_gaming',    colorHex: '#003791'),
    SubscriptionTemplate(
      name: 'Nintendo Online',
      amount: 80,
      billingCycle: BillingCycle.yearly,
      categoryId: 'cat_gaming',
      colorHex: '#E60012',
    ),

    // Fitness
    SubscriptionTemplate(name: 'Strava Premium', amount: 32,  categoryId: 'cat_fitness',   colorHex: '#FC4C02'),
  ];

  /// Szablony pogrupowane po categoryId.
  static Map<String, List<SubscriptionTemplate>> get byCategory {
    final map = <String, List<SubscriptionTemplate>>{};
    for (final t in all) {
      map.putIfAbsent(t.categoryId, () => []).add(t);
    }
    return map;
  }
}
