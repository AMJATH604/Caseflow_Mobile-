import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for user profile management.
/// Handles fetching, updating, and caching professional profiles.
class ProfileRepository {
  static final _client = BaseRepository.client;

  /// Returns a cached profile if fresh (< 5 min), otherwise fetches from DB.
  /// This eliminates the N+1 problem where fetchProfile() was called inside
  /// every data-fetching method.
  static Future<UserProfile> getProfile() async {
    return await BaseRepository.getCachedProfile();
  }

  /// Updates the user's profile information.
  /// Invalidates the cache to ensure next read is fresh.
  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = BaseRepository.requireAuth();
    await _client.from('profiles').update(updates).eq('id', user.id);
    BaseRepository.invalidateProfileCache();
  }

  // ─── Account ─────────────────────────────────────────────

  /// Asks for the account to be deleted in 30 days. Throws
  /// [TeamExistsException] while the user owns a firm with juniors or clerks.
  /// Returns the date the account will be deleted.
  static Future<DateTime> requestAccountDeletion() async {
    BaseRepository.requireAuth();
    try {
      final due = await _client.rpc('request_account_deletion');
      BaseRepository.invalidateProfileCache();
      return DateTime.parse(due as String).toLocal();
    } on PostgrestException catch (e) {
      if (e.message.contains('CF_TEAM_EXISTS')) throw const TeamExistsException();
      rethrow;
    }
  }

  /// Keeps the account: clears a pending deletion.
  static Future<void> cancelAccountDeletion() async {
    BaseRepository.requireAuth();
    await _client.rpc('cancel_account_deletion');
    BaseRepository.invalidateProfileCache();
  }

  /// Confirms the password before a sensitive change by signing in again.
  /// Returns false when the password is wrong.
  static Future<bool> verifyPassword(String password) async {
    final email = BaseRepository.requireAuth().email;
    if (email == null) return false;
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException {
      return false;
    }
  }

  /// Starts an email change. Supabase emails a confirmation link to the new
  /// address (and, with secure email change on, to the old one); the login
  /// email changes only after the link is opened.
  static Future<void> requestEmailChange(String newEmail) async {
    BaseRepository.requireAuth();
    await _client.auth.updateUser(UserAttributes(email: newEmail.trim()));
  }

  static Future<void> changePassword(String newPassword) async {
    BaseRepository.requireAuth();
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Display names for the given profile ids. Names only: other users'
  /// contact fields are not selectable.
  static Future<Map<String, String>> fetchDisplayNames(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', ids);
    return {
      for (final row in rows as List)
        row['id'] as String:
            ((row['full_name'] as String?)?.trim().isNotEmpty ?? false)
                ? row['full_name'] as String
                : 'a colleague',
    };
  }

  /// Refreshes the cache from the database.
  static Future<UserProfile> refreshProfile() async {
    BaseRepository.invalidateProfileCache();
    return await getProfile();
  }
}

/// The account owns a firm that still has juniors or clerks.
class TeamExistsException implements Exception {
  const TeamExistsException();
  @override
  String toString() =>
      'Remove your juniors and clerks from your team before deleting your account.';
}
