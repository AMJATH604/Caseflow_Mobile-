import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

/// Base repository providing shared Supabase utilities for all domain repositories.
///
/// Design decisions:
/// - Static [client] accessor avoids re-initialization in every repository
/// - [getCachedProfile] eliminates the N+1 fetchProfile() problem by caching
///   with a configurable TTL (default: 5 minutes)
/// - [buildVisibilityFilter] centralizes the firm/user visibility OR-filter
///   used by cases, clients, hearings, payments, e-filing, certified copies
/// - [requireAuth] is a guard clause shorthand used in every mutation method
class BaseRepository {
  static final client = Supabase.instance.client;

  // ─── Profile Cache ─────────────────────────────────────
  static UserProfile? _cachedProfile;
  static DateTime? _profileCachedAt;
  static Future<UserProfile>? _profileInFlight;
  static const _profileTtl = Duration(minutes: 5);

  /// Returns a cached profile if fresh (< 5 min), otherwise fetches from DB.
  /// This eliminates the N+1 problem where fetchProfile() was called inside
  /// every data-fetching method (fetchCases, fetchClients, etc.).
  ///
  /// Concurrent callers share a single request. The result cache alone did
  /// not cover a cold start: the dashboard builds a dozen providers at once,
  /// every one of them missed the empty cache in the same moment, and each
  /// fired its own `get_my_profile` RPC — a thundering herd against the one
  /// endpoint all of them were waiting on.
  static Future<UserProfile> getCachedProfile() async {
    final now = DateTime.now();
    if (_cachedProfile != null &&
        _profileCachedAt != null &&
        now.difference(_profileCachedAt!) < _profileTtl) {
      return _cachedProfile!;
    }

    final inFlight = _profileInFlight;
    if (inFlight != null) return inFlight;

    final future = _fetchAndVerifyProfile();
    _profileInFlight = future;
    try {
      final profile = await future;
      _cachedProfile = profile;
      _profileCachedAt = DateTime.now();
      return profile;
    } finally {
      // Cleared on failure too, so a failed fetch does not wedge every later
      // caller onto the same broken future.
      _profileInFlight = null;
    }
  }

  /// Force-invalidates the profile cache.
  /// Call this on: sign-in, sign-out, firm join/leave, profile edit.
  static void invalidateProfileCache() {
    _cachedProfile = null;
    _profileCachedAt = null;
    _profileInFlight = null;
  }

  /// Full profile fetch with firm membership verification.
  static Future<UserProfile> _fetchAndVerifyProfile() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Through a server function: other users' contact fields are not
    // selectable directly, but your own profile needs every column.
    final response = await client.rpc('get_my_profile').maybeSingle();

    if (response == null) {
      final newProfile = {
        'id': user.id,
        'full_name': user.email?.split('@')[0] ?? 'User',
        'subscription_tier': 'free',
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client.from('profiles').insert(newProfile);
      return UserProfile.fromJson(newProfile);
    }

    final Map<String, dynamic> profileData = Map<String, dynamic>.from(
      response,
    );
    final String? currentFirmId = profileData['firm_id'];

    if (currentFirmId != null) {
      // Membership Verification: revoke if no longer in firm_members
      final membership =
          await client
              .from('firm_members')
              .select()
              .eq('member_id', user.id)
              .eq('owner_id', currentFirmId)
              .eq('status', 'accepted')
              .maybeSingle();

      if (membership == null) {
        await client
            .from('profiles')
            .update({'firm_id': null})
            .eq('id', user.id);
        profileData['firm_id'] = null;
      }
    }

    return UserProfile.fromJson(profileData);
  }

  // ─── Auth Guards ───────────────────────────────────────

  /// Returns the current authenticated user or throws.
  static User requireAuth() {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user;
  }

  /// Guarantees the request that follows carries a live access token.
  ///
  /// A query sent with an expired or missing token is not rejected loudly by
  /// PostgREST — RLS simply matches no rows, so the caller receives an empty
  /// list that is indistinguishable from "this user genuinely has none". That
  /// is how the Court Diary could come up blank on a cold start and fill in
  /// later. Throwing instead lets [RetryHelper] recover the session and retry.
  static Future<User> requireActiveSession() async {
    final session = client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');
    if (session.isExpired) {
      await client.auth.refreshSession();
    }
    return requireAuth();
  }

