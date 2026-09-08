import '../../models/models.dart';
import 'base_repository.dart';

/// Reactions for chat messages (both 1-on-1 DMs and Chambers), distinguished by
/// a `scope` of 'dm' or 'chambers'. One reaction per user per message.
class MessageReactionRepository {
  static final _client = BaseRepository.client;

  static const String scopeDm = 'dm';
  static const String scopeChambers = 'chambers';

  /// Toggle the current user's reaction on a message:
  /// - no existing reaction        → add [emoji]
  /// - existing reaction == emoji  → remove it
  /// - existing reaction != emoji  → replace with [emoji]
  static Future<void> toggleReaction({
    required String scope,
    required String messageId,
    required String emoji,
  }) async {
    final user = BaseRepository.requireAuth();

    final existing = await _client
        .from('message_reactions')
        .select('id, emoji')
        .eq('scope', scope)
        .eq('message_id', messageId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      await _client.from('message_reactions').insert({
        'scope': scope,
        'message_id': messageId,
        'user_id': user.id,
        'emoji': emoji,
      });
    } else if (existing['emoji'] == emoji) {
      await _client.from('message_reactions').delete().eq('id', existing['id']);
    } else {
      await _client
          .from('message_reactions')
          .update({'emoji': emoji})
          .eq('id', existing['id']);
    }
  }

  /// Fetch all reactions for a set of message IDs, grouped by message ID.
  static Future<Map<String, List<MessageReaction>>> fetchForMessages({
    required String scope,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return {};

    final rows = await _client
        .from('message_reactions')
        .select('id, scope, message_id, user_id, emoji')
        .eq('scope', scope)
        .inFilter('message_id', messageIds);

    final map = <String, List<MessageReaction>>{};
    for (final r in (rows as List)) {
      final reaction = MessageReaction.fromJson(r);
      map.putIfAbsent(reaction.messageId, () => []).add(reaction);
    }
    return map;
  }
}
