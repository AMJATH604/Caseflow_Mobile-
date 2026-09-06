import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../components/profile_avatar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Unified Chat Hub — WhatsApp-style full-screen layout
/// with search bar, filter chips, separate Chambers & DMs.
class ChatHubScreen extends ConsumerStatefulWidget {
  const ChatHubScreen({super.key});

  @override
  ConsumerState<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends ConsumerState<ChatHubScreen> {
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _chambersInfo;
  bool _loading = true;
  String? _myUserId;
  String? _myFirmId;
  String _searchQuery = '';
  int _selectedFilter = 0; // 0=All, 1=Unread, 2=Chambers, 3=DMs
  RealtimeChannel? _chatHubChannel;
  bool _realtimeSubscribed = false;

  @override
  void initState() {
    super.initState();
    _loadAllChats();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    if (_chatHubChannel != null) {
      Supabase.instance.client.removeChannel(_chatHubChannel!);
    }
    super.dispose();
  }

  void _subscribeToRealtime() {
    if (_realtimeSubscribed) return;
    _realtimeSubscribed = true;

    _chatHubChannel = Supabase.instance.client.channel('chat_hub_realtime_updates');
    _chatHubChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_conversations',
          callback: (payload) {
            if (mounted) _loadAllChats();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) {
            if (mounted) _loadAllChats();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'case_discussions',
          callback: (payload) {
            if (mounted) _loadAllChats();
          },
        )
        .subscribe();
  }

  Future<void> _loadAllChats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _myUserId = user.id;

    try {
      // 1. Fetch user profile to get firm ID
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('firm_id, id')
          .eq('id', user.id)
          .single();
      _myFirmId = profile['firm_id'] ?? profile['id'];

      // 2. Fetch Chambers Last Message
      if (_myFirmId != null) {
        final chambersLast = await Supabase.instance.client
            .from('case_discussions')
            .select('message, created_at, sender_name')
            .isFilter('case_id', null)
            .eq('firm_id', _myFirmId!)
            .order('created_at', ascending: false)
            .limit(1);

        _chambersInfo = {
          'name': 'Digital Chambers',
          'last_message': chambersLast.isNotEmpty ? chambersLast[0] : null,
        };
      }

      // 3. Fetch DM conversations where user is participant
      final res = await Supabase.instance.client
          .from('direct_conversations')
          .select()
          .or('participant_1.eq.${user.id},participant_2.eq.${user.id}')
          .order('last_message_at', ascending: false);

      final conversations = List<Map<String, dynamic>>.from(res);

      // Fetch partner profiles for each conversation
      final partnerIds = conversations.map((c) {
        return c['participant_1'] == user.id
            ? c['participant_2'] as String
            : c['participant_1'] as String;
      }).toSet();

      Map<String, Map<String, dynamic>> profileMap = {};
      if (partnerIds.isNotEmpty) {
        final profiles = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, avatar_url, practice_state, practice_district')
            .inFilter('id', partnerIds.toList());

        for (final p in profiles) {
          profileMap[p['id']] = p;
        }
      }

      // Fetch last message & unread count for each conversation
      for (final conv in conversations) {
        final partnerId = conv['participant_1'] == user.id
            ? conv['participant_2']
            : conv['participant_1'];
        conv['partner'] = profileMap[partnerId] ?? {'full_name': 'Unknown Advocate'};

        // Fetch last message
        final lastMsgRes = await Supabase.instance.client
            .from('direct_messages')
            .select('message, created_at, sender_id')
            .eq('conversation_id', conv['id'])
            .order('created_at', ascending: false)
            .limit(1);

        if (lastMsgRes.isNotEmpty) {
          conv['last_message'] = lastMsgRes[0];
        }

        // Fetch unread count
        final unreadRes = await Supabase.instance.client
            .from('direct_messages')
            .select('id')
            .eq('conversation_id', conv['id'])
            .neq('sender_id', user.id)
            .eq('is_read', false);

        conv['unread_count'] = unreadRes.length;
      }

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading chat list: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAdvocatePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AdvocatePickerSheet(),
    );
  }

