import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../components/profile_avatar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Unified Chat Hub containing Chambers Group and DM conversations
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

  @override
  void initState() {
    super.initState();
    _loadAllChats();
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

  List<Map<String, dynamic>> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    final q = _searchQuery.toLowerCase();
    return _conversations.where((conv) {
      final partner = conv['partner'] as Map<String, dynamic>;
      final name = (partner['full_name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF0F172A)),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                        : [const Color(0xFFEEF2FF), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 90, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'CaseFlow Messenger',
                        style: GoogleFonts.outfit(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        height: 46.h,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search chats...',
                            hintStyle: GoogleFonts.inter(
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontSize: 14.sp,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF4F46E5),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              )
            : RefreshIndicator(
                onRefresh: _loadAllChats,
                color: const Color(0xFF4F46E5),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // 1. Digital Chambers Pinned Group Chat
                    if (_chambersInfo != null && _searchQuery.isEmpty) ...[
                      _buildChambersTile(isDark),
                      SizedBox(height: 24.h),
                      Row(
                        children: [
                          Text(
                            'DIRECT MESSAGES',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Divider(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                    ],

                    // 2. DM Conversations
                    if (_filteredConversations.isEmpty)
                      _buildEmptyDmsState(isDark)
                    else
                      ..._filteredConversations.map(
                        (conv) => _buildConversationTile(conv, isDark),
                      ),
                  ],
                ),
              ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAdvocatePicker(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          heroTag: 'new_dm_fab',
          child: const Icon(Icons.message_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFEEF2FF),
          width: 1.5.w,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/chambers-chat'),
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(18.r),
            child: Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.h,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Digital Chambers',
                            style: GoogleFonts.outfit(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        preview,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv, bool isDark) {
    final partner = conv['partner'] as Map<String, dynamic>;
    final lastMsg = conv['last_message'] as Map<String, dynamic>?;
    final unread = conv['unread_count'] as int? ?? 0;
    final name = partner['full_name'] ?? 'Unknown';
    final location = [
      partner['practice_district'],
      partner['practice_state'],
    ].where((s) => s != null).join(', ');

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
      if (lastMsg['sender_id'] == _myUserId) {
        preview = 'You: $preview';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/dm/${conv['id']}'),
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                ProfileAvatar(
                  avatarUrl: partner['avatar_url'],
                  name: name,
                  radius: 24,
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
                              name,
                              style: GoogleFonts.outfit(
                                fontSize: 15.sp,
                                fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                color: unread > 0
                                    ? const Color(0xFF4F46E5)
                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                                color: unread > 0
                                    ? (isDark ? Colors.white70 : const Color(0xFF1E293B))
                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unread > 0) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '$unread',
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
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
      ),
    );
  }

  Widget _buildEmptyDmsState(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 60.h),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: Color(0xFF4F46E5),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No Direct Messages Yet',
              style: GoogleFonts.outfit(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Tap the chat icon to message advocates.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
  const _AdvocatePickerSheet();

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

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: Color(0xFF4F46E5),
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'New Message',
                    style: GoogleFonts.outfit(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // Search bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search advocate by name...',
                    hintStyle: GoogleFonts.inter(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      fontSize: 14.sp,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                    )
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No advocates found',
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
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

    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startConversation(adv),
          borderRadius: BorderRadius.circular(14.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
            child: Row(
              children: [
                ProfileAvatar(
                  avatarUrl: adv['avatar_url'],
                  name: name,
                  radius: 22,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          location,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF4F46E5),
                    size: 16,
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
