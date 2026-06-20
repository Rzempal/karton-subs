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

  /// Remote path — used only by deploy.ps1, read from .env at deploy time.
  /// Kept here for backward compatibility until migration to GitHub Releases.
  static String get remoteReleasePath => isInternal
      ? const String.fromEnvironment('DEPLOY_REMOTE_INTERNAL', defaultValue: '')
      : const String.fromEnvironment('DEPLOY_REMOTE_PROD', defaultValue: '');

  // ── Synchronizacja budzetu domowego (relay E2E, ADR-009) ─────────────────────
  // Skrzynka relay = projekt Supabase "karton-subs-sync". Wartosci sa JAWNE z
  // zalozenia: klucz "publishable" jest projektowany do umieszczenia w aplikacji.
  // Dane chroni dostep przez RPC (sync_pull/sync_push po sekretnym household_id)
  // + szyfrowanie E2E (serwer nie odczytuje tresci). Patrz docs/security.md.
  static const String syncRelayUrl = 'https://yhcowgjxhbiyeraqdpor.supabase.co';
  static const String syncRelayKey =
      'sb_publishable_PIvE9n0YC3aVcHbU0cG2xw_0PcN6e-b';
}
