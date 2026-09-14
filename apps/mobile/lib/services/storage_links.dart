import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_constants.dart';

/// Turns stored links to private storage files into short-lived signed links.
///
/// Case documents, chat attachments, commission evidence and payment receipts
/// are privileged advocate–client material. Their buckets are being made
/// private, after which the permanent `/object/public/...` links saved in the
/// database stop opening. Rather than rewrite every stored link, anything that
/// displays or downloads one of these files passes it through [resolve], which
/// swaps it for a signed link valid for an hour — issued only to a user whose
/// storage policies allow them to read that file.
///
/// Links to public buckets (bare acts, templates, profile photos) and to other
/// sites are returned unchanged, so it is always safe to call.
class StorageLinks {
  StorageLinks._();

  static const Set<String> privateBuckets = {
    'case-documents',
    'chat-attachments',
    'commission-evidence',
    'commission-sketches',
    'commission-witnesses',
    'payment-receipts',
  };

  static const Duration _lifetime = Duration(hours: 1);

  /// Signed links are reused until five minutes before they expire, so a
  /// scrolling chat does not request a new one for every rebuild.
  static const Duration _renewBefore = Duration(minutes: 5);

  static final Map<String, _SignedLink> _cache = {};

  /// Returns the bucket and object path when [url] points at a private bucket
  /// of this project, otherwise null.
  static StorageRef? parse(String url) {
    if (!url.startsWith(AppConstants.supabaseUrl)) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // storage / v1 / object / {public|sign|authenticated} / <bucket> / <path...>
    final segments = uri.pathSegments;
    final objectIdx = segments.indexOf('object');
    if (objectIdx < 0 || segments.length < objectIdx + 4) return null;

    final bucket = segments[objectIdx + 2];
    if (!privateBuckets.contains(bucket)) return null;

    return StorageRef(bucket, segments.sublist(objectIdx + 3).join('/'));
  }

  /// A link that opens for the current user. See the class documentation.
  static Future<String> resolve(String url) async {
    final ref = parse(url);
    if (ref == null) return url;
    return _sign(url, ref);
  }

  /// A signed link for a file addressed by bucket and path.
  static Future<String> signPath(String bucket, String path) {
    return _sign('$bucket/$path', StorageRef(bucket, path));
  }

  static Future<String> _sign(String cacheKey, StorageRef ref) async {
    final cached = _cache[cacheKey];
    if (cached != null &&
        cached.expiresAt.isAfter(DateTime.now().add(_renewBefore))) {
      return cached.url;
    }

    try {
      final signed = await Supabase.instance.client.storage
          .from(ref.bucket)
          .createSignedUrl(ref.path, _lifetime.inSeconds);
      _cache[cacheKey] = _SignedLink(signed, DateTime.now().add(_lifetime));
      return signed;
    } catch (e) {
      // Before the buckets are made private the public link still works, so
      // fall back to it rather than failing to show the file.
      debugPrint('StorageLinks: could not sign ${ref.bucket}/${ref.path}: $e');
      return cacheKey.startsWith('http')
          ? cacheKey
          : Supabase.instance.client.storage
              .from(ref.bucket)
              .getPublicUrl(ref.path);
    }
  }

  /// Drops cached links, e.g. on sign-out.
  static void clearCache() => _cache.clear();
}

class StorageRef {
  final String bucket;
  final String path;
  const StorageRef(this.bucket, this.path);
}

class _SignedLink {
  final String url;
  final DateTime expiresAt;
  const _SignedLink(this.url, this.expiresAt);
}
