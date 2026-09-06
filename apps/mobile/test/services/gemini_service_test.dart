import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/gemini_service.dart';

void main() {
  group('GeminiService', () {
    late GeminiService service;

    setUp(() {
      service = GeminiService();
    });

    test('initial history should be empty', () {
      expect(service.history, isEmpty);
    });

    test('historyLoaded should be false initially', () {
      expect(service.historyLoaded, isFalse);
    });

    test('suggestedPrompts should return 6 prompts', () {
      final prompts = GeminiService.suggestedPrompts;
      expect(prompts.length, 6);
    });

    test('each suggested prompt should have icon, title, and prompt', () {
      for (final prompt in GeminiService.suggestedPrompts) {
        expect(prompt.containsKey('icon'), isTrue);
        expect(prompt.containsKey('title'), isTrue);
        expect(prompt.containsKey('prompt'), isTrue);
      }
    });

    test('clearHistory should empty the history', () async {
      // Note: clearHistory also tries to delete from DB, but without
      // Supabase initialized it will gracefully fail
      await service.clearHistory();
      expect(service.history, isEmpty);
      expect(service.historyLoaded, isFalse);
    });
  });

  group('ChatMessage', () {
    test('should create with required fields', () {
      final msg = ChatMessage(role: 'user', text: 'Hello');
      expect(msg.role, 'user');
      expect(msg.text, 'Hello');
      expect(msg.isLoading, isFalse);
      expect(msg.hasImage, isFalse);
    });

    test('should detect image presence', () {
      final msg = ChatMessage(
        role: 'user',
        text: 'Check this',
        imagePath: '/path/to/image.jpg',
      );
      expect(msg.hasImage, isTrue);
    });

    test('should set timestamp to now by default', () {
      final before = DateTime.now();
      final msg = ChatMessage(role: 'model', text: 'Response');
      final after = DateTime.now();
      
      expect(msg.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(msg.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}
