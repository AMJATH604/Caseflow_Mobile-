import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/gemini_service.dart';
import 'ai_palette.dart';

/// Chat history, set like ChatGPT's sidebar: search, a New chat row, and
/// conversations grouped by when they were last used. Swipe a chat left, or
/// long-press it, to delete.
class AiChatDrawer extends StatefulWidget {
  final bool isDark;
  final List<ChatSession> sessions;
  final String? currentSessionId;
  final VoidCallback onNewChat;
  final void Function(ChatSession session) onSelectSession;
  final void Function(ChatSession session) onDeleteSession;

  const AiChatDrawer({
    super.key,
    required this.isDark,
    required this.sessions,
    this.currentSessionId,
    required this.onNewChat,
    required this.onSelectSession,
    required this.onDeleteSession,
  });

  /// Which group a conversation falls in, by its last use.
  static String groupOf(DateTime updated, [DateTime? now]) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final day = DateUtils.dateOnly(updated.toLocal());
    final days = today.difference(day).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return 'Previous 7 days';
    if (days < 30) return 'Previous 30 days';
    return 'Older';
  }

  @override
  State<AiChatDrawer> createState() => _AiChatDrawerState();
}

class _AiChatDrawerState extends State<AiChatDrawer> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = AiPalette(widget.isDark);
    final q = _query.trim().toLowerCase();
    final shown = widget.sessions
        .where((s) => q.isEmpty || s.title.toLowerCase().contains(q))
        .toList();

    // Keep the list's own order (newest first) and start a heading whenever
    // the group changes.
    final rows = <Widget>[];
    String? group;
    for (final s in shown) {
      final g = AiChatDrawer.groupOf(s.updatedAt);
      if (g != group) {
        group = g;
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, rows.isEmpty ? 4.h : 18.h, 12.w, 6.h),
            child: Text(
              g,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: c.faint,
              ),
            ),
          ),
        );
      }
      rows.add(
        _SessionTile(
          session: s,
          isActive: s.id == widget.currentSessionId,
          palette: c,
          onTap: () => widget.onSelectSession(s),
          onDelete: () => widget.onDeleteSession(s),
        ),
      );
    }

    return Drawer(
      backgroundColor: c.bg,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 6.h),
              child: Container(
                height: 42.h,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.inter(fontSize: 14.sp, color: c.ink),
                  decoration: InputDecoration(
                    hintText: 'Search chats',
                    hintStyle: GoogleFonts.inter(fontSize: 14.sp, color: c.faint),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.muted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 11.h),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: ListTile(
                onTap: widget.onNewChat,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                leading: Icon(Icons.edit_square, size: 20, color: c.ink),
                title: Text(
                  'New chat',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: c.border, indent: 16.w, endIndent: 16.w),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        q.isEmpty ? 'No chats yet' : 'No chats match "$_query"',
                        style: GoogleFonts.inter(fontSize: 13.sp, color: c.faint),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                      children: rows,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final AiPalette palette;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.palette,
    required this.onTap,
    required this.onDelete,
  });

  Future<bool> _confirm(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete chat?'),
          content: Text('"${session.title}" will be deleted. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 18.w),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: isActive ? palette.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete,
          borderRadius: BorderRadius.circular(10.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            child: Text(
              session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
