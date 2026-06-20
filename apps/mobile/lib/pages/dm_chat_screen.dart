import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/profile_avatar.dart';

class DmChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const DmChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  UserProfile? _myProfile;
  Map<String, dynamic>? _partnerProfile;
  Stream<List<DirectMessage>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _loadChatDetails();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatDetails() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      _myProfile = await SupabaseService.fetchProfile();

      // Fetch the conversation to find the partner ID
      final conv = await Supabase.instance.client
          .from('direct_conversations')
          .select()
          .eq('id', widget.conversationId)
          .single();

      final partnerId =
          conv['participant_1'] == user.id
              ? conv['participant_2']
              : conv['participant_1'];

      // Fetch partner profile
      final partnerProfile = await Supabase.instance.client
          .from('profiles')
          .select(
            'id, full_name, avatar_url, practice_state, practice_district',
          )
          .eq('id', partnerId)
          .single();

      // Mark messages as read
      await SupabaseService.markDirectMessagesRead(widget.conversationId);

      if (mounted) {
        setState(() {
          _partnerProfile = partnerProfile;
          _messagesStream = SupabaseService.directMessagesStream(
            widget.conversationId,
          );
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Load DM details error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    try {
      await SupabaseService.sendDirectMessage(widget.conversationId, text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F7FA),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_partnerProfile == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F7FA),
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Failed to load advocate details.')),
      );
    }

    final partnerName = _partnerProfile!['full_name'] ?? 'Unknown Advocate';
    final partnerLocation =
        [
          _partnerProfile!['practice_district'],
          _partnerProfile!['practice_state'],
        ].where((s) => s != null).join(', ');

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ProfileAvatar(
              avatarUrl: _partnerProfile!['avatar_url'],
              name: partnerName,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (partnerLocation.isNotEmpty)
                    Text(
                      partnerLocation,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color:
                            isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DirectMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return _buildEmptyState(partnerName, isDark);
                }

                // Scroll to bottom on new message
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myProfile?.id;
                    return _buildMessageBubble(msg, isMe, isDark);
                  },
                );
              },
            ),
          ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String name, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB).withAlpha(20),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              size: 40,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Say Hello to $name',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation now.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DirectMessage msg, bool isMe, bool isDark) {
    final timeStr = DateFormat('h:mm a').format(msg.createdAt.toLocal());
    final Color bubbleColor;
    final Color textColor;

    if (isMe) {
      bubbleColor = AppTheme.accent;
      textColor = Colors.white;
    } else {
      bubbleColor =
          isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
      textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMe ? const Radius.circular(16) : const Radius.circular(2),
            bottomRight:
                isMe ? const Radius.circular(2) : const Radius.circular(16),
          ),
          border:
              isMe
                  ? null
                  : Border.all(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFE2E8F0),
                  ),
          boxShadow:
              isMe
                  ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.03,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.message,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: textColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color:
                        isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : (isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8)),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color:
                        msg.isRead
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _msgController,
                  maxLines: null,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14.5,
                      color:
                          isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
