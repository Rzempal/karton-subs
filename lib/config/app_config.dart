// app_config.dart v0.001 Konfiguracja build-time dla Karton Subs

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
  static const String _baseReleasesUrl =
      'https://michalrapala.app/releases/karton-subs';

  /// URL for version.json based on channel.
  static String get versionJsonUrl => isInternal
      ? '$_baseReleasesUrl/internal/version-internal.json'
      : '$_baseReleasesUrl/version.json';

  /// Remote directory path for uploads.
  static String get remoteReleasePath => isInternal
      ? '/home/your_username/domains/michalrapala.app/public_html/releases/karton-subs/internal/'
      : '/home/your_username/domains/michalrapala.app/public_html/releases/karton-subs/';

  /// Backup file extension
  static const String backupExtension = '.subkarton';

  /// App display name
  static const String appName = 'Karton na subskrypcje';
}
