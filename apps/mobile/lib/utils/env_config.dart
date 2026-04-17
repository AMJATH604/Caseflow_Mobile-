/// Environment configuration for CaseFlow.
///
/// **Security:** Only Supabase connection credentials are stored here.
/// All third-party API keys (Gemini, iLovePDF) are stored server-side
/// as Supabase Edge Function secrets and never reach the client binary.
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Validation helper
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