  /// Returns the current user's ID or null.
  static String? get currentUserId => client.auth.currentUser?.id;

  // ─── Visibility Filter ─────────────────────────────────

  /// Builds the standard OR filter string for firm-aware data visibility.
  /// Used by cases, clients, hearings, payments, e-filing, certified copies.
  ///
  /// Logic:
  /// - Always includes user's own records (via assigned_to or created_by)
  /// - If user is in a firm (firmId != null), includes firm records
  /// - If user IS the firm owner (firmId == null), includes records under their ID
  static String buildVisibilityFilter(
    UserProfile profile,
    String userId, {
    String userField = 'assigned_to',
  }) {
    String orFilter = '$userField.eq.$userId';
    if (profile.firmId != null) {
      orFilter += ',firm_id.eq.${profile.firmId}';
    }
    if (profile.isFirmOwner) {
      orFilter += ',firm_id.eq.$userId';
    }
    return orFilter;
  }

  /// The full case-visibility filter: own and firm records, **plus** every
  /// case shared through an accepted collaboration.
  ///
  /// [buildVisibilityFilter] alone omits collaborations, which is correct for
  /// tables that are not shared but wrong for `cases`. Hearings, payments and
  /// e-filing all scope themselves to case ids, so a shared case missing here
  /// meant its hearings never reached the Court Diary at all.
  static Future<String> buildCaseVisibilityFilter(
    UserProfile profile,
    String userId,
    String? email,
  ) async {
    final orFilter = buildVisibilityFilter(profile, userId);

    final collabRes = await client
        .from('case_collaborations')
        .select('case_id')
        .or('collaborator_email.eq.$email,collaborator_id.eq.$userId')
        .eq('status', 'accepted');

    final ids = (collabRes as List).map((c) => c['case_id'] as String).toList();
    if (ids.isEmpty) return orFilter;

    // One `in.(...)` term rather than an `id.eq.` term per collaboration, so
    // the filter string does not grow linearly with the number shared.
    return '$orFilter,id.in.(${ids.join(',')})';
  }

  /// Returns all visible case IDs for the current user (for filtering
  /// sub-entities such as hearings, payments and e-filing records).
  ///
  /// An empty result now means the user genuinely has no cases: the query
  /// either succeeds or throws, so callers may treat empty as authoritative.
  static Future<List<String>> getVisibleCaseIds(
    UserProfile profile,
    String userId,
  ) async {
    final orFilter = await buildCaseVisibilityFilter(
      profile,
      userId,
      client.auth.currentUser?.email,
    );
    final res = await client.from('cases').select('id').or(orFilter);
    return (res as List).map((c) => c['id'] as String).toList();
  }

  /// Target firm ID for creating new records.
  /// If user joined a firm → use that firm's ID.
  /// If solo or firm owner → use their own user ID.
  static String getTargetFirmId(UserProfile profile, String userId) {
    return profile.firmId ?? userId;
  }

  // ─── Server Time Sync ──────────────────────────────────

  static Duration _serverTimeOffset = Duration.zero;

  static void updateOffset(DateTime serverTime) {
    _serverTimeOffset = serverTime.toUtc().difference(DateTime.now().toUtc());
  }

  static DateTime get syncedNow => DateTime.now().add(_serverTimeOffset);

  // ─── Date Normalization ────────────────────────────────

