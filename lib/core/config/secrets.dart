/// Runtime secrets for external services.
///
/// Never commit real values to source control. Instead, inject them at
/// build time, either inline:
///
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
///
/// or via a JSON file (see `env.json.example` in the repository root):
///
///   flutter run --dart-define-from-file=env.json
///
/// Get the values at https://supabase.com -> your project -> Settings -> API.
///
/// Notes:
///  - The Supabase "publishable" (formerly "anon") key is safe to embed in a
///    client app; authorization is enforced by Row Level Security (RLS).
///  - The AI (Gemini) API key is NOT kept here. For security it lives on the
///    server as a Supabase Edge Function secret:
///      supabase secrets set GEMINI_API_KEY=...
class Secrets {
  Secrets._();

  /// Compiled-in values, empty by default. The app shows its
  /// "setup required" screen until both values are provided.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
}
