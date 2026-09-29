import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/document_tools/signature_store.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('signatures');
    SignatureStore.directory = () async => Directory('${temp.path}/signatures');
  });

  tearDown(() => temp.delete(recursive: true));

  test('starts empty', () async {
    expect(await SignatureStore.list(), isEmpty);
  });

  test('keeps the newest four, newest first', () async {
    for (var i = 1; i <= 6; i++) {
      await SignatureStore.add(Uint8List.fromList([i]));
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final saved = await SignatureStore.list();
    expect([for (final s in saved) s.png.single], [6, 5, 4, 3]);
  });

  test('deletes one', () async {
    await SignatureStore.add(Uint8List.fromList([1]));
    final id = (await SignatureStore.list()).single.id;
    await SignatureStore.delete(id);
    expect(await SignatureStore.list(), isEmpty);
  });
}