  Future<void> _handleCameraTap() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked == null) return;

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _AdvocatePickerSheet(
          initialAttachment: File(picked.path),
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      for (final conv in _conversations) {
        final unread = conv['unread_count'] as int? ?? 0;
        if (unread > 0) {
          await SupabaseService.markDirectMessagesRead(conv['id']);
        }
      }
      await _loadAllChats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All messages marked as read ✅')),
        );
      }
    } catch (e) {
      debugPrint('Mark all read error: $e');
    }
  }

  void _showOptionsMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111B21) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(top: 10.h, bottom: 10.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: Color(0xFF00A884)),
              title: Text('Refresh Chats', style: GoogleFonts.inter(fontSize: 15.sp)),
              onTap: () {
                Navigator.pop(ctx);
                _loadAllChats();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_read_rounded, color: Color(0xFF00A884)),
              title: Text('Mark All as Read', style: GoogleFonts.inter(fontSize: 15.sp)),
              onTap: () {
                Navigator.pop(ctx);
                _markAllAsRead();
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_rounded, color: Color(0xFF00A884)),
              title: Text('Digital Chambers', style: GoogleFonts.inter(fontSize: 15.sp)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/chambers-chat');
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredConversations {
    var list = _conversations;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((conv) {
        final partner = conv['partner'] as Map<String, dynamic>;
        final name = (partner['full_name'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    }

    // Apply chip filter for unread
    if (_selectedFilter == 1) {
      list = list.where((conv) => (conv['unread_count'] as int? ?? 0) > 0).toList();
    }

    return list;
  }

  // ═══════════════════════════════════════════════════════
  // BUILD — WhatsApp-style full-screen layout
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111B21) : Colors.white;
    final accentColor = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Top Bar (Title + Action Icons) ──────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 0),
              child: Row(
                children: [
                  // Back button
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(20.r),
                    child: Padding(
                      padding: EdgeInsets.all(4.r),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : const Color(0xFF111B21),
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'CaseFlow',
                    style: GoogleFonts.inter(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  const Spacer(),
                  _actionIcon(Icons.camera_alt_outlined, isDark, _handleCameraTap),
                  _actionIcon(Icons.more_vert_rounded, isDark, () => _showOptionsMenu(context)),
                ],
              ),
            ),

            SizedBox(height: 14.h),

            // ─── Search Bar Pill ─────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                height: 40.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Ask Meta AI or Search',
                    hintStyle: GoogleFonts.inter(
                      color: isDark
                          ? const Color(0xFF8696A0)
                          : const Color(0xFF667781),
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? const Color(0xFF8696A0)
                          : const Color(0xFF667781),
                      size: 22,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: isDark
                        ? const Color(0xFFE9EDEF)
                        : const Color(0xFF111B21),
                  ),
                ),
              ),
            ),

            SizedBox(height: 12.h),

            // ─── Filter Chips ────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _filterChip('All', 0, isDark, accentColor),
                  SizedBox(width: 8.w),
                  _filterChip('Unread', 1, isDark, accentColor),
                  SizedBox(width: 8.w),
                  _filterChip('Chambers', 2, isDark, accentColor),
                  SizedBox(width: 8.w),
                  _filterChip('DMs', 3, isDark, accentColor),
                ],
              ),
            ),

            SizedBox(height: 8.h),

            // ─── Chat List ───────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: accentColor,
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAllChats,
                      color: accentColor,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 100.h),
                        children: _buildChatListItems(isDark),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAdvocatePicker(context),
        backgroundColor: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
        elevation: 4,
        heroTag: 'new_dm_fab',
        child: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  List<Widget> _buildChatListItems(bool isDark) {
    final showChambers = _selectedFilter == 0 || _selectedFilter == 2;
    final showDms = _selectedFilter == 0 || _selectedFilter == 1 || _selectedFilter == 3;

    final List<Widget> items = [];

    // Chambers tile
    if (showChambers && _chambersInfo != null && _searchQuery.isEmpty) {
      items.add(_buildChambersTile(isDark));
    }

    // DM tiles
    if (showDms) {
      final convs = _filteredConversations;
      if (convs.isEmpty && !showChambers) {
        items.add(_buildEmptyDmsState(isDark));
      } else {
        for (final conv in convs) {
          items.add(_buildConversationTile(conv, isDark));
        }
      }
    }

    // If nothing to show at all
    if (items.isEmpty) {
      items.add(_buildEmptyDmsState(isDark));
    }

    return items;
  }

  Widget _actionIcon(IconData icon, bool isDark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.all(10.r),
          child: Icon(
            icon,
            color: isDark ? const Color(0xFFAEBDC6) : const Color(0xFF54656F),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, int index, bool isDark, Color accent) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? accent.withValues(alpha: 0.2)
                  : accent.withValues(alpha: 0.12))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF0F2F5)),
          borderRadius: BorderRadius.circular(20.r),
          border: isSelected
              ? Border.all(color: accent.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? accent
                : (isDark
                    ? const Color(0xFF8696A0)
                    : const Color(0xFF667781)),
          ),
        ),
      ),
    );
  }

  // ─── Chambers Tile ─────────────────────────────────────

  Widget _buildChambersTile(bool isDark) {
    final lastMsg = _chambersInfo!['last_message'] as Map<String, dynamic>?;
    String preview = 'No messages yet';
    String time = '';

    if (lastMsg != null) {
      preview = lastMsg['message'] ?? '';
      final senderName = lastMsg['sender_name'] ?? 'Member';
      preview = '$senderName: $preview';

      final dt = DateTime.parse(lastMsg['created_at']);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        time = DateFormat('h:mm a').format(dt.toLocal());
      } else {
        time = DateFormat('MMM d').format(dt.toLocal());
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/chambers-chat'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              // Group avatar
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Digital Chambers',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFE9EDEF)
                                  : const Color(0xFF111B21),
                            ),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: isDark
                                  ? const Color(0xFF8696A0)
                                  : const Color(0xFF667781),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(
                          Icons.campaign_rounded,
                          size: 16.sp,
                          color: isDark
                              ? const Color(0xFF8696A0)
                              : const Color(0xFF667781),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            preview,
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: isDark
                                  ? const Color(0xFF8696A0)
                                  : const Color(0xFF667781),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── DM Conversation Tile ──────────────────────────────

  Widget _buildConversationTile(Map<String, dynamic> conv, bool isDark) {
    final partner = conv['partner'] as Map<String, dynamic>;
    final lastMsg = conv['last_message'] as Map<String, dynamic>?;
    final unread = conv['unread_count'] as int? ?? 0;
    final name = partner['full_name'] ?? 'Unknown';

    String preview = 'No messages yet';
    String time = '';
    if (lastMsg != null) {
      preview = lastMsg['message'] ?? '';
      final dt = DateTime.parse(lastMsg['created_at']);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        time = DateFormat('h:mm a').format(dt.toLocal());
      } else {
        time = DateFormat('MMM d').format(dt.toLocal());
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/dm/${conv['id']}'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              // Avatar
              ProfileAvatar(
                avatarUrl: partner['avatar_url'],
                name: name,
                radius: 26,
              ),
              SizedBox(width: 14.w),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFE9EDEF)
                                  : const Color(0xFF111B21),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: unread > 0
                                  ? const Color(0xFF00A884)
                                  : (isDark
                                      ? const Color(0xFF8696A0)
                                      : const Color(0xFF667781)),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        // Double tick for sent messages
                        if (lastMsg != null && lastMsg['sender_id'] == _myUserId) ...[
                          Icon(
                            Icons.done_all_rounded,
                            size: 16.sp,
                            color: isDark
                                ? const Color(0xFF8696A0)
                                : const Color(0xFF667781),
                          ),
                          SizedBox(width: 3.w),
                        ],
                        Expanded(
                          child: Text(
                            lastMsg != null && lastMsg['sender_id'] == _myUserId
                                ? 'You: $preview'
                                : preview,
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: isDark
                                  ? const Color(0xFF8696A0)
                                  : const Color(0xFF667781),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread > 0) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A884),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              '$unread',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildEmptyDmsState(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 60.h),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.chat_rounded,
              size: 48.sp,
              color: isDark
                  ? const Color(0xFF8696A0)
                  : const Color(0xFF667781),
            ),
            SizedBox(height: 16.h),
            Text(
              'No conversations yet',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE9EDEF)
                    : const Color(0xFF111B21),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Tap the message icon to start chatting',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: const Color(0xFF8696A0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ADVOCATE PICKER BOTTOM SHEET
// ═══════════════════════════════════════════════════════

class _AdvocatePickerSheet extends ConsumerStatefulWidget {
  final File? initialAttachment;
  const _AdvocatePickerSheet({this.initialAttachment});

  @override
  ConsumerState<_AdvocatePickerSheet> createState() =>
      _AdvocatePickerSheetState();
}

class _AdvocatePickerSheetState extends ConsumerState<_AdvocatePickerSheet> {
  String _search = '';
  List<Map<String, dynamic>> _advocates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdvocates();
  }

  Future<void> _fetchAdvocates() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      var query = Supabase.instance.client
          .from('profiles')
          .select('id, full_name, avatar_url, practice_state, practice_district')
          .eq('is_public_directory_enabled', true)
          .order('full_name');

      final res = await query;
      final list = List<Map<String, dynamic>>.from(res);

      // Exclude self
      if (userId != null) {
        list.removeWhere((a) => a['id'] == userId);
      }

      if (mounted) {
        setState(() {
          _advocates = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch advocates error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _advocates;
    final q = _search.toLowerCase();
    return _advocates.where((a) {
      final name = (a['full_name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  Future<void> _startConversation(Map<String, dynamic> advocate) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    final partnerId = advocate['id'] as String;

    try {
      // Check if conversation already exists
      final existing = await Supabase.instance.client
          .from('direct_conversations')
          .select('id')
          .or(
            'and(participant_1.eq.$myId,participant_2.eq.$partnerId),and(participant_1.eq.$partnerId,participant_2.eq.$myId)',
          )
          .limit(1);

      String convId;
      if (existing.isNotEmpty) {
        convId = existing[0]['id'];
      } else {
        // Create new conversation
        final newConv = await Supabase.instance.client
            .from('direct_conversations')
            .insert({
              'participant_1': myId,
              'participant_2': partnerId,
            })
            .select('id')
            .single();
        convId = newConv['id'];
      }

      if (widget.initialAttachment != null) {
        final url = await SupabaseService.uploadDirectMessageAttachment(
          file: widget.initialAttachment!,
          conversationId: convId,
        );
        if (url != null) {
          await SupabaseService.sendDirectMessage(
            convId,
            '📷 Photo',
            attachmentUrl: url,
            attachmentType: 'image',
          );
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close picker
        context.push('/dm/$convId');
      }
    } catch (e) {
      debugPrint('Start conversation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111B21) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 14.h),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'New Message',
                        style: GoogleFonts.inter(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
              child: Container(
                height: 38.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search advocate by name...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF8696A0),
                      fontSize: 14.sp,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF8696A0),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: isDark
                        ? const Color(0xFFE9EDEF)
                        : const Color(0xFF111B21),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ),
            // List
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: accentColor,
                      ),
                    )
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No advocates found',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8696A0),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final adv = _filtered[i];
                            return _buildAdvocateItem(adv, isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvocateItem(Map<String, dynamic> adv, bool isDark) {
    final name = adv['full_name'] ?? 'Unknown';
    final location = [
      adv['practice_district'],
      adv['practice_state'],
    ].where((s) => s != null).join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _startConversation(adv),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              ProfileAvatar(
                avatarUrl: adv['avatar_url'],
                name: name,
                radius: 24,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFE9EDEF)
                            : const Color(0xFF111B21),
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        location,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: const Color(0xFF8696A0),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
