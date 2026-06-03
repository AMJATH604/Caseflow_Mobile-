import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

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
    try {
      final profile = await SupabaseService.fetchProfile();
      final senderName = profile.fullName ?? "Advocate";

      await SupabaseService.postDiscussion({
        'case_id': widget.caseId,
        'firm_id': widget.firmId,
        'message': text,
        'sender_name': senderName,
      });

      final currentUser = ref.read(userProvider);
      setState(() {
        _optimisticMessages.add(
          CaseComment(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
              final pendingOptimistic =
                  _optimisticMessages
                      .where(
                        (opt) =>
                            !streamMessages.any(
                              (s) =>
                                  s.message == opt.message &&
                                  s.senderId == opt.senderId,
                            ),
                      )
                      .toList();
              final allMessages = [...streamMessages, ...pendingOptimistic];

              if (pendingOptimistic.length < _optimisticMessages.length) {
                _optimisticMessages.removeWhere(
                  (opt) => streamMessages.any(
                    (s) =>
                        s.message == opt.message && s.senderId == opt.senderId,
                  ),
                );
              }

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
            error: (e, s) => Center(child: Text("Error: $e")),
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
      label = "Today";
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = "Yesterday";
    } else {
      label = DateFormat('dd MMM yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
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
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar (left side for others)
            if (!isMe) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: avatarColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Bubble
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        msg.senderName?.toUpperCase() ?? "ADVOCATE",
                        style: TextStyle(
                          fontSize: 9,
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
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color:
                                    isMe
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : const Color(0xFF94A3B8),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
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
            padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 20),
          const Text(
            "Start a Discussion",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              "Coordinate with your team members\nabout case strategy and updates",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
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
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Gradient send button
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(14),
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
                        ? const SizedBox(
                          width: 18,
                          height: 18,
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
