import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers.dart';

/// Keeps the bar association screens live against BarDesk.
///
/// Everything the association publishes reached the phone only when the
/// advocate happened to pull to refresh: a court-closure notice posted at
/// 9am was read at noon, and a condolence — where the whole point is that
/// members know before they leave for court — arrived no faster than a
/// WhatsApp forward.
///
/// The tables BarDesk writes are in the `supabase_realtime` publication, so
/// a change there can invalidate the matching providers here. The channel is
/// filtered by association server-side: a member never receives another
/// association's traffic.
class BarRealtimeService {
  BarRealtimeService._();

  static RealtimeChannel? _channel;
  static String? _associationId;

  /// Which providers a change in each table makes stale.
  static void _invalidate(Ref ref, String table, String associationId) {
    switch (table) {
      case 'bar_notices':
        ref.invalidate(barNoticesProvider(associationId));
        break;
      case 'bar_events':
        ref.invalidate(barEventsProvider(associationId));
        break;
      case 'bar_members':
        // Covers a renewal, an ID card being issued, and the welfare status
        // the association keeps on the member's behalf.
        ref.invalidate(barMembershipProvider(associationId));
        break;
      case 'bar_fee_payments':
        ref.invalidate(barFeeHistoryProvider(associationId));
        break;
      case 'bar_condolences':
        ref.invalidate(barCondolencesProvider(associationId));
        break;
    }
  }

  /// Subscribes for [associationId], replacing any existing subscription.
  static void subscribe(Ref ref, String associationId) {
    if (_associationId == associationId && _channel != null) return;
    unsubscribe();

    final client = Supabase.instance.client;
    final channel = client.channel('bar_live:$associationId');

    for (final table in const [
      'bar_notices',
      'bar_events',
      'bar_members',
      'bar_fee_payments',
      'bar_condolences',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'association_id',
          value: associationId,
        ),
        callback: (_) {
          try {
            _invalidate(ref, table, associationId);
          } catch (e) {
            // A disposed ref during navigation must not take the channel
            // down with it.
            debugPrint('BarRealtime: invalidate failed for $table: $e');
          }
        },
      );
    }

    channel.subscribe();
    _channel = channel;
    _associationId = associationId;
  }

  static void unsubscribe() {
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _channel = null;
    _associationId = null;
  }
}

/// Holds the subscription for as long as a bar screen is on screen.
///
/// Watching this from a screen is all that is needed; it tears the channel
/// down when the last listener goes away.
final barRealtimeProvider = Provider.autoDispose.family<void, String>((
  ref,
  associationId,
) {
  if (associationId.isEmpty) return;
  BarRealtimeService.subscribe(ref, associationId);
  ref.onDispose(BarRealtimeService.unsubscribe);
});
