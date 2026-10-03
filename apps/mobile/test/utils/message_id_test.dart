import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/utils/message_id.dart';

void main() {
  test('message ids are version-4 UUIDs the database accepts', () {
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    for (var i = 0; i < 200; i++) {
      expect(newMessageId(), matches(uuid));
    }
  });

  test('message ids do not repeat', () {
    final ids = {for (var i = 0; i < 5000; i++) newMessageId()};
    expect(ids.length, 5000);
  });
}
