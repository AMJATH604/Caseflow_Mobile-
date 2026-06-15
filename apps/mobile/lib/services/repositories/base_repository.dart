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
  static const _profileTtl = Duration(minutes: 5);

  /// Returns a cached profile if fresh (< 5 min), otherwise fetches from DB.
  /// This eliminates the N+1 problem where fetchProfile() was called inside
  /// every data-fetching method (fetchCases, fetchClients, etc.).
  static Future<UserProfile> getCachedProfile() async {
    final now = DateTime.now();
    if (_cachedProfile != null &&
        _profileCachedAt != null &&
        now.difference(_profileCachedAt!) < _profileTtl) {
      return _cachedProfile!;
    }
    // Cache miss — fetch fresh
    _cachedProfile = await _fetchAndVerifyProfile();
    _profileCachedAt = now;
    return _cachedProfile!;
  }

  /// Force-invalidates the profile cache.
  /// Call this on: sign-in, sign-out, firm join/leave, profile edit.
  static void invalidateProfileCache() {
    _cachedProfile = null;
    _profileCachedAt = null;
  }

  /// Full profile fetch with firm membership verification.
  static Future<UserProfile> _fetchAndVerifyProfile() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final response =
        await client.from('profiles').select().eq('id', user.id).maybeSingle();

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

  /// Returns all visible case IDs for the current user (for filtering sub-entities).
  static Future<List<String>> getVisibleCaseIds(
    UserProfile profile,
    String userId,
  ) async {
    final orFilter = buildVisibilityFilter(profile, userId);
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

  /// Normalizes date strings: DD-MM-YYYY or DD/MM/YYYY → YYYY-MM-DD
  static String? normalizeDateStr(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final s = dateStr.trim();

    // Already YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;

    // DD-MM-YYYY or DD/MM/YYYY
    final match = RegExp(r'^(\d{2})[-/](\d{2})[-/](\d{4})$').firstMatch(s);
    if (match != null) {
      return '${match.group(3)}-${match.group(2)}-${match.group(1)}';
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
