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
