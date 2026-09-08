import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../services/supabase_service.dart';
import '../profile_avatar.dart';

/// WhatsApp-style "Forward to…" sheet. Lists the user's DM conversations plus
/// Digital Chambers, and forwards the given message content to the chosen
/// target. Works for both DM and Chambers messages (content is passed in as
/// plain fields, so it doesn't depend on either concrete message model).
class ChatForwardPicker extends StatefulWidget {
  final String messageText;
  final String? attachmentUrl;
  final String? attachmentType;

  const ChatForwardPicker({
    super.key,
    required this.messageText,
    this.attachmentUrl,
    this.attachmentType,
  });

  static Future<void> show(
    BuildContext context, {
    required String messageText,
    String? attachmentUrl,
    String? attachmentType,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatForwardPicker(
        messageText: messageText,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      ),
    );
  }

  @override
  State<ChatForwardPicker> createState() => _ChatForwardPickerState();
}

class _ChatForwardPickerState extends State<ChatForwardPicker> {
  bool _loading = true;
  bool _sending = false;
  String? _myFirmId;
  String? _myName;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, firm_id, full_name')
          .eq('id', user.id)
          .single();
      _myFirmId = profile['firm_id'] ?? profile['id'];
      _myName = profile['full_name'] ?? 'Team Member';

      final res = await Supabase.instance.client
          .from('direct_conversations')
          .select()
          .or('participant_1.eq.${user.id},participant_2.eq.${user.id}')
          .order('last_message_at', ascending: false);

      final conversations = List<Map<String, dynamic>>.from(res);
      final partnerIds = conversations.map((c) {
        return c['participant_1'] == user.id
            ? c['participant_2'] as String
            : c['participant_1'] as String;
      }).toSet();

      final profiles = partnerIds.isEmpty
          ? []
          : await Supabase.instance.client
              .from('profiles')
              .select('id, full_name, avatar_url')
              .inFilter('id', partnerIds.toList());

      final profileMap = {for (final p in profiles) p['id']: p};
      for (final conv in conversations) {
        final partnerId = conv['participant_1'] == user.id
            ? conv['participant_2']
            : conv['participant_1'];
        conv['partner'] =
            profileMap[partnerId] ?? {'full_name': 'Unknown Advocate'};
      }

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Forward picker load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forwardToConversation(String convId) async {
    setState(() => _sending = true);
    try {
      await SupabaseService.sendDirectMessage(
        convId,
        widget.messageText,
        attachmentUrl: widget.attachmentUrl,
        attachmentType: widget.attachmentType,
      );
      _done();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _forwardToChambers() async {
    if (_myFirmId == null) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.postDiscussion({
        'firm_id': _myFirmId,
        'case_id': null,
        'message': widget.messageText,
        'attachment_url': widget.attachmentUrl,
        'attachment_type': widget.attachmentType,
        'sender_name': _myName ?? 'Team Member',
      });
      _done();
    } catch (e) {
      _fail(e);
    }
  }

  void _done() {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message forwarded')),
    );
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Forward failed: $e')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111B21) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                children: [
                  Icon(Icons.forward_rounded, color: accent, size: 22),
                  SizedBox(width: 12.w),
                  Text(
                    'Forward to',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFE9EDEF)
                          : const Color(0xFF111B21),
                    ),
                  ),
                ],
              ),
            ),
            if (_sending) LinearProgressIndicator(color: accent, minHeight: 2.h),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : ListView(
                      controller: scrollController,
                      children: [
                        if (_myFirmId != null)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: accent,
                              child: const Icon(Icons.groups_rounded,
                                  color: Colors.white),
                            ),
                            title: Text(
                              'Digital Chambers',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15.sp,
                                color: isDark
                                    ? const Color(0xFFE9EDEF)
                                    : const Color(0xFF111B21),
                              ),
                            ),
                            onTap: _sending ? null : _forwardToChambers,
                          ),
                        ..._conversations.map((conv) {
                          final partner =
                              conv['partner'] as Map<String, dynamic>;
                          final name = partner['full_name'] ?? 'Unknown';
                          return ListTile(
                            leading: ProfileAvatar(
                              avatarUrl: partner['avatar_url'],
                              name: name,
                              radius: 20,
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15.sp,
                                color: isDark
                                    ? const Color(0xFFE9EDEF)
                                    : const Color(0xFF111B21),
                              ),
                            ),
                            onTap: _sending
                                ? null
                                : () => _forwardToConversation(
                                    conv['id'] as String),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
