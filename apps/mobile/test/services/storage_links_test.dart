import 'package:caseflow/services/app_constants.dart';
import 'package:caseflow/services/storage_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = '${AppConstants.supabaseUrl}/storage/v1/object';

  group('StorageLinks.parse', () {
    test('recognises a public link to a private bucket', () {
      final ref = StorageLinks.parse(
        '$base/public/chat-attachments/dms/abc-123/photo_1.jpg',
      );
      expect(ref, isNotNull);
      expect(ref!.bucket, 'chat-attachments');
      expect(ref.path, 'dms/abc-123/photo_1.jpg');
    });

    test('decodes percent-encoded file names', () {
      final ref = StorageLinks.parse(
        '$base/public/case-documents/case-1/DVC%20Withdrawal%20Memo.pdf',
      );
      expect(ref!.path, 'case-1/DVC Withdrawal Memo.pdf');
    });

    test('recognises signed and authenticated link shapes', () {
      expect(
        StorageLinks.parse('$base/sign/commission-evidence/c1/v1/e.jpg?token=x')
            ?.path,
        'c1/v1/e.jpg',
      );
      expect(
        StorageLinks.parse('$base/authenticated/payment-receipts/u/c/1.png')
            ?.bucket,
        'payment-receipts',
      );
    });

    test('leaves public buckets alone', () {
      expect(StorageLinks.parse('$base/public/bare_acts/ipc.pdf'), isNull);
      expect(
        StorageLinks.parse('$base/public/profile-photos/u1/avatar.jpg?v=1'),
        isNull,
      );
    });

    test('leaves other sites alone', () {
      expect(
        StorageLinks.parse(
          'https://example.com/storage/v1/object/public/chat-attachments/a.jpg',
        ),
        isNull,
      );
      expect(StorageLinks.parse('https://www.livelaw.in/image.jpg'), isNull);
    });

    test('ignores malformed storage links', () {
      expect(StorageLinks.parse('$base/public/chat-attachments'), isNull);
      expect(StorageLinks.parse('not a url'), isNull);
    });
  });
}
