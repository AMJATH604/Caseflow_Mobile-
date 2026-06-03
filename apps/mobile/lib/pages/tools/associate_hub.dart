import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/firm_service.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';

class AssociateHub extends ConsumerStatefulWidget {
  const AssociateHub({super.key});

  @override
  ConsumerState<AssociateHub> createState() => _AssociateHubState();
}

class _AssociateHubState extends ConsumerState<AssociateHub> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  List<FirmMember> _members = [];
  List<FirmMember> _invitations = [];
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _profile = await SupabaseService.fetchProfile();
      if (_profile?.isFirmOwner ?? false) {
        _members = await FirmService.fetchFirmMembers();
      } else if (_profile?.firmId != null) {
        // Fetch members for associates using their firm_id
        _members = await FirmService.fetchFirmMembers(
          explicitOwnerId: _profile!.firmId,
        );
      }
      _invitations = await FirmService.fetchInvitations();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null && _isLoading)
      return const Center(child: CircularProgressIndicator());
    if (_profile == null) return const Center(child: Text("Profile error"));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_invitations.isNotEmpty) ...[
            _buildSectionHeader("FIRM INVITATIONS"),
            const SizedBox(height: 12),
            ..._invitations.map((inv) => _buildInvitationCard(inv)),
            const SizedBox(height: 24),
          ],

          if (_profile!.isFirmOwner) ...[
            _buildSectionHeader("RECRUIT NEW ASSOCIATE"),
            const SizedBox(height: 12),
            _buildInviteForm(),
            const SizedBox(height: 24),
            _buildSectionHeader("THE PROFESSIONAL TEAM"),
            const SizedBox(height: 12),
            if (_members.isEmpty)
              _buildEmptyTeamState()
            else
              ..._members.map((m) => _buildMemberCard(m)),
          ] else if (_profile!.isFirmMember) ...[
            _buildSectionHeader("TEAM DIRECTORY"),
            const SizedBox(height: 12),
            ..._members.map((m) => _buildMemberCard(m)),
          ] else ...[
            _buildNoFirmState(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: AppTheme.accent),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF6B7280),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInviteForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: "Associate's Email Address",
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _inviteMember,
              child: const Text("SEND RECRUITMENT INVITE"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await FirmService.inviteMember(email);
      _emailController.clear();
      await _loadData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Member invited successfully!")),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMemberCard(FirmMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE2E8F0),
          child: Icon(Icons.person_rounded, color: Colors.blueGrey, size: 20),
        ),
        title: Text(
          member.memberName ?? member.memberEmail,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          member.status.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppTheme.accent,
            letterSpacing: 1,
          ),
        ),
        trailing:
            (_profile!.isFirmOwner && member.memberId != _profile!.id)
                ? IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed: () => _removeMember(member.id),
                )
                : null,
      ),
    );
  }

  Future<void> _removeMember(String id) async {
    setState(() => _isLoading = true);
    await FirmService.removeMember(id);
    await _loadData();
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildInvitationCard(FirmMember invitation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_center_rounded, color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Invite from ${invitation.ownerName ?? 'Firm'}",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => _acceptInv(invitation.id),
            child: const Text(
              "ACCEPT",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInv(String id) async {
    setState(() => _isLoading = true);
    try {
      await FirmService.acceptInvitation(id);

      // ─── Immediate Refresh ──────────────────────────────────────────────
      // Invalidate providers to remove the "lag" - this forces an immediate
      // re-fetch showing new cases and updated profile status.
      ref.invalidate(userProfileProvider);
      ref.invalidate(casesProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(hearingsProvider);

      await _loadData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Joined firm successfully!")),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNoFirmState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.hub_rounded,
              size: 48,
              color: AppTheme.accent.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              "Firm Hub Inactive",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              "Create or join a legal firm to manage associates.",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTeamState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text("No members yet.", style: TextStyle(color: Colors.grey)),
    ),
  );
}
