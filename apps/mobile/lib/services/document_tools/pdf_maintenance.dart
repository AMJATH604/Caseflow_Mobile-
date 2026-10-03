/// Protect, unlock, repair and compress, on the device.
///
/// Pure Dart; run through `DocumentToolsService`. Compression and the last
/// resort of repair also re-render pages, which the app does on the UI
/// isolate with the platform PDF renderer (see `PageRendering`).
library;

import 'dart:convert' show base64Url, latin1;
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_engine.dart';

class PdfProtection {
  PdfProtection._();

  /// Encrypts [pdf] with AES-256. [password] is needed to open it. The
  /// owner password (for changing permissions) is random and discarded, so
  /// it cannot be guessed from the user's; Unlock works with [password].
  static Uint8List protect(Uint8List pdf, String password) {
    if (password.length < 4) {
      throw const DocumentToolException('Use a password of at least 4 characters');
    }
    final doc = PdfEngine.open(pdf);
    try {
      if (_isEncrypted(pdf)) {
        throw const DocumentToolException(
          'This PDF already has a password. Unlock it first, then protect it again.',
        );
      }
      doc.security
        ..algorithm = PdfEncryptionAlgorithm.aesx256Bit
        ..userPassword = password
        ..ownerPassword = _randomSecret();
      doc.fileStructure.incrementalUpdate = false;
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }

  /// Removes the password (given the right one) and any print/copy/edit
  /// restrictions. A PDF that opens without a password but is restricted
  /// needs no password.
  static Uint8List unlock(Uint8List pdf, String password) {
    if (!_isEncrypted(pdf)) {
      throw const DocumentToolException('This PDF has no password or restrictions to remove.');
    }
    final PdfDocument doc;
    try {
      doc = PdfDocument(inputBytes: pdf, password: password);
    } on ArgumentError catch (e) {
      if (e.name == 'password' || '${e.message}'.toLowerCase().contains('password')) {
        throw DocumentToolException(
          password.isEmpty
              ? 'This PDF needs its password to open. Enter it and try again.'
              : 'That password is not correct.',
        );
      }
      throw const DocumentToolException('This PDF could not be read. Try Repair PDF first.');
    }
    try {
      // Empty passwords alone keep the file encrypted (with its print/copy
      // restrictions); clearing the permissions too removes encryption.
      doc.security
        ..userPassword = ''
        ..ownerPassword = ''
        ..permissions.clear();
      doc.fileStructure.incrementalUpdate = false;
      final out = Uint8List.fromList(doc.saveSync());
      if (_isEncrypted(out)) {
        throw const DocumentToolException('The password could not be removed from this PDF.');
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  static String _randomSecret() {
    final random = Random.secure();
    return base64Url.encode([for (var i = 0; i < 24; i++) random.nextInt(256)]);
  }

  /// Whether the file has an /Encrypt dictionary (password or restrictions).
  static bool isEncrypted(Uint8List pdf) => _isEncrypted(pdf);

  /// An /Encrypt entry in a trailer (or cross-reference stream) is what
  /// makes a PDF encrypted; the old dictionary object can linger unused.
  static bool _isEncrypted(Uint8List pdf) =>
      RegExp(r'/Encrypt\s*(\d+\s+\d+\s+R|<<)').hasMatch(_latin1(pdf));
}

class PdfRepair {
  PdfRepair._();

  /// Tries to make a damaged PDF readable: first as it is, then with its
  /// cross-reference table rebuilt from the objects actually in the file
  /// (what breaks most often: truncated downloads, bad edits). Returns a
  /// cleanly re-saved PDF, or null if neither worked (the app then falls
  /// back to re-rendering pages).
  static Uint8List? repair(Uint8List pdf) {
    for (final candidate in [pdf, rebuildCrossReference(pdf)]) {
      if (candidate == null) continue;
      final saved = _resave(candidate);
      if (saved != null) return saved;
    }
    return null;
  }

  /// [pdf] cut after its last complete object, with a new cross-reference
  /// table and trailer built by finding every "N G obj" in the file. The
  /// cut drops the broken table and trailer, which would otherwise still
  /// trip up readers. Null if no document catalog is found. Later copies
  /// of an object (incremental updates) win.
  static Uint8List? rebuildCrossReference(Uint8List pdf) {
    final text = _latin1(pdf);
    final lastEnd = text.lastIndexOf('endobj');
    if (lastEnd < 0) return null;
    final bodyEnd = lastEnd + 'endobj'.length;

    final offsets = <int, (int, int)>{}; // object number -> (offset, generation)
    for (final m in RegExp(r'(?<![0-9])(\d{1,7})\s+(\d{1,5})\s+obj\b').allMatches(text)) {
      // An object starting after the last "endobj" was cut off mid-way.
      if (m.start > lastEnd) continue;
      final number = int.parse(m.group(1)!);
      if (number == 0) continue;
      offsets[number] = (m.start, int.parse(m.group(2)!));
    }
    if (offsets.isEmpty) return null;

    final root = _findRoot(text, offsets);
    if (root == null) return null;

    final size = offsets.keys.reduce((a, b) => a > b ? a : b) + 1;
    final xref = StringBuffer('\nxref\n0 $size\n0000000000 65535 f \n');
    for (var n = 1; n < size; n++) {
      final entry = offsets[n];
      xref.write(
        entry == null
            ? '0000000000 00000 f \n'
            : '${entry.$1.toString().padLeft(10, '0')} ${entry.$2.toString().padLeft(5, '0')} n \n',
      );
    }
    final start = bodyEnd + 1; // after the leading newline
    xref.write('trailer\n<< /Size $size /Root $root >>\nstartxref\n$start\n%%EOF\n');
    return Uint8List.fromList([...pdf.sublist(0, bodyEnd), ...latin1.encode(xref.toString())]);
  }

  /// "N G R" for the document catalog: from a trailer if one survives,
  /// otherwise the object that declares /Type /Catalog.
  static String? _findRoot(String text, Map<int, (int, int)> offsets) {
    for (final m in RegExp(r'/Root\s+(\d+)\s+(\d+)\s+R').allMatches(text).toList().reversed) {
      if (offsets.containsKey(int.parse(m.group(1)!))) return '${m.group(1)} ${m.group(2)} R';
    }
    for (final entry in offsets.entries) {
      final start = entry.value.$1;
      final end = text.indexOf('endobj', start);
      final body = text.substring(start, end < 0 ? text.length : end);
      if (RegExp(r'/Type\s*/Catalog\b').hasMatch(body)) return '${entry.key} ${entry.value.$2} R';
    }
    return null;
  }

  /// A clean full rewrite if possible, else a plain save (which keeps the
  /// repaired table), else null.
  static Uint8List? _resave(Uint8List pdf) {
    for (final fullRewrite in [true, false]) {
      PdfDocument? doc;
      try {
        doc = PdfDocument(inputBytes: pdf);
        if (doc.pages.count == 0) return null;
        // Touch every page so a broken one fails here, not in the reader.
        for (var i = 0; i < doc.pages.count; i++) {
          doc.pages[i].size;
        }
        doc.fileStructure.incrementalUpdate = !fullRewrite;
        final saved = Uint8List.fromList(doc.saveSync());
        // Only a file that opens again counts as repaired.
        PdfDocument(inputBytes: saved).dispose();
        return saved;
      } catch (_) {
        // Try the next way.
      } finally {
        doc?.dispose();
      }
    }
    return null;
  }
}

class PdfCompression {
  PdfCompression._();

  /// 0-based pages with (almost) no text: scans and photos, whose images
  /// are what makes filings large. Pages with real text are left alone so
  /// they stay sharp and searchable.
  static List<int> scannedPages(Uint8List pdf) {
    final doc = PdfEngine.open(pdf);
    try {
      final extractor = PdfTextExtractor(doc);
      return [
        for (var i = 0; i < doc.pages.count; i++)
          if (_text(extractor, i).trim().length < 3) i,
      ];
    } finally {
      doc.dispose();
    }
  }

  /// Re-saves [pdf] with maximum stream compression and without leftovers
  /// from earlier edits.
  static Uint8List rewrite(Uint8List pdf) {
    final doc = PdfEngine.open(pdf);
    try {
      doc.compressionLevel = PdfCompressionLevel.best;
      doc.fileStructure.incrementalUpdate = false;
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }

  static String _text(PdfTextExtractor extractor, int page) {
    try {
      return extractor.extractText(startPageIndex: page, endPageIndex: page);
    } catch (_) {
      return '';
    }
  }
}

String _latin1(Uint8List bytes) => latin1.decode(bytes, allowInvalid: true);
