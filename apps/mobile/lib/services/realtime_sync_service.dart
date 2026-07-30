import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Realtime sync service that listens to Supabase Realtime changes
/// on key tables and triggers a UI refresh via the [dataRefreshProvider].
///
/// This eliminates the need for manual pull-to-refresh after data mutations.
/// All providers that watch [dataRefreshProvider] will automatically re-fetch
/// when any INSERT, UPDATE, or DELETE event fires on the monitored tables.
class RealtimeSyncService {
  RealtimeSyncService._();
  static final RealtimeSyncService _instance = RealtimeSyncService._();
  factory RealtimeSyncService() => _instance;

  /// Callback that increments [dataRefreshProvider] in the Riverpod container.
  /// Set this from main.dart after ProviderScope is available.
  VoidCallback? onDataChanged;

  /// Tracks whether we are currently subscribed.
  bool _isSubscribed = false;

  /// Active Realtime channels.
  final List<RealtimeChannel> _channels = [];

  /// Debounce timer to batch rapid successive changes.
  Timer? _debounceTimer;

  /// Tables to monitor for Realtime changes.
  /// These cover the core data domains that appear on dashboards and lists.
  static const List<String> _monitoredTables = [
    'cases',
    'hearings',
    'clients',
    'payments',
    'documents',
    'tasks',
    'strategy_tasks',
    'commissions',
    'certified_copies',
    'efiling_records',
    'evidence_checklist',
    'evidence_photos',
    'witness_notes',
    'caveats',
  ];

  /// Initialize Realtime subscriptions for all monitored tables.
  /// Call this after the user is authenticated.
  void initialize() {
    if (_isSubscribed) return;

    final client = Supabase.instance.client;

    for (final table in _monitoredTables) {
      try {
        final channel = client
            .channel('realtime_$table')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              callback: (payload) {
                debugPrint(
                    'Realtime: ${payload.eventType} on $table');
                _triggerRefresh();
              },
            )
            .subscribe((status, [error]) {
          debugPrint('Realtime channel $table: $status');
        });
        _channels.add(channel);
      } catch (e) {
        debugPrint('Realtime: Failed to subscribe to $table: $e');
      }
    }

    _isSubscribed = true;
    debugPrint('RealtimeSyncService: Subscribed to ${_monitoredTables.length} tables');
  }

  /// Debounced refresh trigger.
  /// Batches multiple rapid events (e.g., bulk imports) into a single
  /// UI refresh within a 500ms window.
  void _triggerRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      debugPrint('RealtimeSyncService: Triggering global data refresh');
      onDataChanged?.call();
    });
  }

  /// Unsubscribe from all Realtime channels.
  /// Call this on sign-out to clean up resources.
  void dispose() {
    _debounceTimer?.cancel();
    final client = Supabase.instance.client;
    for (final channel in _channels) {
      try {
        client.removeChannel(channel);
      } catch (e) {
        debugPrint('Realtime: Error removing channel: $e');
      }
    }
    _channels.clear();
    _isSubscribed = false;
    debugPrint('RealtimeSyncService: All channels disposed');
  }
}
