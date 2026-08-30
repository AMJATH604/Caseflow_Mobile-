import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/firm_service.dart';
import '../services/supabase_service.dart';
import '../services/repositories/discussion_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import '../components/cf_shimmer_loader.dart';
import '../components/profile_avatar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FirmManagementScreen extends ConsumerStatefulWidget {
  const FirmManagementScreen({super.key});

  @override
  ConsumerState<FirmManagementScreen> createState() =>
      _FirmManagementScreenState();
}

class _FirmManagementScreenState extends ConsumerState<FirmManagementScreen> {
  final _emailController = TextEditingController();
  final _noticeController = TextEditingController();
  final _chatScrollController = ScrollController();
  bool _isLoading = false;
  bool _isUploading = false;
  List<FirmMember> _members = [];
  List<FirmMember> _invitations = [];
  UserProfile? _profile;
  final List<CaseComment> _optimisticNotices = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _noticeController.dispose();
    _chatScrollController.dispose();
    super.dispose();
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
        setState(() => _members = members);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation sent!')));
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

  Future<void> _acceptInvitation(String id) async {
    setState(() => _isLoading = true);
    try {
      await FirmService.acceptInvitation(id);
      await _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firm joined successfully!')),
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

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ─── Send Text Message ──
  Future<void> _sendMessage() async {
    final text = _noticeController.text.trim();
    if (text.isEmpty) return;
    final firmId = _profile?.firmId ?? _profile?.id;
    final senderName = _profile?.fullName ?? 'Team Member';

    // Optimistic add
    setState(() {
      _optimisticNotices.add(
        CaseComment(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          firmId: firmId ?? '',
          senderId: _profile?.id ?? '',
          message: text,
          senderName: senderName,
          createdAt: DateTime.now(),
        ),
      );
    });
    _noticeController.clear();
    _scrollToBottom();

    await SupabaseService.postDiscussion({
      'firm_id': firmId,
      'message': text,
      'case_id': null,
      'sender_name': senderName,
    });
  }

  // ─── Send Attachment ──
  Future<void> _sendAttachment({required String type}) async {
    final firmId = _profile?.firmId ?? _profile?.id;
    if (firmId == null) return;

    File? file;
    String? attachmentType;

    if (type == 'camera') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (picked == null) return;
      file = File(picked.path);
      attachmentType = 'image';
    } else if (type == 'gallery') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked == null) return;
      file = File(picked.path);
      attachmentType = 'image';
    } else if (type == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      file = File(result.files.first.path!);
      attachmentType = DiscussionRepository.getAttachmentType(file.path);
    }

    if (file == null) return;

    setState(() => _isUploading = true);

    final url = await DiscussionRepository.uploadAttachment(
      file: file,
      firmId: firmId,
    );

