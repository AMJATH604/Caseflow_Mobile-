/// Getting files into the document tools and results back out: pickers,
/// share, save to phone, open, and save into a case's documents.
library;

import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../supabase_service.dart';
import 'pdf_engine.dart' show DocumentToolException;

/// The `case-documents` storage bucket's per-file limit.
const maxCaseDocumentBytes = 50 * 1024 * 1024;

/// A file held in memory by a tool, as picked or as produced.
class ToolFile {
  final String name;
  final Uint8List bytes;
  const ToolFile(this.name, this.bytes);

  String get sizeLabel => formatBytes(bytes.length);
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// `Petition.pdf` → `Petition`.
String baseName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.substring(0, dot) : fileName;
}

/// A file name safe for storage paths and every phone's file system.
/// Only a trailing `.pdf` (the [extension]) is treated as an extension, so
/// names like `O.S. 12/2026` keep their dots.
String safeFileName(String name, {String extension = 'pdf'}) {
  var base = name.trim();
  if (base.toLowerCase().endsWith('.${extension.toLowerCase()}')) {
    base = base.substring(0, base.length - extension.length - 1);
  }
  base = base
      .replaceAll(RegExp(r'[^\w\s().,-]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (base.isEmpty) base = 'document';
  if (base.length > 80) base = base.substring(0, 80).trim();
  return '$base.$extension';
}

/// [name], or `name (2).pdf`, `name (3).pdf`... if [taken] already has it.
String uniqueFileName(String name, Iterable<String> taken) {
  final used = taken.map((t) => t.toLowerCase()).toSet();
  if (!used.contains(name.toLowerCase())) return name;
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var n = 2; ; n++) {
    final candidate = '$base ($n)$ext';
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
}

class DocumentFiles {
  DocumentFiles._();

  /// Save-to-phone and Open need a real file system.
  static bool get canSaveToDevice => !kIsWeb;

  static Future<List<ToolFile>> pickPdfs({bool multiple = true}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: multiple,
      withData: true,
    );
    return _toToolFiles(result);
  }

  /// The camera scanner is a phone feature.
  static bool get canScan => !kIsWeb;

  /// Pages scanned with the camera (edges found and straightened by ML Kit
  /// on Android, VisionKit on iOS), as JPEGs. Empty if cancelled.
  static Future<List<ToolFile>> scanPages() async {
    try {
      final paths = await CunningDocumentScanner.getPictures(
        scannerSource: ScannerSource.camera,
      );
      if (paths == null) return const [];
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final files = [
        for (var i = 0; i < paths.length; i++)
          ToolFile('scan_${stamp}_${i + 1}.jpg', await File(paths[i]).readAsBytes()),
      ];
      // The scanner keeps its own copies; the pages are in memory now.
      await CunningDocumentScanner.cleanCache().catchError((_) {});
      return files;
    } on CunningDocumentScannerException catch (e) {
      throw DocumentToolException(
        e.code == 'permission_denied'
            ? 'CaseFlow needs camera access to scan. Allow it in your phone settings.'
            : 'The scanner could not start: ${e.message}',
      );
    }
  }

  /// Images from the phone's photo picker.
  static Future<List<ToolFile>> pickImagesFromGallery() async {
    final picked = await ImagePicker().pickMultiImage();
    return [for (final x in picked) ToolFile(x.name, await x.readAsBytes())];
  }

  /// Images from the file manager (e.g. WhatsApp or Downloads folders).
  static Future<List<ToolFile>> pickImageFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    return _toToolFiles(result);
  }

  /// The share sheet on phones; a download on web.
  static Future<void> share(ToolFile file) =>
      Printing.sharePdf(bytes: file.bytes, filename: file.name);

  /// Asks where to save and writes the file. Returns false if cancelled.
  static Future<bool> saveToDevice(ToolFile file) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: file.name,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: file.bytes,
    );
    return path != null;
  }

  /// Opens the file in the phone's PDF viewer.
  static Future<void> open(ToolFile file) async {
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/document_tools/${file.name}');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(file.bytes, flush: true);
    final result = await OpenFile.open(out.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  /// Uploads [file] to the case's documents without overwriting an existing
  /// document of the same name. Returns the name it was saved under.
  static Future<String> saveToCase(
    String caseId,
    ToolFile file, {
    required Iterable<String> existingNames,
  }) async {
    checkCaseDocumentSize(file);
    final name = uniqueFileName(safeFileName(file.name), existingNames);
    await SupabaseService.uploadDocument(caseId, file.bytes, name);
    return name;
  }

  /// One of the case's existing documents, for reuse in a tool.
  static Future<ToolFile> fromCase(String caseId, String fileName) async =>
      ToolFile(fileName, await SupabaseService.downloadDocument(caseId, fileName));

  /// Throws if [file] is over the case-documents limit.
  static void checkCaseDocumentSize(ToolFile file) {
    if (file.bytes.length > maxCaseDocumentBytes) {
      throw DocumentToolException(
        '"${file.name}" is ${file.sizeLabel}; case documents can be up to '
        '${formatBytes(maxCaseDocumentBytes)}. Split it into smaller files first.',
      );
    }
  }

  static List<ToolFile> _toToolFiles(FilePickerResult? result) => [
    for (final f in result?.files ?? const <PlatformFile>[])
      if (f.bytes != null) ToolFile(f.name, f.bytes!),
  ];
}
