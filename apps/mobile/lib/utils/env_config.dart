class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String iLovePdfPublicKey = String.fromEnvironment(
    'ILOVEPDF_PUBLIC_KEY',
    defaultValue: '',
  );

  static const String iLovePdfSecretKey = String.fromEnvironment(
    'ILOVEPDF_SECRET_KEY',
    defaultValue: '',
  );

  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  // Gemini AI Configuration
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // Validation helper
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      iLovePdfPublicKey.isNotEmpty &&
      iLovePdfSecretKey.isNotEmpty &&
      razorpayKeyId.isNotEmpty;
}
