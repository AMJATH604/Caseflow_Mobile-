import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    // These are static fire-and-forget methods that should never throw
    // even without Firebase initialized

    test('logScreenView should not throw', () async {
      await expectLater(
        AnalyticsService.logScreenView('TestScreen'),
        completes,
      );
    });

    test('logFeatureUsed should not throw', () async {
      await expectLater(
        AnalyticsService.logFeatureUsed('test_feature'),
        completes,
      );
    });

    test('logEvent should not throw', () async {
      await expectLater(
        AnalyticsService.logEvent('test_event', {'key': 'value'}),
        completes,
      );
    });

    test('logToolUsed should not throw', () async {
      await expectLater(
        AnalyticsService.logToolUsed('limitation_calculator'),
        completes,
      );
    });

    test('logAIQuerySent should not throw', () async {
      await expectLater(
        AnalyticsService.logAIQuerySent(hasAttachment: true),
        completes,
      );
    });
  });
}
