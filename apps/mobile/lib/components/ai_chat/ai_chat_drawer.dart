import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/gemini_service.dart';

/// Drawer sidebar showing AI chat session history with new chat button.
class AiChatDrawer extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F0F18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20.r)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 34.w,
                    height: 34.h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Chat History',
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // ── New Chat Button ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: InkWell(
                onTap: onNewChat,
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8.w),
                      Text(
                        'New Chat',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 8.h),

            // ── Section header ──
            if (sessions.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RECENTS',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFF94A3B8),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),

            // ── Session list ──
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: isDark
                                ? const Color(0xFF232330)
                                : const Color(0xFFE2E8F0),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'No conversations yet',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isActive = session.id == currentSessionId;
                        return _SessionTile(
                          session: session,
                          isActive: isActive,
                          isDark: isDark,
                          onTap: () => onSelectSession(session),
                          onDelete: () => onDeleteSession(session),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats a DateTime into a relative time string.
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

/// Individual session tile with swipe-to-delete and tap-to-select.
class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Dismissible(
        key: Key(session.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.red,
            size: 22,
          ),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: const Text('Delete Chat?'),
              content: Text(
                'Delete "${session.title}"? This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => onDelete(),
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete,
          borderRadius: BorderRadius.circular(12.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark
                      ? const Color(0xFF1E1E2E)
                      : const Color(0xFFEEF2FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
              border: isActive
                  ? Border.all(
                      color: isDark
                          ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                          : const Color(0xFF6366F1).withValues(alpha: 0.2),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isActive
                      ? Icons.chat_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: isActive
                      ? const Color(0xFF6366F1)
                      : (isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? (isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A))
                              : (isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569)),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        AiChatDrawer.formatTimeAgo(session.updatedAt),
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
