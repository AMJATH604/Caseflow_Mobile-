import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/document_tools/pdf_engine.dart' show DocumentToolException;
import 'package:caseflow/services/document_tools/document_files.dart';

void main() {
  group('safeFileName', () {
    test('keeps ordinary names and adds the extension', () {
      expect(safeFileName('Vakalat (signed).pdf'), 'Vakalat (signed).pdf');
      expect(safeFileName('Plaint'), 'Plaint.pdf');
    });

    test('replaces characters that break paths', () {
      expect(safeFileName('O.S. 12/2026: Plaint'), 'O.S. 12_2026_ Plaint.pdf');
      expect(safeFileName(r'a\b*c?.pdf'), 'a_b_c_.pdf');
    });

    test('never returns an empty name', () {
      expect(safeFileName('   '), 'document.pdf');
    });

    test('shortens very long names', () {
      expect(safeFileName('x' * 200).length, 84);
    });
  });

  group('uniqueFileName', () {
    test('keeps a free name', () {
      expect(uniqueFileName('a.pdf', ['b.pdf']), 'a.pdf');
    });

    test('numbers a taken name, ignoring case', () {
      expect(uniqueFileName('a.pdf', ['A.pdf', 'a (2).pdf']), 'a (3).pdf');
    });
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(5 * 1024 * 1024 + 300000), '5.3 MB');
  });

  test('baseName', () {
    expect(baseName('Petition.final.pdf'), 'Petition.final');
    expect(baseName('.hidden'), '.hidden');
  });

  test('checkCaseDocumentSize allows 50 MB and refuses more', () {
    DocumentFiles.checkCaseDocumentSize(ToolFile('ok.pdf', Uint8List(maxCaseDocumentBytes)));
    expect(
      () => DocumentFiles.checkCaseDocumentSize(
        ToolFile('big.pdf', Uint8List(maxCaseDocumentBytes + 1)),
      ),
      throwsA(isA<DocumentToolException>()),
    );
  });
}
