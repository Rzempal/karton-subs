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

  /// Remote path — used only by deploy_apk.ps1, read from .env at deploy time.
  /// Kept here for backward compatibility until migration to GitHub Releases.
  static String get remoteReleasePath => isInternal
      ? const String.fromEnvironment('DEPLOY_REMOTE_INTERNAL', defaultValue: '')
      : const String.fromEnvironment('DEPLOY_REMOTE_PROD', defaultValue: '');
}
