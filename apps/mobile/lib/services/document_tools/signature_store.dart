/// The user's saved signatures and seals, kept only on this phone (in the
/// app's private storage), never uploaded.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SavedSignature {
  final String id;
  final Uint8List png;
  const SavedSignature(this.id, this.png);
}

class SignatureStore {
  SignatureStore._();

  static const maxSaved = 4;

  /// Where signatures live; tests point this at a temporary folder.
  @visibleForTesting
  static Future<Directory> Function() directory = () async =>
      Directory('${(await getApplicationSupportDirectory()).path}/signatures');

  /// Newest first. Empty on web, which has no private file storage.
  static Future<List<SavedSignature>> list() async {
    if (kIsWeb) return const [];
    final dir = await directory();
    if (!await dir.exists()) return const [];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.png'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return [
      for (final f in files)
        SavedSignature(f.uri.pathSegments.last.replaceAll('.png', ''), await f.readAsBytes()),
    ];
  }

  /// Saves [png], dropping the oldest beyond [maxSaved].
  static Future<void> add(Uint8List png) async {
    if (kIsWeb) return;
    final dir = await directory();
    await dir.create(recursive: true);
    // Zero-padded time, so names sort oldest to newest.
    final id = DateTime.now().microsecondsSinceEpoch.toString().padLeft(20, '0');
    await File('${dir.path}/$id.png').writeAsBytes(png, flush: true);
    final all = await list();
    for (final old in all.skip(maxSaved)) {
      await delete(old.id);
    }
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) return;
    final file = File('${(await directory()).path}/$id.png');
    if (await file.exists()) await file.delete();
  }
}