  /// Normalizes a date string to `YYYY-MM-DD`, or null if unrecognised.
  ///
  /// Accepts the three shapes that actually reach us:
  /// - `YYYY-MM-DD` — already correct, passed through
  /// - `DD-MM-YYYY` / `DD/MM/YYYY` — the eCourts export format
  /// - `YYYY-MM-DDTHH:MM:SS...` — Dart's `toIso8601String()`, which is what
  ///   CaseFlow's own backup files contain; the time portion is dropped
  ///
  /// Returning null (rather than the input) is deliberate: callers must decide
  /// whether to skip the record or store nothing, instead of silently writing
  /// a value the database or `DateTime.parse` will later reject.
  static String? normalizeDateStr(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final s = dateStr.trim();

    // Already YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;

    // Full ISO-8601 timestamp — keep the date part only.
    final isoMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})[T ]').firstMatch(s);
    if (isoMatch != null) return isoMatch.group(1);

    // DD-MM-YYYY or DD/MM/YYYY
    final match = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(s);
    if (match != null) {
      final day = match.group(1)!.padLeft(2, '0');
      final month = match.group(2)!.padLeft(2, '0');
      return '${match.group(3)}-$month-$day';
    }

    return null;
  }

  // ─── Soft Delete Support ───────────────────────────────
  // Legal data requires audit trails — soft delete preserves records
  // by setting a `deleted_at` timestamp instead of removing rows.

  /// Soft-delete a record by setting its `deleted_at` timestamp.
  /// The record remains in the database for audit purposes but is
  /// filtered out of all standard queries.
  static Future<void> softDelete(String table, String id) async {
    requireAuth();
    await client
        .from(table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Restore a soft-deleted record by clearing its `deleted_at` timestamp.
  static Future<void> restoreSoftDeleted(String table, String id) async {
    requireAuth();
    await client.from(table).update({'deleted_at': null}).eq('id', id);
  }

  // ─── PostgREST Filter Sanitization ─────────────────────

  /// Escapes a user-supplied value for safe use inside a PostgREST filter
  /// string (`.or(...)`, `.ilike(...)`).
  ///
  /// Two distinct hazards are handled:
  ///
  /// 1. **Filter-structure injection.** PostgREST parses `,` as a term
  ///    separator and `()` as grouping inside `.or()`. A search for
  ///    `a,firm_id.eq.b` would otherwise inject an extra OR term and widen
  ///    the result set beyond what the user may see. These characters — plus
  ///    `.`, `"` and `\` which are also structural — are stripped.
  ///
  /// 2. **LIKE wildcard abuse.** `%` and `_` are wildcards in `ilike`. A query
  ///    of `%%%%%` is a needless table scan. They are removed so the search
  ///    matches them literally rather than as patterns.
  ///
  /// Returns at most [maxLength] characters.
  static String sanitizeFilterValue(String value, {int maxLength = 100}) {
    final cleaned = value
        .replaceAll(RegExp(r'[,()"\\.%_*]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength)
        : cleaned;
  }

  // ─── Input Validation Helpers ──────────────────────────

  /// Validates that required fields are present and non-empty in a data map.
  /// Throws [ArgumentError] with a clear message if validation fails.
  static void validateRequired(
    Map<String, dynamic> data,
    List<String> requiredFields,
  ) {
    for (final field in requiredFields) {
      final value = data[field];
      if (value == null || (value is String && value.trim().isEmpty)) {
        throw ArgumentError('Required field "$field" is missing or empty');
      }
    }
  }

  /// Validates that a string field doesn't exceed a maximum length.
  /// Returns the trimmed value or null if the input is null.
  static String? validateStringLength(
    String? value,
    String fieldName, {
    int maxLength = 500,
  }) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.length > maxLength) {
      throw ArgumentError(
        '$fieldName exceeds maximum length of $maxLength characters',
      );
    }
    return trimmed;
  }

  // ─── Profile Photo ────────────────────────────────────

  /// Uploads a profile photo to Supabase Storage and updates the profile.
  /// Overwrites any existing photo. Invalidates the profile cache.
  static Future<String> updateProfilePhoto(
    String userId,
    Uint8List imageBytes,
  ) async {
    requireAuth();
    final storagePath = '$userId/avatar.jpg';

    await client.storage.from('profile-photos').uploadBinary(
      storagePath,
      imageBytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    final publicUrl = client.storage
        .from('profile-photos')
        .getPublicUrl(storagePath);

    // Append cache-buster to force reload in Image widgets
    final urlWithBuster = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    await client
        .from('profiles')
        .update({'avatar_url': urlWithBuster})
        .eq('id', userId);

    invalidateProfileCache();
    return urlWithBuster;
  }

  /// Removes the profile photo from storage and clears the URL in the profile.
  static Future<void> removeProfilePhoto(String userId) async {
    requireAuth();
    final storagePath = '$userId/avatar.jpg';

    try {
      await client.storage.from('profile-photos').remove([storagePath]);
    } catch (_) {
      // Ignore storage removal errors (file may not exist)
    }

    await client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', userId);

    invalidateProfileCache();
  }
}
