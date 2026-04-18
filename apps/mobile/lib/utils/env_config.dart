/// Environment configuration for CaseFlow.
///
/// **Security:** Only Supabase connection credentials are stored here.
/// All third-party API keys (Gemini, iLovePDF) are stored server-side
/// as Supabase Edge Function secrets and never reach the client binary.
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://asrjqsnyezvcakvkokcl.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzcmpxc255ZXp2Y2Frdmtva2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5NTQ1MjYsImV4cCI6MjA4NzUzMDUyNn0._W7YwzwxA2m83VxITvQMDVUSbTlnJi1Ij389Sxp-Mls',
  );

  // Validation helper
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
