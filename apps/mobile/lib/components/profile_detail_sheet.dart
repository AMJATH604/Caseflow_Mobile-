import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'profile_avatar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/account_switcher_service.dart';

/// Premium profile detail bottom sheet — Silicon-level design.
///
/// Shows all user details collected during signup in a gorgeous
/// glassmorphic card layout with gradient accents, smooth animations,
/// and contextual action buttons.
class ProfileDetailSheet extends ConsumerStatefulWidget {
  const ProfileDetailSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ProfileDetailSheet(),
    );
  }

  @override
  ConsumerState<ProfileDetailSheet> createState() => _ProfileDetailSheetState();
}

class _ProfileDetailSheetState extends ConsumerState<ProfileDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  bool _isUploadingPhoto = false;
  List<Map<String, dynamic>> _savedAccounts = [];
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    // Auto-save current session
    final profile = ref.read(userProfileProvider).valueOrNull;
    await AccountSwitcherService.saveCurrentSession(
      fullName: profile?.fullName,
      avatarUrl: profile?.avatarUrl,
    );
    final accounts = await AccountSwitcherService.getSavedAccounts();
    if (mounted) setState(() => _savedAccounts = accounts);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: profile == null
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            : FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      children: [
                        // ─── Drag Handle ──────────────────
                        SizedBox(height: 12.h),
                        Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(height: 8.h),

                        // ─── Hero Header ──────────────────
                        _buildHeroHeader(context, profile, isDark),

                        // ─── Account Switcher ──────────────
                        if (_savedAccounts.length > 1)
                          _buildAccountSwitcher(context, profile, isDark),

                        // ─── Professional Info ────────────
                        _buildSection(
                          context,
                          isDark,
                          title: 'Professional Details',
                          icon: Icons.badge_rounded,
                          iconColor: const Color(0xFF6366F1),
                          children: [
                            if (profile.registrationNumber != null)
                              _buildInfoRow(
                                isDark,
                                icon: Icons.numbers_rounded,
                                label: 'Bar Registration',
                                value: profile.registrationNumber!,
                                accentColor: const Color(0xFF6366F1),
                              ),
                            if (profile.practiceState != null)
                              _buildInfoRow(
                                isDark,
                                icon: Icons.location_on_rounded,
                                label: 'Practice State',
                                value: profile.practiceState!,
                                accentColor: const Color(0xFF0EA5E9),
                              ),
                            if (profile.practiceDistrict != null)
                              _buildInfoRow(
                                isDark,
                                icon: Icons.map_rounded,
                                label: 'District',
                                value: profile.practiceDistrict!,
                                accentColor: const Color(0xFF14B8A6),
                              ),
                            if (profile.officeAddress != null)
                              _buildInfoRow(
                                isDark,
                                icon: Icons.business_rounded,
                                label: 'Office Address',
                                value: profile.officeAddress!,
                                accentColor: const Color(0xFFF59E0B),
                              ),
                            if (profile.registrationNumber == null &&
                                profile.practiceState == null &&
                                profile.practiceDistrict == null &&
                                profile.officeAddress == null)
                              Padding(
                                padding: EdgeInsets.all(16.r),
                                child: Text(
                                  'No professional details added yet',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // ─── Contact Info ─────────────────
                        _buildSection(
                          context,
                          isDark,
                          title: 'Contact',
                          icon: Icons.contact_mail_rounded,
                          iconColor: const Color(0xFF10B981),
                          children: [
                            if (profile.email != null)
                              _buildInfoRow(
                                isDark,
                                icon: Icons.email_rounded,
                                label: 'Email',
                                value: profile.email!,
                                accentColor: const Color(0xFF10B981),
                                copyable: true,
                              ),
                            if (profile.mobileNumber != null)
                              _buildInfoRow(
                                isDark,
                                icon: Icons.phone_rounded,
                                label: 'Mobile',
                                value: profile.mobileNumber!,
                                accentColor: const Color(0xFF2563EB),
                                copyable: true,
                              ),
                          ],
                        ),

                        // ─── Subscription Info ────────────
                        _buildSubscriptionCard(context, profile, isDark),

                        // ─── Actions ──────────────────────
                        _buildActionsSection(context, isDark),

                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ─── HERO HEADER ────────────────────────────────────────

  Widget _buildHeroHeader(
    BuildContext context,
    UserProfile profile,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A5F),
            Color(0xFF312E81),
          ],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Photo + edit button
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ProfileAvatar(
                  avatarUrl: profile.avatarUrl,
                  name: profile.fullName,
                  radius: 48,
                  showBorder: false,
                ),
              ),
              // Edit photo button
              GestureDetector(
                onTap: () => _showPhotoPicker(context, profile),
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 3.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isUploadingPhoto
                      ? SizedBox(
                          width: 14.w,
                          height: 14.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Name
          Text(
            profile.fullName ?? 'Advocate',
            style: GoogleFonts.outfit(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),

          // Email
          if (profile.email != null)
            Text(
              profile.email!,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: 16.h),

          // Role + Status badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(
                icon: profile.isAdvocate
                    ? Icons.gavel_rounded
                    : Icons.person_rounded,
                label: profile.isAdvocate ? 'ADVOCATE' : 'CITIZEN',
                colors: profile.isAdvocate
                    ? [const Color(0xFF6366F1), const Color(0xFF818CF8)]
                    : [const Color(0xFF10B981), const Color(0xFF34D399)],
              ),
              SizedBox(width: 10.w),
              _buildBadge(
                icon: Icons.circle,
                iconSize: 6,
                label: 'ONLINE',
                colors: [const Color(0xFF10B981), const Color(0xFF34D399)],
              ),
              if (profile.firmId != null) ...[
                SizedBox(width: 10.w),
                _buildBadge(
                  icon: Icons.business_center_rounded,
                  label: 'FIRM MEMBER',
                  colors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required List<Color> colors,
    double iconSize = 12,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: colors[0].withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: colors[0].withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors[0], size: iconSize),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: colors[0],
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ─── INFO SECTION ────────────────────────────────────

  Widget _buildSection(
    BuildContext context,
    bool isDark, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                SizedBox(width: 12.w),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          ...children,
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    bool copyable = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied $label'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    backgroundColor: const Color(0xFF334155),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SUBSCRIPTION CARD ──────────────────────────────

  Widget _buildSubscriptionCard(
    BuildContext context,
    UserProfile profile,
    bool isDark,
  ) {
    final tier = profile.subscriptionTier.toUpperCase();
    final Color tierColor;
    final IconData tierIcon;

    switch (profile.subscriptionTier) {
      case 'business':
        tierColor = const Color(0xFFF59E0B);
        tierIcon = Icons.diamond_rounded;
        break;
      case 'pro':
        tierColor = const Color(0xFF6366F1);
        tierIcon = Icons.workspace_premium_rounded;
        break;
      default:
        tierColor = const Color(0xFF64748B);
        tierIcon = Icons.layers_rounded;
    }

    String statusText = 'Free Plan';
    if (profile.isTrialActive) {
      final daysLeft =
          profile.trialEndsAt!.difference(DateTime.now()).inDays;
      statusText = 'Trial · $daysLeft days left';
    } else if (profile.isSubscriptionActive) {
      statusText =
          'Active until ${DateFormat('MMM d, y').format(profile.currentPeriodEnd!)}';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor.withValues(alpha: isDark ? 0.15 : 0.08),
            tierColor.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: tierColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(tierIcon, color: tierColor, size: 22),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tier PLAN',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: tierColor,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (profile.isFree)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Upgrade',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── ACCOUNT SWITCHER ──────────────────────────────

  Widget _buildAccountSwitcher(
    BuildContext context,
    UserProfile currentProfile,
    bool isDark,
  ) {
    final currentUserId = AccountSwitcherService.currentUserId;
    final otherAccounts = _savedAccounts
        .where((a) => a['userId'] != currentUserId)
        .toList();

    if (otherAccounts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: const Icon(
                    Icons.switch_account_rounded,
                    color: Color(0xFF2563EB),
                    size: 16,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'SWITCH ACCOUNT',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          // Account list
          ...otherAccounts.map((account) => _buildAccountTile(
            context,
            account,
            currentProfile,
            isDark,
          )),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    Map<String, dynamic> account,
    UserProfile currentProfile,
    bool isDark,
  ) {
    final email = account['email'] as String? ?? '';
    final fullName = account['fullName'] as String? ?? 'Account';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: _isSwitching ? null : () => _switchAccount(context, account, currentProfile),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Name & email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Switch indicator
                if (_isSwitching)
                  SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Switch',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _switchAccount(
    BuildContext context,
    Map<String, dynamic> account,
    UserProfile currentProfile,
  ) async {
    setState(() => _isSwitching = true);

    final success = await AccountSwitcherService.switchToAccount(
      account,
      currentFullName: currentProfile.fullName,
      currentAvatarUrl: currentProfile.avatarUrl,
    );

    if (mounted) {
      setState(() => _isSwitching = false);
      if (success) {
        Navigator.pop(context);
        // Refresh all data for the new account
        ref.invalidate(userProfileProvider);
        ref.read(dataRefreshProvider.notifier).state++;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.switch_account_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 10.w),
                Text(
                  'Switched to ${account['fullName'] ?? account['email']}',
                  style: GoogleFonts.inter(fontSize: 13.sp),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 10.w),
                const Text('Session expired. Please sign in again.'),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
        // Remove the expired account
        await AccountSwitcherService.removeAccount(
          account['userId'] as String,
        );
        await _loadSavedAccounts();
      }
    }
  }

  // ─── ACTIONS ────────────────────────────────────────

  Widget _buildActionsSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          _buildActionButton(
            isDark,
            icon: Icons.person_add_alt_rounded,
            label: 'Add Another Account',
            color: const Color(0xFF2563EB),
            onTap: () {
              Navigator.pop(context);
              GoRouter.of(context).go('/login');
            },
          ),
          SizedBox(height: 12.h),
          _buildActionButton(
            isDark,
            icon: Icons.settings_rounded,
            label: 'Settings',
            color: const Color(0xFF64748B),
            onTap: () {
              Navigator.pop(context);
              GoRouter.of(context).go('/settings');
            },
          ),
          SizedBox(height: 12.h),
          _buildActionButton(
            isDark,
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: const Color(0xFFEF4444),
            onTap: () async {
              Navigator.pop(context);
              await SupabaseService.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    bool isDark, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SizedBox(width: 14.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PHOTO PICKER ───────────────────────────────────

  void _showPhotoPicker(BuildContext context, UserProfile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Update Profile Photo',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _buildPhotoOption(
                    isDark: isDark,
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadPhoto(context, profile, ImageSource.camera);
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildPhotoOption(
                    isDark: isDark,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF059669),
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadPhoto(context, profile, ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(
    BuildContext context,
    UserProfile profile,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);
      final bytes = await picked.readAsBytes();
      await SupabaseService.updateProfilePhoto(profile.id, bytes);
      ref.invalidate(userProfileProvider);

      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 10.w),
                Text('Photo updated!',
                    style: GoogleFonts.inter(fontSize: 13.sp)),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
