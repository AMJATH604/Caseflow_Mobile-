import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'repositories/base_repository.dart';

/// Audit logging service for tracking critical data mutations.
///
/// Records who changed what, when, and from which context.
/// Essential for a legal application where data integrity and
/// chain of custody are paramount.
///
/// Usage:
/// ```dart
/// await AuditLogger.log(
///   action: AuditAction.create,
///   entity: 'cases',
///   entityId: caseId,
///   details: {'case_title': title, 'client_id': clientId},
/// );
/// ```
class AuditLogger {
  static final _client = Supabase.instance.client;

  /// Log an audit event (fire-and-forget — never blocks the main flow).
  ///
  /// Parameters:
  /// - [action] — The type of mutation (create, update, delete, etc.)
  /// - [entity] — The table/entity name (e.g., 'cases', 'hearings')
  /// - [entityId] — The primary key of the affected record
  /// - [details] — Optional JSON map with additional context (old/new values)
  /// - [context] — Optional screen or source identifier
  static Future<void> log({
    required AuditAction action,
    required String entity,
    required String entityId,
    Map<String, dynamic>? details,
    String? context,
  }) async {
    try {
      final userId = BaseRepository.currentUserId;
      if (userId == null) return;

      await _client.from('audit_logs').insert({
        'user_id': userId,
        'action': action.name,
        'entity': entity,
        'entity_id': entityId,
        'details': details,
        'context': context,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Audit logging should NEVER crash the app — log locally and continue
      debugPrint('AuditLogger: Failed to record audit event: $e');
    }
  }

  /// Log a batch of audit events (e.g., bulk import).
  static Future<void> logBatch({
    required AuditAction action,
    required String entity,
    required List<String> entityIds,
    String? context,
  }) async {
    try {
      final userId = BaseRepository.currentUserId;
      if (userId == null) return;

      final now = DateTime.now().toUtc().toIso8601String();
      final records =
          entityIds
              .map(
                (id) => {
                  'user_id': userId,
                  'action': action.name,
                  'entity': entity,
                  'entity_id': id,
                  'context': context,
                  'created_at': now,
                },
              )
              .toList();

      await _client.from('audit_logs').insert(records);
    } catch (e) {
      debugPrint('AuditLogger: Failed to record batch audit: $e');
    }
  }
}

/// Enumeration of auditable actions.
///
/// Maps to the `action` column in the `audit_logs` table.
enum AuditAction {
  /// A new record was created
  create,

  /// An existing record was updated
  update,

  /// A record was deleted (or soft-deleted)
  delete,

  /// A record was viewed (for sensitive data access tracking)
  view,

  /// Data was exported (PDF, CSV, etc.)
  export_data,

  /// Data was imported (case import, eCourt sync, etc.)
  import_data,

  /// User signed in
  signIn,

  /// User signed out
  signOut,

  /// Subscription tier changed
  subscriptionChange,

  /// Firm membership changed (joined/left)
  firmMembershipChange,

  /// Case collaboration invited/accepted/rejected
  collaborationChange,

  /// AI chat interaction (for usage tracking)
  aiQuery,
}
