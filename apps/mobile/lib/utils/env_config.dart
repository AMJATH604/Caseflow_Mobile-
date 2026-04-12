class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://asrjqsnyezvcakvkokcl.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzcmpxc255ZXp2Y2Frdmtva2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5NTQ1MjYsImV4cCI6MjA4NzUzMDUyNn0._W7YwzwxA2m83VxITvQMDVUSbTlnJi1Ij389Sxp-Mls',
  );

  static const String iLovePdfPublicKey = String.fromEnvironment(
    'ILOVEPDF_PUBLIC_KEY',
    defaultValue: 'project_public_d3b01c34a2e8c25dbcbbfebde8b631d8_d7uL593fbfafde66c8913b5fe4a3deed7fe02',
  );

  static const String iLovePdfSecretKey = String.fromEnvironment(
    'ILOVEPDF_SECRET_KEY',
    defaultValue: 'secret_key_84c7e6c430a91f53198de7e5ebf1f33f_Zg_O04b5dfd1788c0356fb3ece29f8f4a2119',
  );

  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_placeholder',
  );

  // Gemini AI Configuration
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyB2qJNjxtped779XjzwDERZ1MQ32Hrt4cM',
  );

  // Validation helper
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      iLovePdfPublicKey.isNotEmpty &&
      iLovePdfSecretKey.isNotEmpty &&
      razorpayKeyId.isNotEmpty;
}
