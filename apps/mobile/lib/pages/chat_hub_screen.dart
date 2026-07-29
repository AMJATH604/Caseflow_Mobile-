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
    final headerColor = isDark ? const Color(0xFF202C33) : const Color(0xFF008069);
    final bgColor = isDark ? const Color(0xFF111B21) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: headerColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: headerColor,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 14.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'CaseFlow Messenger',
                        style: GoogleFonts.inter(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // Search bar — fixed visibility
                      Container(
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search conversations...',
                            hintStyle: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14.sp,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: Colors.white,
                          ),
                          cursorColor: Colors.white,
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
            ? Center(
                child: CircularProgressIndicator(
                  color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadAllChats,
                color: const Color(0xFF00A884),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 100.h),
                  children: [
                    // ═══ CHAMBERS SECTION ═══
                    if (_chambersInfo != null && _searchQuery.isEmpty) ...[
                      _buildSectionHeader('CHAMBERS', isDark),
                      _buildChambersTile(isDark),
                      // Divider
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 78.w),
                        child: Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFE8E8E8),
                        ),
                      ),
                    ],

                    // ═══ MESSAGES SECTION ═══
                    _buildSectionHeader('MESSAGES', isDark),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAdvocatePicker(context),
        backgroundColor: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
        elevation: 4,
        heroTag: 'new_dm_fab',
        child: const Icon(Icons.message_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildSectionHeader(String label, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 6.h),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark
                  ? const Color(0xFF00A884)
                  : const Color(0xFF008069),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF1F5F9),
            ),
          ),
        ],
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
      if (lastMsg['sender_id'] == _myUserId) {
        preview = 'You: $preview';
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
    final headerColor = isDark ? const Color(0xFF202C33) : const Color(0xFF008069);

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
                color: headerColor,
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
                        color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
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
