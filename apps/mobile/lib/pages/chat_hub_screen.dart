import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/providers.dart';
import '../components/profile_avatar.dart';
import 'chambers_chat_screen.dart';

/// Unified Chat Hub with two tabs:
/// 1. Chambers — Group chat for firm (existing Digital Chambers)
/// 2. Messages — 1-on-1 DMs between advocates
class ChatHubScreen extends ConsumerStatefulWidget {
  const ChatHubScreen({super.key});

  @override
  ConsumerState<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends ConsumerState<ChatHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F7FA),
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
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Chat Hub',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
              unselectedLabelColor: isDark
                  ? const Color(0xFF64748B)
                  : const Color(0xFF94A3B8),
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hub_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Chambers'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Messages'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Chambers (existing group chat)
          const ChambersChatScreen(),
          // Tab 2: Direct Messages
          _DirectMessagesTab(
            onNewMessage: () => _showAdvocatePicker(context),
          ),
        ],
      ),
    );
  }

  // ─── Advocate Picker for New DM ─────────────────────

  void _showAdvocatePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AdvocatePickerSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════
// DIRECT MESSAGES TAB
// ═══════════════════════════════════════════════════════

class _DirectMessagesTab extends ConsumerStatefulWidget {
  final VoidCallback onNewMessage;
  const _DirectMessagesTab({required this.onNewMessage});

  @override
  ConsumerState<_DirectMessagesTab> createState() => _DirectMessagesTabState();
}

class _DirectMessagesTabState extends ConsumerState<_DirectMessagesTab> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _myUserId = user.id;

    try {
      // Fetch conversations where user is participant
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

      // Fetch last message for each conversation
      for (final conv in conversations) {
        final partnerId = conv['participant_1'] == user.id
            ? conv['participant_2']
            : conv['participant_1'];
        conv['partner'] = profileMap[partnerId] ?? {'full_name': 'Unknown'};

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
      debugPrint('Error loading conversations: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    return Stack(
      children: [
        if (_conversations.isEmpty)
          _buildEmptyState(isDark)
        else
          RefreshIndicator(
            onRefresh: _loadConversations,
            color: AppTheme.accent,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _conversations.length,
              itemBuilder: (context, index) =>
                  _buildConversationTile(_conversations[index], isDark),
            ),
          ),
        // New message FAB
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: widget.onNewMessage,
              backgroundColor: Colors.transparent,
              elevation: 0,
              heroTag: 'new_dm_fab',
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            context.push('/dm/${conv['id']}');
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                ProfileAvatar(
                  avatarUrl: partner['avatar_url'],
                  name: name,
                  radius: 24,
                ),
                const SizedBox(width: 14),
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
                                fontSize: 15,
                                fontWeight: unread > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: unread > 0
                                    ? AppTheme.accent
                                    : (isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: unread > 0
                                    ? (isDark
                                        ? Colors.white70
                                        : const Color(0xFF334155))
                                    : (isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8)),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unread',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          location,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.forum_rounded,
              size: 48,
              color: AppTheme.accent.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Messages Yet',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Start a conversation with any advocate from the directory',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onNewMessage,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('New Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
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
            backgroundColor: AppTheme.error,
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: AppTheme.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'New Message',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
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
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No advocates found',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startConversation(adv),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                ProfileAvatar(
                  avatarUrl: adv['avatar_url'],
                  name: name,
                  radius: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          location,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppTheme.accent,
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
