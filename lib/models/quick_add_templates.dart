// quick_add_templates.dart v0.001 Predefiniowane szablony subskrypcji PL-centric

import 'subscription.dart';

/// Szablon Quick Add — dane do wstępnego wypełnienia formularza
class SubscriptionTemplate {
  final String name;
  final double amount;
  final Currency currency;
  final BillingCycle billingCycle;
  final String categoryId;
  final String iconName;
  final String color;
  final String? cancellationUrl;

  const SubscriptionTemplate({
    required this.name,
    required this.amount,
    this.currency = Currency.PLN,
    this.billingCycle = BillingCycle.monthly,
    required this.categoryId,
    required this.iconName,
    required this.color,
    this.cancellationUrl,
  });
}

/// Predefiniowane szablony z cenami w PLN (marzec 2026)
class QuickAddTemplates {
  static const List<SubscriptionTemplate> all = [
    // Streaming
    SubscriptionTemplate(
      name: 'Netflix',
      amount: 43,
      categoryId: 'cat-streaming',
      iconName: 'tv',
      color: '#E50914',
    ),
    SubscriptionTemplate(
      name: 'HBO Max',
      amount: 30,
      categoryId: 'cat-streaming',
      iconName: 'film',
      color: '#5822B4',
    ),
    SubscriptionTemplate(
      name: 'Disney+',
      amount: 38,
      categoryId: 'cat-streaming',
      iconName: 'play-circle',
      color: '#113CCF',
    ),
    SubscriptionTemplate(
      name: 'Amazon Prime',
      amount: 49,
      categoryId: 'cat-streaming',
      iconName: 'play-circle',
      color: '#00A8E1',
    ),

    // Muzyka
    SubscriptionTemplate(
      name: 'Spotify',
      amount: 24,
      categoryId: 'cat-music',
      iconName: 'music',
      color: '#1DB954',
    ),
    SubscriptionTemplate(
      name: 'YouTube Premium',
      amount: 27,
      categoryId: 'cat-music',
      iconName: 'play-circle',
      color: '#FF0000',
    ),
    SubscriptionTemplate(
      name: 'Tidal',
      amount: 20,
      categoryId: 'cat-music',
      iconName: 'headphones',
      color: '#000000',
    ),
    SubscriptionTemplate(
      name: 'Apple Music',
      amount: 22,
      categoryId: 'cat-music',
      iconName: 'music',
      color: '#FA243C',
    ),

    // Chmura
    SubscriptionTemplate(
      name: 'iCloud+',
      amount: 4,
      categoryId: 'cat-cloud',
      iconName: 'cloud',
      color: '#3693F5',
    ),
    SubscriptionTemplate(
      name: 'Google One',
      amount: 9,
      categoryId: 'cat-cloud',
      iconName: 'cloud',
      color: '#4285F4',
    ),
    SubscriptionTemplate(
      name: 'Dropbox Plus',
      amount: 48,
      categoryId: 'cat-cloud',
      iconName: 'cloud',
      color: '#0061FF',
    ),

    // Oprogramowanie
    SubscriptionTemplate(
      name: 'Microsoft 365',
      amount: 30,
      categoryId: 'cat-software',
      iconName: 'monitor',
      color: '#D83B01',
    ),
    SubscriptionTemplate(
      name: 'Adobe Creative Cloud',
      amount: 240,
      categoryId: 'cat-software',
      iconName: 'code',
      color: '#FF0000',
    ),
    SubscriptionTemplate(
      name: 'ChatGPT Plus',
      amount: 92,
      categoryId: 'cat-software',
      iconName: 'globe',
      color: '#10A37F',
    ),

    // Gaming
    SubscriptionTemplate(
      name: 'Xbox Game Pass',
      amount: 55,
      categoryId: 'cat-gaming',
      iconName: 'gamepad-2',
      color: '#107C10',
    ),
    SubscriptionTemplate(
      name: 'PlayStation Plus',
      amount: 35,
      billingCycle: BillingCycle.monthly,
      categoryId: 'cat-gaming',
      iconName: 'gamepad-2',
      color: '#003791',
    ),
    SubscriptionTemplate(
      name: 'Nintendo Switch Online',
      amount: 80,
      billingCycle: BillingCycle.yearly,
      categoryId: 'cat-gaming',
      iconName: 'gamepad-2',
      color: '#E60012',
    ),

    // Fitness
    SubscriptionTemplate(
      name: 'Strava Premium',
      amount: 32,
      categoryId: 'cat-fitness',
      iconName: 'dumbbell',
      color: '#FC4C02',
    ),
  ];
}
