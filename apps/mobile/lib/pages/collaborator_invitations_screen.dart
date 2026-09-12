import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/collaborator_service.dart';
import '../services/firm_service.dart';
import '../services/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CollaboratorInvitationsScreen extends ConsumerStatefulWidget {
  const CollaboratorInvitationsScreen({super.key});

  @override
  ConsumerState<CollaboratorInvitationsScreen> createState() =>
      _CollaboratorInvitationsScreenState();
}

class _CollaboratorInvitationsScreenState
    extends ConsumerState<CollaboratorInvitationsScreen> {
  bool _isLoading = true;
  // Case-sharing invitations (someone shared a specific case).
  List<Map<String, dynamic>> _caseInvitations = [];
  // Firm-membership invitations (a senior recruiting you to their firm).
  List<FirmMember> _firmInvitations = [];

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    try {
      // Load both invitation types together so the dashboard is the single
      // place every incoming invitation shows up.
      final results = await Future.wait([
        CollaboratorService.fetchMyInvitations(),
        FirmService.fetchInvitations(),
      ]);
      if (!mounted) return;
      setState(() {
        _caseInvitations = results[0] as List<Map<String, dynamic>>;
        _firmInvitations = results[1] as List<FirmMember>;
        _isLoading = false;
      });
      // Keep the dashboard "Invitations" badge in sync with this list.
      ref.invalidate(pendingInvitationsCountProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invitations: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Case invitation response ──────────────────────────────
  Future<void> _respondCase(String id, String status) async {
    try {
      await CollaboratorService.respondToInvitation(id, status);

      // Accepting grants access to a whole case, so the case list, hearings and
      // dashboard stats are all stale — same refresh _acceptFirm does. Without
      // this the newly shared case did not appear until a manual refresh.
      if (status == 'accepted') {
        ref.invalidate(casesProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(hearingsProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? 'Invitation Accepted'
                  : 'Invitation Rejected',
            ),
            backgroundColor:
                status == 'accepted' ? AppTheme.success : AppTheme.darkBorder,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─── Firm invitation response ──────────────────────────────
  Future<void> _acceptFirm(String id) async {
    try {
      await FirmService.acceptInvitation(id);

      // Joining a firm changes the user's profile, visible cases, hearings and
      // dashboard stats — refresh them immediately so there's no lag.
      ref.invalidate(userProfileProvider);
      ref.invalidate(casesProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(hearingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined firm successfully!')),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _declineFirm(String id) async {
    try {
      await FirmService.declineInvitation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation Rejected'),
            backgroundColor: AppTheme.darkBorder,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  bool get _hasNoInvitations =>
      _caseInvitations.isEmpty && _firmInvitations.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryLight,
      appBar: AppBar(
        title: Text(
          'Invitations',
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18.sp),
        ),
        backgroundColor: AppTheme.darkCard,
        elevation: 0,
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
              : _hasNoInvitations
              ? _buildEmptyState()
              : RefreshIndicator(
                onRefresh: _loadInvitations,
                color: AppTheme.accent,
                child: ListView(
                  padding: EdgeInsets.all(16.r),
                  children: [
                    if (_firmInvitations.isNotEmpty) ...[
                      _buildSectionHeader('FIRM INVITATIONS'),
                      SizedBox(height: 12.h),
                      ..._firmInvitations.map(_buildFirmInvitationCard),
                      SizedBox(height: 24.h),
                    ],
                    if (_caseInvitations.isNotEmpty) ...[
                      _buildSectionHeader('CASE INVITATIONS'),
                      SizedBox(height: 12.h),
                      ..._caseInvitations.map(_buildCaseInvitationCard),
                    ],
                  ],
                ),
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

  // ─── Firm invitation card ──────────────────────────────────
  Widget _buildFirmInvitationCard(FirmMember invitation) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firm Invitation',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 16.sp,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Invited by ${invitation.ownerName ?? 'a firm'}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 24.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineFirm(invitation.id),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: Text(
                    'REJECT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptFirm(invitation.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  child: Text(
                    'ACCEPT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Case invitation card ──────────────────────────────────
  Widget _buildCaseInvitationCard(Map<String, dynamic> invite) {
    final caseInfo = invite['cases'];
    final inviter =
        invite['profiles'] != null
            ? invite['profiles']['full_name']
            : 'A Colleague';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Icon(
                  Icons.folder_shared_rounded,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caseInfo?['case_title'] ?? 'Untitled Case',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 16.sp,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Invited by $inviter',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 24.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondCase(invite['id'], 'rejected'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: Text(
                    'REJECT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respondCase(invite['id'], 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  child: Text(
                    'ACCEPT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.mail_outline_rounded,
            size: 64,
            color: Color(0xFFE2E8F0),
          ),
          SizedBox(height: 16.h),
          Text(
            'No Pending Invitations',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Firm and case invitations will appear here.',
            style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}
