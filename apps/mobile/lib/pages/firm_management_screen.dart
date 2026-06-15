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
import '../components/profile_avatar.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Share',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
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
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
                        const SizedBox(height: 32),
                      ],
                      if (_invitations.isNotEmpty) ...[
                        _buildSectionHeader('Firm Invitations'),
                        ..._invitations.map((inv) => _buildInvitationCard(inv)),
                        const SizedBox(height: 32),
                      ],
                      if (_profile?.isFirmOwner ?? false) ...[
                        _buildSectionHeader('Recruit Associate'),
                        _buildInviteForm(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('Legal Professional Hub'),
                        if (_members.isEmpty)
                          _buildEmptyTeamState()
                        else
                          ..._members.map((m) => _buildMemberCard(m)),
                      ] else if (_profile?.firmId != null) ...[
                        _buildSectionHeader('Chambers Status'),
                        _buildStaffFirmCard(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('The Team'),
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
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E293B),
              size: 20,
            ),
            onPressed: () => context.go('/'),
          ),
          const SizedBox(width: 4),
          Text(
            'Firm Operating System',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
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
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: 2,
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chambers Chat',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to open full conversation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
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
                decoration: const InputDecoration(
                  hintText: "Junior's Professional Email",
                  hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'INITIALIZE RECRUITMENT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: ProfileAvatar(
          name: member.memberName ?? member.memberEmail,
          radius: 20,
          showBorder: false,
        ),
        title: Text(
          isMe
              ? '${member.memberName ?? member.memberEmail} (Me)'
              : (member.memberName ?? member.memberEmail),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            fontSize: 14,
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
            fontSize: 9,
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
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Authenticated Chambers Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Full professional access to shared documents & cases',
                  style: TextStyle(
                    fontSize: 12,
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
            fontSize: 12,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _acceptInvitation(invitation.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 24),
            Text(
              'Professional Hub',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Transform CaseFlow into a shared chambers workspace. Recruit juniors and synchronize your legal operations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/upgrade'),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text(
                  'ACTIVATE BUSINESS NODES',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.person_add_rounded,
            size: 48,
            color: Color(0xFFE2E8F0),
          ),
          SizedBox(height: 16),
          Text(
            'Recruit your first professional junior',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
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
