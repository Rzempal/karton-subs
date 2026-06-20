/// Konfiguracja build-time (--dart-define=CHANNEL=internal|production).
///
/// ZMIEN:
///   1. _baseReleasesUrl → twoja domena + nazwa aplikacji
///   2. remoteReleasePath → sciezka na serwerze (uzywana przez deploy.ps1)
class AppConfig {
  static const String channel = String.fromEnvironment(
    'CHANNEL',
    defaultValue: 'production',
  );

  static bool get isInternal => channel == 'internal';

  // >>> ZMIEN na swoja domene i nazwe aplikacji <<<
  static const String _baseReleasesUrl =
      'https://your-domain.example.com/releases/NAZWA-APLIKACJI';

  static String get versionJsonUrl => isInternal
      ? '$_baseReleasesUrl/internal/version-internal.json'
      : '$_baseReleasesUrl/version.json';

  // >>> ZMIEN sciezke na serwerze <<<
  static String get remoteReleasePath => isInternal
      ? '/home/your_username/domains/your-domain.example.com/public_html/releases/NAZWA-APLIKACJI/internal/'
      : '/home/your_username/domains/your-domain.example.com/public_html/releases/NAZWA-APLIKACJI/';
}
