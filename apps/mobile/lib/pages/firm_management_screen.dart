import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/firm_service.dart';
import '../services/supabase_service.dart';

import '../services/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class FirmManagementScreen extends ConsumerStatefulWidget {
  const FirmManagementScreen({super.key});

  @override
  ConsumerState<FirmManagementScreen> createState() => _FirmManagementScreenState();
}

class _FirmManagementScreenState extends ConsumerState<FirmManagementScreen> {
  final _emailController = TextEditingController();
  final _noticeController = TextEditingController();
  bool _isLoading = false;
  List<FirmMember> _members = [];
  List<FirmMember> _invitations = [];
  UserProfile? _profile;
  final List<CaseComment> _optimisticNotices = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      _profile = await SupabaseService.fetchProfile();
      if (_profile!.isFirmOwner) {
        _members = await FirmService.fetchFirmMembers();
      }
      _invitations = await FirmService.fetchInvitations();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await FirmService.inviteMember(email);
      _emailController.clear();
      final members = await FirmService.fetchFirmMembers();
      if (mounted) {
        setState(() {
          _members = members;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invitation sent!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptInvitation(String id) async {
    setState(() => _isLoading = true);
    try {
      await FirmService.acceptInvitation(id);
      await _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Firm joined successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInitialData,
                color: AppTheme.accent,
                backgroundColor: const Color(0xFF1E293B),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_profile?.isFirmMember == true || (_profile?.isFirmOwner ?? false)) ...[
                        _buildSectionHeader("Digital Chambers"),
                        _buildNoticeBoard(),
                        const SizedBox(height: 32),
                      ],
                      if (_invitations.isNotEmpty) ...[
                        _buildSectionHeader("Firm Invitations"),
                        ..._invitations.map((inv) => _buildInvitationCard(inv)),
                        const SizedBox(height: 32),
                      ],

                      if (_profile?.isFirmOwner ?? false) ...[
                        _buildSectionHeader("Recruit Associate"),
                        _buildInviteForm(),
                        const SizedBox(height: 32),
                        _buildSectionHeader("Legal Professional Hub"),
                        if (_members.isEmpty)
                          _buildEmptyTeamState()
                        else
                          ..._members.map((m) => _buildMemberCard(m)),
                      ] else if (_profile?.firmId != null) ...[
                        _buildSectionHeader("Chambers Status"),
                        _buildStaffFirmCard(),
                        const SizedBox(height: 32),
                        _buildSectionHeader("The Team"),
                        ..._members.map((m) => _buildMemberCard(m)),
                      ] else ...[
                        _buildBusinessUpgradePrompt(),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
            onPressed: () => context.go('/'),
          ),
          const SizedBox(width: 4),
          Text(
            "Firm Operating System",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w900, 
              color: Color(0xFF1E293B),
              letterSpacing: 2
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteForm() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _emailController,
                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Junior's Professional Email",
                  hintStyle: TextStyle(color: const Color(0xFFCBD5E1)),
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 18, color: const Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _inviteMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text("INITIALIZE RECRUITMENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(FirmMember member) {
    final bool isMe = member.memberId == _profile?.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.person_pin_rounded, color: Color(0xFF64748B), size: 20),
        ),
        title: Text(
          isMe ? "${member.memberName ?? member.memberEmail} (Me)" : (member.memberName ?? member.memberEmail),
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B), fontSize: 14, letterSpacing: -0.5),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            member.status.toUpperCase(), 
            style: TextStyle(
              color: member.status == 'accepted' ? AppTheme.success.withValues(alpha: 0.7) : AppTheme.accent.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            )
          ),
        ),
        trailing: (_profile?.isFirmOwner ?? false) ? IconButton(
          icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.4), size: 18),
          onPressed: () => _removeMember(member.id),
        ) : null,
      ),
    );
  }

  Widget _buildStaffFirmCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
            child: const Icon(Icons.verified_user_rounded, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Authenticated Chambers Profile", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 16)
                ),
                const SizedBox(height: 4),
                Text(
                  "Full professional access to shared documents & cases", 
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(FirmMember invitation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.accent,
          child: Icon(Icons.business_rounded, color: Colors.black),
        ),
        title: const Text("Professional Invitation", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        subtitle: Text("Join flow by ${invitation.ownerName ?? invitation.ownerId}", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        trailing: ElevatedButton(
          onPressed: () => _acceptInvitation(invitation.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildBusinessUpgradePrompt() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.account_tree_rounded, size: 48, color: AppTheme.accent),
            ),
            const SizedBox(height: 24),
            Text(
              "Professional Hub",
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), letterSpacing: -1),
            ),
            const SizedBox(height: 12),
            Text(
              "Transform CaseFlow into a shared chambers workspace. Recruit juniors and synchronize your legal operations.",
              textAlign: TextAlign.center,
              style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/upgrade'),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text("ACTIVATE BUSINESS NODES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeBoard() {
    return Consumer(
      builder: (context, ref, _) {
        final firmId = _profile?.firmId ?? _profile?.id;
        if (firmId == null) return const SizedBox.shrink();
        
        final noticesAsync = ref.watch(firmNoticesProvider(firmId));
        
        return Container(
          height: 350,
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            children: [
              Expanded(
                child: noticesAsync.when(
                  data: (streamNotices) {
                    // Merge stream + optimistic notices
                    final pendingOptimistic = _optimisticNotices.where(
                      (opt) => !streamNotices.any((s) => s.message == opt.message && s.senderId == opt.senderId),
                    ).toList();
                    final allNotices = [...streamNotices, ...pendingOptimistic];

                    // Clear synced ones
                    if (pendingOptimistic.length < _optimisticNotices.length) {
                      _optimisticNotices.removeWhere((opt) =>
                        streamNotices.any((s) => s.message == opt.message && s.senderId == opt.senderId)
                      );
                    }

                    if (allNotices.isEmpty) {
                      return const Center(child: Text("No notices yet.", style: TextStyle(color: Colors.grey, fontSize: 12)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: allNotices.length,
                      itemBuilder: (context, index) {
                        final msg = allNotices[index];
                        final isMe = msg.senderId == _profile?.id;
                        return _buildNoticeBubble(msg, isMe);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Error: $e")),
                ),
              ),
              _buildNoticeInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoticeBubble(CaseComment msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.accent : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
          border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderName ?? "Team Member",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accent.withValues(alpha: 0.8), letterSpacing: 0.5),
                ),
              ),
            Text(
              msg.message,
              style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 13, fontWeight: isMe ? FontWeight.w900 : FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.createdAt),
              style: TextStyle(fontSize: 8, color: (isMe ? Colors.black : Colors.white).withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _noticeController,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: "Broadcast to chambers...",
                hintStyle: TextStyle(color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, size: 22, color: AppTheme.accent),
            onPressed: () async {
              final text = _noticeController.text.trim();
              if (text.isEmpty) return;
              final firmId = _profile?.firmId ?? _profile?.id;
              final senderName = _profile?.fullName ?? "Team Member";
              
              await SupabaseService.postDiscussion({
                'firm_id': firmId,
                'message': text,
                'case_id': null,
                'sender_name': senderName,
              });

              setState(() {
                _optimisticNotices.add(CaseComment(
                  id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                  firmId: firmId ?? '',
                  senderId: _profile?.id ?? '',
                  message: text,
                  senderName: senderName,
                  createdAt: DateTime.now(),
                ));
              });
              _noticeController.clear();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTeamState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.person_add_rounded, size: 48, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          Text(
            "Recruit your first professional junior", 
            style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Team Member?"),
        content: const Text("They will no longer have access to cases in this firm."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirmService.removeMember(id);
        await _loadInitialData();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
