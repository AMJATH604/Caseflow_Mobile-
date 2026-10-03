import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caseflow/components/ai_chat/ai_chat_widgets.dart';
import 'package:caseflow/services/gemini_service.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  group('AiMessageBubble', () {
    testWidgets('an answer is shown while it streams, not hidden behind '
        '"thinking"', (tester) async {
      await _pump(
        tester,
        AiMessageBubble(
          message: ChatMessage(
            role: 'model',
            text: 'Section 138 applies',
            isLoading: true,
          ),
          isUser: false,
          isDark: false,
        ),
      );
      await tester.pump();
      expect(find.textContaining('Section 138 applies'), findsOneWidget);
      // Copy and Share wait for the finished answer.
      expect(find.byTooltip('Copy'), findsNothing);
    });

    testWidgets('a finished answer offers Copy and Share', (tester) async {
      await _pump(
        tester,
        AiMessageBubble(
          message: ChatMessage(role: 'model', text: 'Done.'),
          isUser: false,
          isDark: true,
        ),
      );
      await tester.pump();
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
    });

    testWidgets('your question appears once, as a bubble', (tester) async {
      await _pump(
        tester,
        AiMessageBubble(
          message: ChatMessage(role: 'user', text: 'What is bail?'),
          isUser: true,
          isDark: false,
        ),
      );
      await tester.pump();
      expect(find.text('What is bail?'), findsOneWidget);
    });
  });

  group('AiChatDrawer.groupOf', () {
    final now = DateTime(2026, 10, 3, 15);
    test('groups chats by when they were last used', () {
      expect(AiChatDrawer.groupOf(DateTime(2026, 10, 3, 9), now), 'Today');
      expect(AiChatDrawer.groupOf(DateTime(2026, 10, 2, 23), now), 'Yesterday');
      expect(AiChatDrawer.groupOf(DateTime(2026, 9, 28), now), 'Previous 7 days');
      expect(AiChatDrawer.groupOf(DateTime(2026, 9, 10), now), 'Previous 30 days');
      expect(AiChatDrawer.groupOf(DateTime(2026, 6, 1), now), 'Older');
    });
  });

  testWidgets('history search narrows the list', (tester) async {
    final now = DateTime.now();
    await _pump(
      tester,
      AiChatDrawer(
        isDark: false,
        sessions: [
          ChatSession(id: '1', title: 'Cheque bounce notice', createdAt: now, updatedAt: now),
          ChatSession(id: '2', title: 'Partition suit', createdAt: now, updatedAt: now),
        ],
        onNewChat: () {},
        onSelectSession: (_) {},
        onDeleteSession: (_) {},
      ),
    );
    await tester.pump();
    expect(find.text('Partition suit'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'cheque');
    await tester.pump();
    expect(find.text('Cheque bounce notice'), findsOneWidget);
    expect(find.text('Partition suit'), findsNothing);
  });
}
