import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/safe_date.dart';

/// A single row from `public.notifications` — the in-app Notification Centre.
///
/// Named [AppNotification] rather than `Notification` on purpose: Flutter's
/// own `Notification` class and Firebase's `RemoteNotification` are already in
/// scope across the notification code, and a third `Notification` would make
/// every import ambiguous.
///
/// Rows are transient. A cron job deletes anything older than 24 hours, so
/// this is a "what did I miss today" feed, not a permanent history.
class AppNotification {
  final String id;
  final String userId;

  /// One of the types in the table's CHECK constraint: `hearing_reminder`,
  /// `caveat_reminder`, `invitation`, `invitation_response`, `case_status`,
  /// `task_assigned`, `task_due`, `payment`, `bar_notice`.
  final String type;
  final String title;
  final String body;

  /// go_router path to push when the row is tapped, e.g. `/cases/<uuid>`.
  /// Null for notifications with nowhere useful to go.
  final String? route;

  /// Type-specific ids — `case_id`, `task_id`, `hearing_id`, …
  final Map<String, dynamic> payload;

  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.route,
    this.payload = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      route: json['route'],
      payload:
          json['payload'] is Map
              ? Map<String, dynamic>.from(json['payload'])
              : const {},
      readAt: parseDateOrNull(json['read_at']),
      createdAt: parseDateOr(json['created_at'], DateTime.now()),
    );
  }

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      route: route,
      payload: payload,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  /// Icon shown in the leading tile, chosen from [type] so the list stays
  /// declarative. Mirrors the icon each source uses elsewhere in the app.
  IconData get icon {
    switch (type) {
      case 'hearing_reminder':
        return Icons.gavel_rounded;
      case 'caveat_reminder':
        return Icons.shield_outlined;
      case 'invitation':
        return Icons.mail_rounded;
      case 'invitation_response':
        return Icons.how_to_reg_rounded;
      case 'case_status':
        return Icons.folder_rounded;
      case 'task_assigned':
        return Icons.assignment_ind_rounded;
      case 'task_due':
        return Icons.timer_outlined;
      case 'payment':
        return Icons.credit_card_rounded;
      case 'bar_notice':
        return Icons.account_balance_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// Accent colour for the leading tile.
  Color get color {
    switch (type) {
      case 'hearing_reminder':
        return AppTheme.warning;
      case 'caveat_reminder':
        return const Color(0xFFEA580C);
      case 'invitation':
        return const Color(0xFF7C3AED);
      case 'invitation_response':
        return AppTheme.success;
      case 'case_status':
        return AppTheme.accent;
      case 'task_assigned':
        return AppTheme.accentViolet;
      case 'task_due':
        return AppTheme.error;
      case 'payment':
        return AppTheme.success;
      case 'bar_notice':
        return const Color(0xFF0891B2);
      default:
        return AppTheme.info;
    }
  }

  /// Short relative age, e.g. `now`, `12m`, `5h`. Never exceeds `23h` in
  /// practice because rows are purged at 24 hours.
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
