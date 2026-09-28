/// Supabase connection settings, compiled in with
/// `--dart-define-from-file=.env.app`.
///
/// Only client-safe values belong here: the project URL and the publishable
/// key. Row-level security is what protects the data. Service-role and AI keys
/// must never be passed to the app.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static void ensureConfigured() {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Supabase is not configured. Copy .env.app.example to .env.app, fill '
        'it in, and run: flutter run --dart-define-from-file=.env.app',
      );
    }
  }
}
