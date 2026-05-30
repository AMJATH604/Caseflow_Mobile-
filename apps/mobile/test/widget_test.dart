// Basic Flutter widget smoke test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test - verifying testing framework', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('CaseFlow'),
          ),
        ),
      ),
    );

    expect(find.text('CaseFlow'), findsOneWidget);
    expect(find.text('Nonexistent Text'), findsNothing);
  });
}
