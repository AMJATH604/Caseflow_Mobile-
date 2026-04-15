import 'secrets.dart';

class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: Secrets.supabaseUrl,
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: Secrets.supabaseAnonKey,
  );

  static const String iLovePdfPublicKey = String.fromEnvironment(
    'ILOVEPDF_PUBLIC_KEY',
    defaultValue: Secrets.iLovePdfPublicKey,
  );

  static const String iLovePdfSecretKey = String.fromEnvironment(
    'ILOVEPDF_SECRET_KEY',
    defaultValue: Secrets.iLovePdfSecretKey,
  );

  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: Secrets.razorpayKeyId,
  );

  // Gemini AI Configuration
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: Secrets.geminiApiKey,
  );

  // Validation helper
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      iLovePdfPublicKey.isNotEmpty &&
      iLovePdfSecretKey.isNotEmpty &&
      razorpayKeyId.isNotEmpty;
}
