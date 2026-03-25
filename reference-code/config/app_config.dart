// REFERENCE: Ten plik pochodzi z "Karton z lekami" (APPteczka).
// Reusable: wzorzec konfiguracji build-time (--dart-define=CHANNEL=X).
// Do wymiany: URL-e (baseReleasesUrl, remotePath) na nowa domene.

/// Configuration based on build flavor/channel.
class AppConfig {
  /// Channel name passed via --dart-define=CHANNEL=internal|production
  static const String channel = String.fromEnvironment(
    'CHANNEL',
    defaultValue: 'production',
  );

  /// Whether this is an internal (dev) build.
  static bool get isInternal => channel == 'internal';

  /// Base URL for releases on the server.
  static const String _baseReleasesUrl = 'https://michalrapala.app/releases';

  /// URL for version.json based on channel.
  static String get versionJsonUrl => isInternal
      ? '$_baseReleasesUrl/internal/version-internal.json'
      : '$_baseReleasesUrl/version.json';

  /// Remote directory path for uploads.
  static String get remoteReleasePath => isInternal
      ? '/home/host361978/domains/michalrapala.app/public_html/releases/internal/'
      : '/home/host361978/domains/michalrapala.app/public_html/releases/';
}
