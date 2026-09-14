/// Environment configuration for CaseFlow.
///
/// **Security:** Only Supabase connection credentials are stored here.
/// All third-party API keys (Gemini) are stored server-side
/// as Supabase Edge Function secrets and never reach the client binary.
///
/// The client key is the **publishable** key (`sb_publishable_…`). It is public
/// by design and protected by RLS. It replaces the legacy JWT `anon` key, which
/// is being retired together with the legacy `service_role` key after the
/// latter leaked into the repository. Both legacy keys share one signing secret
/// and can only be disabled together, so every client must move off the anon
/// key first.
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://asrjqsnyezvcakvkokcl.supabase.co',
  );

  /// `--dart-define=SUPABASE_PUBLISHABLE_KEY=…` is preferred. The older
  /// `SUPABASE_ANON_KEY` define is still honoured so existing build commands
  /// keep working, but must be given the publishable key, not the legacy one.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_g8UbCM_UoYqvLn8DbGIBCA_QGG3U9nT',
    ),
  );

  // Validation helper
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
