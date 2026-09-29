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
  // ─── Why these are not plain String.fromEnvironment defaults ────────────
  //
  // `String.fromEnvironment('X', defaultValue: y)` returns the default only
  // when X is *undefined*. A define given an empty value is defined, so it
  // wins and the default never applies.
  //
  // CI reaches exactly that case. Both build workflows pass
  //   --dart-define=SUPABASE_PUBLISHABLE_KEY="${{ secrets.… }}"
  // and an unset GitHub secret expands to an empty string, so the build ships
  // with a blank key. Every request then comes back 401 "No API key found",
  // which the sign-in screen could only report as a generic failure.
  //
  // Treating empty as absent means a missing or blank secret falls back to
  // the working public key instead of producing a binary that cannot talk to
  // the backend at all. These stay `const`: string comparison and conditional
  // expressions are both allowed in a const context, so this is still folded
  // at compile time and the value is still a compile-time constant.

  static const String _urlDefine = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseUrl =
      _urlDefine != ''
          ? _urlDefine
          : 'https://asrjqsnyezvcakvkokcl.supabase.co';

  /// `--dart-define=SUPABASE_PUBLISHABLE_KEY=…` is preferred. The older
  /// `SUPABASE_ANON_KEY` define is still honoured so existing build commands
  /// keep working, but must be given the publishable key, not the legacy one.
  static const String _publishableDefine = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String _anonDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String supabaseAnonKey =
      _publishableDefine != ''
          ? _publishableDefine
          : (_anonDefine != ''
              ? _anonDefine
              : 'sb_publishable_g8UbCM_UoYqvLn8DbGIBCA_QGG3U9nT');

  /// The CaseFlow document server (Word→PDF, OCR, compression...), e.g.
  /// `https://tools.example.in`, given with `--dart-define=DOC_TOOLS_API_URL=…`.
  /// Empty when not set: the server-side tools are then hidden, so a build
  /// without a server never shows tools that cannot work.
  static const String docToolsApiUrl = String.fromEnvironment('DOC_TOOLS_API_URL');

  // Validation helper
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
