import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'profile_avatar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/message_id.dart';

/// Premium Discussion Tab — WhatsApp-grade chat with avatar circles,
/// date separator pills, rounded bubbles, and glassmorphic input bar.
class CaseDiscussionTab extends ConsumerStatefulWidget {
  final String caseId;
  final String firmId;

  const CaseDiscussionTab({
    super.key,
    required this.caseId,
    required this.firmId,
  });

  @override
  ConsumerState<CaseDiscussionTab> createState() => _CaseDiscussionTabState();
}

class _CaseDiscussionTabState extends ConsumerState<CaseDiscussionTab> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  final List<CaseComment> _optimisticMessages = [];

  static const _avatarGradients = [
    [Color(0xFF6366F1), Color(0xFF818CF8)],
    [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    [Color(0xFFEF4444), Color(0xFFF87171)],
    [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Color> _getAvatarColors(String? name) {
    final hash = (name ?? 'A').codeUnits.fold(0, (prev, c) => prev + c);
    return _avatarGradients[hash % _avatarGradients.length];
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    // Made here and saved with the row, so the message shows at once and the
    // copy that comes back from the database replaces it (matched by id, not
    // by text, which hid a second "ok" behind the first).
    final id = newMessageId();
    try {
      final profile = await SupabaseService.fetchProfile();
      final senderName = profile.fullName ?? 'Advocate';
      final currentUser = ref.read(userProvider);

      setState(() {
        _optimisticMessages.add(
          CaseComment(
            id: id,
            caseId: widget.caseId,
            firmId: widget.firmId,
            senderId: currentUser?.id ?? '',
            message: text,
            senderName: senderName,
            createdAt: DateTime.now(),
          ),
        );
      });
      _messageController.clear();

      await SupabaseService.postDiscussion({
        'id': id,
        'case_id': widget.caseId,
        'firm_id': widget.firmId,
        'message': text,
        'sender_name': senderName,
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        // Not sent: take the bubble back and return the text to the box.
        setState(() => _optimisticMessages.removeWhere((m) => m.id == id));
        if (_messageController.text.isEmpty) _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message not sent. Check your connection.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final discussionsAsync = ref.watch(caseDiscussionsProvider(widget.caseId));
    final currentUser = ref.watch(userProvider);

    return Column(
      children: [
        Expanded(
          child: discussionsAsync.when(
            data: (streamMessages) {
              final savedIds = {for (final m in streamMessages) m.id};
              _optimisticMessages.removeWhere((o) => savedIds.contains(o.id));
              final allMessages = [...streamMessages, ..._optimisticMessages];

              if (allMessages.isEmpty) return _buildEmptyState();

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: allMessages.length,
                itemBuilder: (context, index) {
                  final msg = allMessages[index];
                  final isMe = msg.senderId == currentUser?.id;

                  // Date separator
                  Widget? dateSeparator;
                  if (index == 0) {
                    dateSeparator = _buildDatePill(msg.createdAt);
                  } else {
                    final prev = allMessages[index - 1];
                    if (!_isSameDay(prev.createdAt, msg.createdAt)) {
                      dateSeparator = _buildDatePill(msg.createdAt);
                    }
                  }

                  return Column(
                    children: [
                      if (dateSeparator != null) dateSeparator,
                      _buildMessageBubble(msg, isMe),
                    ],
                  );
                },
              );
            },
            loading:
                () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─── DATE SEPARATOR PILL ─────────────────────────────
  Widget _buildDatePill(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('dd MMM yyyy').format(date);
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ─── MESSAGE BUBBLE ──────────────────────────────────
  Widget _buildMessageBubble(CaseComment msg, bool isMe) {
    final timeStr = DateFormat('hh:mm a').format(msg.createdAt.toLocal());
    final initial = (msg.senderName ?? 'A')[0].toUpperCase();
    final avatarColors = _getAvatarColors(msg.senderName);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar (left side for others)
            if (!isMe) ...[
              ProfileAvatar(
                name: msg.senderName,
                radius: 16,
                borderWidth: 0,
                showBorder: false,
                gradientColors: avatarColors,
              ),
              SizedBox(width: 8.w),
            ],
            // Bubble
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: EdgeInsets.only(left: 4.w, bottom: 3.h),
                      child: Text(
                        msg.senderName?.toUpperCase() ?? 'ADVOCATE',
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: avatarColors[0],
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isMe
                              ? const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                              )
                              : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16.r),
                        topRight: Radius.circular(16.r),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border:
                          isMe
                              ? null
                              : Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isMe
                                  ? const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.message,
                          style: TextStyle(
                            color:
                                isMe ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.4.h,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color:
                                    isMe
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : const Color(0xFF94A3B8),
                              ),
                            ),
                            if (isMe) ...[
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.done_all_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFF0F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.forum_rounded,
              size: 44,
              color: Color(0xFF2563EB),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Start a Discussion',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17.sp,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.w),
            child: Text(
              'Coordinate with your team members\nabout case strategy and updates',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13.sp,
                height: 1.4.h,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PREMIUM INPUT BAR ───────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5.w),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                style: TextStyle(color: Color(0xFF1E293B), fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Gradient send button
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child:
                    _isSending
                        ? SizedBox(
                          width: 18.w,
                          height: 18.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
