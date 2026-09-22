import 'package:flutter_test/flutter_test.dart';

import 'package:caseflow/utils/env_config.dart';

// These run with no --dart-define, which is the undefined case. The empty
// case — a define present but blank — cannot be reproduced from inside the
// same test run, because dart-defines are fixed at compile time. What is
// asserted here is the property that matters either way: whatever the build
// was given, the app never starts with a blank URL or key.
//
// The empty case is not hypothetical. Both build workflows pass
//   --dart-define=SUPABASE_PUBLISHABLE_KEY="${{ secrets.… }}"
// and an unset GitHub secret expands to "", which String.fromEnvironment
// treats as a value rather than falling back to its default. A build made
// that way shipped a blank key and every request returned 401.
//
// To check the empty case by hand:
//   flutter test test/utils/env_config_test.dart \
//     --dart-define=SUPABASE_PUBLISHABLE_KEY= \
//     --dart-define=SUPABASE_URL=
// These tests must still pass.
void main() {
  group('EnvConfig', () {
    test('never resolves to a blank URL', () {
      expect(EnvConfig.supabaseUrl, isNotEmpty);
      expect(EnvConfig.supabaseUrl.trim(), EnvConfig.supabaseUrl);
    });

    test('never resolves to a blank key', () {
      expect(EnvConfig.supabaseAnonKey, isNotEmpty);
      expect(EnvConfig.supabaseAnonKey.trim(), EnvConfig.supabaseAnonKey);
    });

    test('URL is a usable https origin', () {
      final uri = Uri.tryParse(EnvConfig.supabaseUrl);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, isNotEmpty);
      // A trailing slash doubles up when paths are appended to it.
      expect(EnvConfig.supabaseUrl.endsWith('/'), isFalse);
    });

    test('the key is a publishable key, never a legacy JWT', () {
      // The legacy anon key shares a signing secret with the service_role key
      // that leaked into this repository, so both are being retired together.
      // A JWT here would mean a build is still on the key being killed.
      expect(
        EnvConfig.supabaseAnonKey.startsWith('eyJ'),
        isFalse,
        reason: 'looks like a legacy JWT anon key, not sb_publishable_…',
      );
      expect(EnvConfig.supabaseAnonKey.startsWith('sb_publishable_'), isTrue);
    });

    test('the key is never a secret key', () {
      // A secret key in the client binary would bypass RLS for anyone who
      // unpacked the app.
      expect(EnvConfig.supabaseAnonKey.contains('sb_secret_'), isFalse);
      expect(EnvConfig.supabaseAnonKey.contains('service_role'), isFalse);
    });

    test('isConfigured agrees with the resolved values', () {
      expect(EnvConfig.isConfigured, isTrue);
    });
  });
}
