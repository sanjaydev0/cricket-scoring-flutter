/// Build-time configuration, supplied with `--dart-define` so no key is ever
/// committed to the repository.
///
/// ```bash
/// flutter build apk --release \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
/// ```
///
/// Absent values simply disable online rooms: the app builds and runs exactly
/// as it always has, which is why the default is "not configured" rather than
/// an error.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project's *publishable* key (Settings -> API). The legacy `anon` JWT
  /// also works. Never the service_role key — that bypasses row level security
  /// and must never ship inside an app.
  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static const String supabaseAnonKeyFallback =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get key => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKeyFallback;

  static bool get onlineRoomsEnabled =>
      supabaseUrl.isNotEmpty && key.isNotEmpty;
}
