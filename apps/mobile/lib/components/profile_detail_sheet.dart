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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ─── Hero Header ──────────────────
                        _buildHeroHeader(context, profile, isDark),

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
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No professional details added yet',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
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

                        const SizedBox(height: 40),
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
      padding: const EdgeInsets.all(24),
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
        borderRadius: BorderRadius.circular(28),
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
                padding: const EdgeInsets.all(4),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 3,
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
                      ? const SizedBox(
                          width: 14,
                          height: 14,
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
          const SizedBox(height: 16),

          // Name
          Text(
            profile.fullName ?? 'Advocate',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Email
          if (profile.email != null)
            Text(
              profile.email!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),

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
              const SizedBox(width: 10),
              _buildBadge(
                icon: Icons.circle,
                iconSize: 6,
                label: 'ONLINE',
                colors: [const Color(0xFF10B981), const Color(0xFF34D399)],
              ),
              if (profile.firmId != null) ...[
                const SizedBox(width: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors[0].withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors[0].withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors[0], size: iconSize),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
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
        borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
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
          const SizedBox(height: 4),
          ...children,
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: const Color(0xFF334155),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor.withValues(alpha: isDark ? 0.15 : 0.08),
            tierColor.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(tierIcon, color: tierColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tier PLAN',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: tierColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
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
                borderRadius: BorderRadius.circular(12),
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── ACTIONS ────────────────────────────────────────

  Widget _buildActionsSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
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
          const SizedBox(height: 12),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Update Profile Photo',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 20),
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
                const SizedBox(width: 12),
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
            const SizedBox(height: 16),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
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
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Photo updated!',
                    style: GoogleFonts.inter(fontSize: 13)),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
