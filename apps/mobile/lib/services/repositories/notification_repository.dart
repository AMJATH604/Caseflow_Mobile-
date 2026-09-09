import '../../models/notification_models.dart';
import 'base_repository.dart';

/// Reads and mutates `public.notifications` — the in-app Notification Centre.
///
/// RLS scopes every statement here to the signed-in user, so none of these
/// methods filter on `user_id` themselves: a client cannot see or touch
/// another advocate's rows regardless of what it asks for. Rows are inserted
/// only by database triggers and the notification edge functions.
///
/// Everything in the table is transient — a cron job deletes rows older than
/// 24 hours — so there is no pagination and no offline cache. The whole feed
/// is at most a day's worth of events.
class NotificationRepository {
  static final _client = BaseRepository.client;

  /// The user's notifications, newest first.
  static Future<List<AppNotification>> fetchNotifications() async {
    BaseRepository.requireAuth();
    final res = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false);

    return (res as List)
        .map((row) => AppNotification.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Number of unread notifications — the badge count.
  ///
  /// Returns 0 rather than throwing when signed out: this feeds a badge that
  /// is built on every frame of the bottom nav, including during sign-out.
  static Future<int> unreadCount() async {
    if (_client.auth.currentUser == null) return 0;

    final res = await _client
        .from('notifications')
        .select('id')
        .isFilter('read_at', null);

    return (res as List).length;
  }

  /// Marks one notification read. No-op if it is already read.
  static Future<void> markRead(String id) async {
    BaseRepository.requireAuth();
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .isFilter('read_at', null);
  }

  /// Marks every unread notification read in one statement.
  static Future<void> markAllRead() async {
    BaseRepository.requireAuth();
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('read_at', null);
  }

  /// Permanently removes one notification (swipe to dismiss).
  ///
  /// A hard delete, unlike the soft-delete used for case data: these rows are
  /// already scheduled for deletion within 24 hours and carry no audit value.
  static Future<void> dismiss(String id) async {
    BaseRepository.requireAuth();
    await _client.from('notifications').delete().eq('id', id);
  }

  /// Clears the whole feed for the current user.
  static Future<void> clearAll() async {
    final user = BaseRepository.requireAuth();
    await _client.from('notifications').delete().eq('user_id', user.id);
  }
}
