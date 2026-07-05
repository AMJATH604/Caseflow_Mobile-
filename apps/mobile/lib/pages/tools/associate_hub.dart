import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/firm_service.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
    if (_profile == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) return const Center(child: Text('Profile error'));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_invitations.isNotEmpty) ...[
            _buildSectionHeader('FIRM INVITATIONS'),
            SizedBox(height: 12.h),
            ..._invitations.map((inv) => _buildInvitationCard(inv)),
            SizedBox(height: 24.h),
          ],

          if (_profile!.isFirmOwner) ...[
            _buildSectionHeader('RECRUIT NEW ASSOCIATE'),
            SizedBox(height: 12.h),
            _buildInviteForm(),
            SizedBox(height: 24.h),
            _buildSectionHeader('THE PROFESSIONAL TEAM'),
            SizedBox(height: 12.h),
            if (_members.isEmpty)
              _buildEmptyTeamState()
            else
              ..._members.map((m) => _buildMemberCard(m)),
          ] else if (_profile!.isFirmMember) ...[
            _buildSectionHeader('TEAM DIRECTORY'),
            SizedBox(height: 12.h),
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
        Container(width: 4.w, height: 16.h, color: AppTheme.accent),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
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
      padding: EdgeInsets.all(16.r),
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
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _inviteMember,
              child: const Text('SEND RECRUITMENT INVITE'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member invited successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMemberCard(FirmMember member) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp),
        ),
        subtitle: Text(
          member.status.toUpperCase(),
          style: const TextStyle(
            fontSize: 9.sp,
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
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_center_rounded, color: AppTheme.accent),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              "Invite from ${invitation.ownerName ?? 'Firm'}",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
            ),
          ),
          TextButton(
            onPressed: () => _acceptInv(invitation.id),
            child: const Text(
              'ACCEPT',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined firm successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNoFirmState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Column(
          children: [
            Icon(
              Icons.hub_rounded,
              size: 48,
              color: AppTheme.accent.withValues(alpha: 0.2),
            ),
            SizedBox(height: 16.h),
            const Text(
              'Firm Hub Inactive',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4.h),
            Text(
              'Create or join a legal firm to manage associates.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTeamState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(32.r),
      child: Text('No members yet.', style: TextStyle(color: Colors.grey)),
    ),
  );
}
