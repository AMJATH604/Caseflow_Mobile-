import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/firm_service.dart';
import '../../services/providers.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Recruit Associate — the firm hierarchy.
///
/// An advocate can be a senior (invites associates), an associate (accepted a
/// senior's invitation), or both. Associates see who they work under and the
/// rest of that team; seniors see everyone they have invited, beneath them.
class AssociateHub extends ConsumerStatefulWidget {
  const AssociateHub({super.key});

  @override
  ConsumerState<AssociateHub> createState() => _AssociateHubState();
}

class _AssociateHubState extends ConsumerState<AssociateHub> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  List<FirmMember> _members = [];
  List<SeniorFirm> _seniorFirms = [];
  UserProfile? _profile;

  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _profile = await SupabaseService.fetchProfile();
      // Both, independently: an advocate can lead a team and belong to
      // another senior's firm at the same time.
      final results = await Future.wait([
        FirmService.fetchMySeniorFirms(),
        if (_profile?.isFirmOwner ?? false) FirmService.fetchFirmMembers(),
      ]);
      _seniorFirms = results[0] as List<SeniorFirm>;
      _members = results.length > 1 ? results[1] as List<FirmMember> : [];
    } catch (e) {
      debugPrint('AssociateHub load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    if (_profile == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) return const Center(child: Text('Profile error'));

    final isSenior = _profile!.isFirmOwner;
    final isAssociate = _seniorFirms.isNotEmpty;

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAssociate) ...[
              _buildSectionHeader('YOUR SENIOR'),
              SizedBox(height: 12.h),
              ..._seniorFirms.map(_buildSeniorFirmCard),
              SizedBox(height: 12.h),
            ] else ...[
              _buildUnassignedBanner(),
              SizedBox(height: 20.h),
            ],
            if (isSenior) ...[
              _buildSectionHeader('RECRUIT NEW ASSOCIATE'),
              SizedBox(height: 12.h),
              _buildInviteForm(),
              SizedBox(height: 24.h),
              _buildSectionHeader('YOUR TEAM'),
              SizedBox(height: 12.h),
              _buildMyTeamCard(),
            ],
            if (!isSenior && !isAssociate) _buildNoFirmState(),
          ],
        ),
      ),
    );
  }

  // ─── Associate view ──────────────────────────────────────

  Widget _buildSeniorFirmCard(SeniorFirm firm) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: AppTheme.cardDecoration(isDark: _isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_rounded, color: AppTheme.accent, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'You are part of ',
                      children: [
                        TextSpan(
                          text: "${firm.ownerName}'s",
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(text: ' team'),
                      ],
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: _isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.only(left: 4.w),
            child: Text(
              'Joined ${DateFormat('d MMM yyyy').format(firm.joinedAt.toLocal())}',
              style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey),
            ),
          ),
          SizedBox(height: 14.h),
          _buildPersonRow(
            name: firm.ownerName,
            badge: 'SENIOR',
            badgeColor: AppTheme.accent,
            isRoot: true,
          ),
          ...firm.teammates.asMap().entries.map(
            (e) => _buildTreeChild(
              isLast: e.key == firm.teammates.length - 1,
              child: _buildPersonRow(
                name: e.value.isMe ? '${e.value.name} (You)' : e.value.name,
                badge: 'ASSOCIATE',
                badgeColor: _green,
                highlight: e.value.isMe,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isLoading ? null : () => _leaveTeam(firm),
              icon: Icon(Icons.logout_rounded, color: _red, size: 18.sp),
              label: Text(
                'Leave team',
                style: GoogleFonts.inter(
                  color: _red,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveTeam(SeniorFirm firm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Leave ${firm.ownerName}'s team?"),
        content: Text(
          "You'll lose access to ${firm.ownerName}'s firm cases, and any of them "
          "assigned to you will be unassigned. ${firm.ownerName} will be notified.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave team'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await FirmService.leaveTeam(firm.ownerId);
      // Firm cases, hearings and the dashboard all depend on the team.
      ref.read(dataRefreshProvider.notifier).state++;
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You left ${firm.ownerName}'s team")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave the team: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildUnassignedBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: AppTheme.cardDecoration(isDark: _isDark),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
            child: Icon(Icons.person_off_rounded, color: Colors.grey, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're not part of any team",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: _isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  "Accept a senior's invitation to join their team, or invite associates to start your own.",
                  style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Senior view ─────────────────────────────────────────

  Widget _buildMyTeamCard() {
    final accepted = _members.where((m) => m.status == 'accepted').length;
    final pending = _members.where((m) => m.status == 'pending').length;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: AppTheme.cardDecoration(isDark: _isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPersonRow(
            name: '${_profile!.fullName ?? 'You'} (You)',
            badge: 'SENIOR',
            badgeColor: AppTheme.accent,
            isRoot: true,
            subtitle: _members.isEmpty
                ? 'No associates invited yet'
                : '$accepted associate${accepted == 1 ? '' : 's'}'
                    '${pending > 0 ? ' · $pending pending' : ''}',
          ),
          if (_members.isEmpty)
            _buildTreeChild(
              isLast: true,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Text(
                  'Invite an associate by email above.',
                  style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey),
                ),
              ),
            )
          else
            ..._members.asMap().entries.map(
              (e) => _buildTreeChild(
                isLast: e.key == _members.length - 1,
                child: _buildPersonRow(
                  name: e.value.memberName ?? e.value.memberEmail,
                  badge: e.value.status.toUpperCase(),
                  badgeColor: _statusColor(e.value.status),
                  trailing: IconButton(
                    tooltip: 'Remove from team',
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: _isLoading ? null : () => _removeMember(e.value.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return _green;
      case 'rejected':
        return _red;
      default:
        return _amber;
    }
  }

  // ─── Tree building blocks ────────────────────────────────

  /// Indents [child] under the row above it and draws the connector line.
  Widget _buildTreeChild({required bool isLast, required Widget child}) {
    final lineColor = _isDark ? Colors.white24 : const Color(0xFFCBD5E1);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34.w,
            child: Stack(
              children: [
                // Vertical line: full height, or down to the elbow on the last child.
                Positioned(
                  left: 17.w,
                  top: 0,
                  bottom: 0,
                  child: FractionallySizedBox(
                    alignment: Alignment.topCenter,
                    heightFactor: isLast ? 0.5 : 1,
                    child: Container(width: 1.5, color: lineColor),
                  ),
                ),
                // Elbow into the row.
                Positioned(
                  left: 17.w,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(height: 1.5, color: lineColor),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPersonRow({
    required String name,
    required String badge,
    required Color badgeColor,
    bool isRoot = false,
    bool highlight = false,
    String? subtitle,
    Widget? trailing,
  }) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: highlight ? _green.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isRoot ? 20.r : 16.r,
            backgroundColor: badgeColor.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: isRoot ? 15.sp : 13.sp,
                color: badgeColor,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: isRoot ? 15.sp : 14.sp,
                    color: _isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              badge,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                color: badgeColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (trailing != null) trailing,
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
      decoration: AppTheme.cardDecoration(isDark: _isDark),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
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

  Future<void> _removeMember(String id) async {
    setState(() => _isLoading = true);
    await FirmService.removeMember(id);
    await _loadData();
    if (mounted) setState(() => _isLoading = false);
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
            Text(
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
}
