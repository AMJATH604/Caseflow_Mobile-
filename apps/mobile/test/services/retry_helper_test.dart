import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/retry_helper.dart';

void main() {
  group('RetryHelper', () {
    test('succeeds on first attempt', () async {
      int attempts = 0;
      final result = await RetryHelper.retry(() async {
        attempts++;
        return 'success';
      });
      expect(result, 'success');
      expect(attempts, 1);
    });

    test('retries on failure and eventually succeeds', () async {
      int attempts = 0;
      final result = await RetryHelper.retry(() async {
        attempts++;
        if (attempts < 3) throw Exception('Simulated failure');
        return 'recovered';
      }, maxRetries: 3);
      expect(result, 'recovered');
      expect(attempts, 3);
    });

    test('throws after exhausting all retries', () async {
      int attempts = 0;
      expect(
        () => RetryHelper.retry(
          () async {
            attempts++;
            throw Exception('Persistent failure');
          },
          maxRetries: 2,
        ),
        throwsException,
      );
      expect(attempts, greaterThanOrEqualTo(2));
    });

    test('respects custom maxRetries', () async {
      int attempts = 0;
      try {
        await RetryHelper.retry(
          () async {
            attempts++;
            throw Exception('fail');
          },
          maxRetries: 5,
        );
      } catch (_) {}
      // Should have tried 5 times (or until maxRetries is exhausted)
      expect(attempts, greaterThanOrEqualTo(5));
    });
  });
}
