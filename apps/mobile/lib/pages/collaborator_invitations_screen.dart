import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/collaborator_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CollaboratorInvitationsScreen extends StatefulWidget {
  const CollaboratorInvitationsScreen({super.key});

  @override
  State<CollaboratorInvitationsScreen> createState() =>
      _CollaboratorInvitationsScreenState();
}

class _CollaboratorInvitationsScreenState
    extends State<CollaboratorInvitationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    try {
      final invites = await CollaboratorService.fetchMyInvitations();
      setState(() {
        _invitations = invites;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invitations: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(String id, String status) async {
    try {
      await CollaboratorService.respondToInvitation(id, status);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryLight,
      appBar: AppBar(
        title: Text(
          'Case Invitations',
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
              : _invitations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: EdgeInsets.all(16.r),
                itemCount: _invitations.length,
                itemBuilder: (context, index) {
                  final invite = _invitations[index];
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
                                      color: Color(0xFF64748B),
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
                                onPressed:
                                    () => _respond(invite['id'], 'rejected'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
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
                                onPressed:
                                    () => _respond(invite['id'], 'accepted'),
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
                },
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
            'When someone shares a case with you, it will appear here.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}
