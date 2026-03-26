/// Konfiguracja build-time (--dart-define=CHANNEL=internal|production).
/// Port z APPteczka — zmienione URL-e na domenę karton-subs.
class AppConfig {
  static const String channel = String.fromEnvironment(
    'CHANNEL',
    defaultValue: 'production',
  );

  static bool get isInternal => channel == 'internal';

  static const String _baseReleasesUrl =
      'https://michalrapala.app/releases/karton-subs';

  static String get versionJsonUrl => isInternal
      ? '$_baseReleasesUrl/internal/version-internal.json'
      : '$_baseReleasesUrl/version.json';

  static String get remoteReleasePath => isInternal
      ? '/home/host361978/domains/michalrapala.app/public_html/releases/karton-subs/internal/'
      : '/home/host361978/domains/michalrapala.app/public_html/releases/karton-subs/';
}
