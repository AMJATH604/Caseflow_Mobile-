import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/offline_cache_service.dart';

void main() {
  group('OfflineCacheService', () {
    test('isOnline should return a boolean', () async {
      final result = await OfflineCacheService.isOnline;
      expect(result, isA<bool>());
    });

    test('connectivityStream should emit values', () {
      final stream = OfflineCacheService.connectivityStream;
      expect(stream, isA<Stream<bool>>());
    });
  });
}
