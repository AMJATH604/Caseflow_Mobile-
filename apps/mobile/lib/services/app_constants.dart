import '../utils/env_config.dart';

/// Application-wide constants.
///
/// **Security:** Only Supabase connection credentials are exposed here.
/// Third-party API keys (Gemini, iLovePDF) are stored as Supabase Edge
/// Function secrets and accessed exclusively through server-side proxies.
class AppConstants {
  static const String appName = "CaseFlow";
  static const String appTagline = "Next-Gen Legal Management";

  // Supabase Configuration (anon key — safe for client)
  static const String supabaseUrl = EnvConfig.supabaseUrl;
  static const String supabaseAnonKey = EnvConfig.supabaseAnonKey;
}