    if (url != null) {
      final senderName = _profile?.fullName ?? 'Team Member';
      await SupabaseService.postDiscussion({
        'firm_id': firmId,
        'message':
            attachmentType == 'image'
                ? '📷 Photo'
                : '📎 ${file.path.split('/').last}',
        'case_id': null,
        'sender_name': senderName,
        'attachment_url': url,
        'attachment_type': attachmentType,
      });
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload. Check your internet connection.'),
          ),
        );
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Share',
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachOption(
                        Icons.camera_alt_rounded,
                        'Camera',
                        Colors.pink,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'camera');
                        },
                      ),
                      _buildAttachOption(
                        Icons.photo_library_rounded,
                        'Gallery',
                        Colors.purple,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'gallery');
                        },
                      ),
                      _buildAttachOption(
                        Icons.insert_drive_file_rounded,
                        'Document',
                        Colors.blue,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'file');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildAttachOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading && _profile == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(child: CfShimmerLoader.dashboard()),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInitialData,
                color: CfColors.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_profile?.isFirmMember == true ||
                          (_profile?.isFirmOwner ?? false)) ...[
                        _buildSectionHeader('Digital Chambers'),
                        _buildNoticeBoard(),
                        SizedBox(height: 32.h),
                      ],
                      if (_invitations.isNotEmpty) ...[
                        _buildSectionHeader('Firm Invitations'),
                        ..._invitations.map((inv) => _buildInvitationCard(inv)),
                        SizedBox(height: 32.h),
                      ],
                      if (_profile?.isFirmOwner ?? false) ...[
                        _buildSectionHeader('Recruit Associate'),
                        _buildInviteForm(),
                        SizedBox(height: 32.h),
                        _buildSectionHeader('Legal Professional Hub'),
                        if (_members.isEmpty)
                          _buildEmptyTeamState()
                        else
                          ..._members.map((m) => _buildMemberCard(m)),
                      ] else if (_profile?.firmId != null) ...[
                        _buildSectionHeader('Chambers Status'),
                        _buildStaffFirmCard(),
                        SizedBox(height: 32.h),
                        _buildSectionHeader('The Team'),
                        ..._members.map((m) => _buildMemberCard(m)),
                      ] else ...[
                        _buildBusinessUpgradePrompt(),
                      ],
                      SizedBox(height: 100.h),
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

  Widget _buildHeader(BuildContext context, CfColorScheme colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textPrimary,
              size: 20,
            ),
            onPressed: () => context.go('/'),
          ),
          SizedBox(width: 4.w),
          Text(
            'Firm Operating System',
            style: CfTypography.headingLg.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, [CfColorScheme? colors]) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: CfColors.brand,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            title.toUpperCase(),
            style: CfTypography.labelMd.copyWith(
              color: colors?.textPrimary ?? const Color(0xFF1E293B),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ─── CHAMBERS CHAT ENTRY CARD ──────────────────────
  Widget _buildNoticeBoard() {
    return InkWell(
      onTap: () => context.push('/chambers-chat'),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52.w,
              height: 52.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chambers Chat',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Tap to open full conversation',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── REMAINING WIDGETS (unchanged logic, preserved) ──

  Widget _buildInviteForm() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: TextField(
                controller: _emailController,
                style: TextStyle(color: Color(0xFF1E293B), fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: "Junior's Professional Email",
                  hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _inviteMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'INITIALIZE RECRUITMENT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11.sp,
                    letterSpacing: 1,
                  ),
                ),
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
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        leading: ProfileAvatar(
          name: member.memberName ?? member.memberEmail,
          radius: 20,
          showBorder: false,
        ),
        title: Text(
          isMe
              ? '${member.memberName ?? member.memberEmail} (Me)'
              : (member.memberName ?? member.memberEmail),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            fontSize: 14.sp,
            letterSpacing: -0.5,
          ),
        ),
        subtitle: Text(
          member.status.toUpperCase(),
          style: TextStyle(
            color:
                member.status == 'accepted'
                    ? AppTheme.success.withValues(alpha: 0.7)
                    : AppTheme.accent.withValues(alpha: 0.7),
            fontSize: 9.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        trailing:
            (_profile?.isFirmOwner ?? false)
                ? IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.redAccent.withValues(alpha: 0.4),
                    size: 18,
                  ),
                  onPressed: () => _removeMember(member.id),
                )
                : null,
      ),
    );
  }

  Widget _buildStaffFirmCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.black,
              size: 24,
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Authenticated Chambers Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Full professional access to shared documents & cases',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
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
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.accent,
          child: Icon(Icons.business_rounded, color: Colors.black),
        ),
        title: const Text(
          'Professional Invitation',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          'Join flow by ${invitation.ownerName ?? invitation.ownerId}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12.sp,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _acceptInvitation(invitation.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          child: const Text(
            'Accept',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessUpgradePrompt() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(32.r),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                ),
              ),
              child: const Icon(
                Icons.account_tree_rounded,
                size: 48,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Professional Hub',
              style: GoogleFonts.inter(
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Transform CaseFlow into a shared chambers workspace. Recruit juniors and synchronize your legal operations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.sp,
                height: 1.5.h,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/upgrade'),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: Text(
                  'ACTIVATE BUSINESS NODES',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.sp,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTeamState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(40.r),
      margin: EdgeInsets.only(top: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_rounded,
            size: 48,
            color: Color(0xFFE2E8F0),
          ),
          SizedBox(height: 16.h),
          Text(
            'Recruit your first professional junior',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove Team Member?'),
            content: const Text(
              'They will no longer have access to cases in this firm.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
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
