import '../utils/env_config.dart';

class AppConstants {
  static const String appName = "CaseFlow";
  static const String appTagline = "Next-Gen Legal Management";
  
  // Supabase Configuration
  static const String supabaseUrl = EnvConfig.supabaseUrl;
  static const String supabaseAnonKey = EnvConfig.supabaseAnonKey;

  // iLovePDF Configuration
  static const String iLovePdfPublicKey = EnvConfig.iLovePdfPublicKey;
  static const String iLovePdfSecretKey = EnvConfig.iLovePdfSecretKey;

  // Gemini AI Configuration
  static const String geminiApiKey = EnvConfig.geminiApiKey;
}

