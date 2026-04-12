import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

      // Optimistic: add message to local list immediately
      final currentUser = ref.read(userProvider);
      setState(() {
        _optimisticMessages.add(CaseComment(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          caseId: widget.caseId,
          firmId: widget.firmId,
          senderId: currentUser?.id ?? '',
          message: text,
          senderName: senderName,
          createdAt: DateTime.now(),
        ));
      });

      _messageController.clear();
      // Scroll to bottom after sending
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: discussionsAsync.when(
            data: (streamMessages) {
              // Merge: stream messages + optimistic ones not yet in stream
              final pendingOptimistic = _optimisticMessages.where(
                (opt) => !streamMessages.any((s) => 
                  s.message == opt.message && s.senderId == opt.senderId
                ),
              ).toList();
              final allMessages = [...streamMessages, ...pendingOptimistic];

              // Clear synced optimistic messages
              if (pendingOptimistic.length < _optimisticMessages.length) {
                _optimisticMessages.removeWhere((opt) => 
                  streamMessages.any((s) => s.message == opt.message && s.senderId == opt.senderId)
                );
              }

              if (allMessages.isEmpty) {
                return _buildEmptyState(isDark);
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: allMessages.length,
                itemBuilder: (context, index) {
                  final msg = allMessages[index];
                  final isMe = msg.senderId == currentUser?.id;
                  return _buildMessageBubble(msg, isMe, isDark);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error: $e")),
          ),
        ),
        _buildInputArea(isDark),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 24),
          Text(
            "NO MESSAGES YET",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFF64748B), letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Start a conversation about this case.",
              textAlign: TextAlign.center,
              style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CaseComment msg, bool isMe, bool isDark) {
    final timeStr = DateFormat('hh:mm a').format(msg.createdAt);
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  msg.senderName?.toUpperCase() ?? "ADVOCATE",
                  style: TextStyle(fontSize: 8, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.accent : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.message,
                    style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeStr.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: isMe ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF94A3B8),
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

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(fontSize: 13, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                : const Icon(Icons.send_rounded, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}
