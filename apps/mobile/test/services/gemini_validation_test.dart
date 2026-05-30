import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/gemini_service.dart';

/// Tests for the Gemini service client-side input validation.
void main() {
  group('GeminiService.validatePrompt', () {
    test('empty string returns error', () {
      expect(GeminiService.validatePrompt(''), isNotNull);
      expect(GeminiService.validatePrompt('   '), isNotNull);
    });

    test('normal message returns null (valid)', () {
      expect(GeminiService.validatePrompt('What is Section 302 IPC?'), isNull);
    });

    test('message at max length is valid', () {
      final longMsg = 'a' * 10000;
      expect(GeminiService.validatePrompt(longMsg), isNull);
    });

    test('message exceeding max length returns error', () {
      final tooLong = 'a' * 10001;
      final result = GeminiService.validatePrompt(tooLong);
      expect(result, isNotNull);
      expect(result, contains('too long'));
    });

    test('normal legal question passes', () {
      expect(
        GeminiService.validatePrompt(
          'What is the limitation period for a civil suit under Section 3 of the Limitation Act, 1963?',
        ),
        isNull,
      );
    });
  });
}
