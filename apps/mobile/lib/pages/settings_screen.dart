import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_prefs.dart';
import '../components/profile_avatar.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../components/feedback_sheet.dart';
import '../services/app_localizations.dart';
import '../services/locale_service.dart';
import '../utils/app_fonts.dart';

/// Premium Settings Screen — Silicon-level design.
///
/// Sections: Account, Notifications, Appearance, Privacy, Data & Storage, About
/// Features a glassmorphic card layout with smooth animations and functional toggles.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  // Notification toggles
  bool _dmNotifications = true;
  bool _chamberNotifications = true;
  bool _hearingReminders = true;
  bool _notifSound = true;
  bool _notifVibration = true;

  // Privacy toggles
  bool _publicDirectory = true;

  // Appearance
  bool _isDarkMode = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          // Keys come from NotificationPrefs, which is the side that acts on
          // them in FcmService. Sharing the constants is what stops the two
          // halves drifting apart — they already had, which is why these
          // switches did nothing at all.
          _dmNotifications = prefs.getBool(NotificationPrefs.dmKey) ?? true;
          _chamberNotifications =
              prefs.getBool(NotificationPrefs.chamberKey) ?? true;
          _hearingReminders =
              prefs.getBool(NotificationPrefs.hearingKey) ?? true;
          _notifSound = prefs.getBool(NotificationPrefs.soundKey) ?? true;
          _notifVibration =
              prefs.getBool(NotificationPrefs.vibrationKey) ?? true;
          _publicDirectory = prefs.getBool('settings_public_directory') ?? true;
          _isDarkMode = prefs.getBool('settings_dark_mode') ?? false;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── Hero Header ──────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeroHeader(context, profile, isDark),
            ),

            // ─── Account ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.person_rounded,
                title: 'Account',
                color: AppTheme.accent,
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildActionTile(
                  isDark,
                  icon: Icons.manage_accounts_rounded,
                  title: 'My account',
                  subtitle: 'Edit your details, email, password, or delete your account',
                  color: AppTheme.accent,
                  onTap: () => context.push('/account'),
                ),
              ]),
            ),

            // ─── Notification Settings ────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.notifications_active_rounded,
                title: l10n.get('section_notifications'),
                color: const Color(0xFF3B82F6),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildToggleTile(
                  isDark,
                  icon: Icons.chat_bubble_rounded,
                  title: l10n.get('direct_messages'),
                  subtitle: l10n.get('direct_messages_sub'),
                  value: _dmNotifications,
                  color: const Color(0xFF6366F1),
                  onChanged: (v) {
                    setState(() => _dmNotifications = v);
                    _saveBool(NotificationPrefs.dmKey, v);
                  },
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  isDark,
                  icon: Icons.forum_rounded,
                  title: l10n.get('chamber_messages'),
                  subtitle: l10n.get('chamber_messages_sub'),
                  value: _chamberNotifications,
                  color: const Color(0xFF0EA5E9),
                  onChanged: (v) {
                    setState(() => _chamberNotifications = v);
                    _saveBool(NotificationPrefs.chamberKey, v);
                  },
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  isDark,
                  icon: Icons.event_rounded,
                  title: l10n.get('hearing_reminders'),
                  subtitle: l10n.get('hearing_reminders_sub'),
                  value: _hearingReminders,
                  color: const Color(0xFFF59E0B),
                  onChanged: (v) {
                    setState(() => _hearingReminders = v);
                    _saveBool(NotificationPrefs.hearingKey, v);
                  },
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  isDark,
                  icon: Icons.volume_up_rounded,
                  title: l10n.get('notification_sound'),
                  subtitle: l10n.get('notification_sound_sub'),
                  value: _notifSound,
                  color: const Color(0xFF10B981),
                  onChanged: (v) {
                    setState(() => _notifSound = v);
                    _saveBool(NotificationPrefs.soundKey, v);
                  },
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  isDark,
                  icon: Icons.vibration_rounded,
                  title: l10n.get('vibration'),
                  subtitle: l10n.get('vibration_sub'),
                  value: _notifVibration,
                  color: const Color(0xFF8B5CF6),
                  onChanged: (v) {
                    setState(() => _notifVibration = v);
                    _saveBool(NotificationPrefs.vibrationKey, v);
                  },
                ),
              ]),
            ),

            // ─── Appearance ───────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.palette_rounded,
                title: l10n.get('section_appearance'),
                color: const Color(0xFF8B5CF6),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildDarkModeToggle(isDark),
                _buildDivider(isDark),
                _buildLanguageTile(isDark),
              ]),
            ),

            // ─── Privacy ─────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.shield_rounded,
                title: l10n.get('section_privacy'),
                color: const Color(0xFF10B981),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildToggleTile(
                  isDark,
                  icon: Icons.public_rounded,
                  title: l10n.get('public_directory'),
                  subtitle: l10n.get('public_directory_sub'),
                  value: _publicDirectory,
                  color: const Color(0xFF10B981),
                  onChanged: (v) async {
                    setState(() => _publicDirectory = v);
                    _saveBool('settings_public_directory', v);
                    // Also update the profile in Supabase
                    try {
                      final userId =
                          SupabaseService.client.auth.currentUser?.id;
                      if (userId != null) {
                        await SupabaseService.client
                            .from('profiles')
                            .update({'is_public_directory_enabled': v}).eq(
                                'id', userId);
                      }
                    } catch (_) {
                      // Not saved: put the switch back rather than show a
                      // setting the directory does not have.
                      if (!mounted) return;
                      setState(() => _publicDirectory = !v);
                      _saveBool('settings_public_directory', !v);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not update the directory setting. '
                            'Check your connection and try again.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ]),
            ),

            // ─── Data & Storage ──────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.storage_rounded,
                title: l10n.get('section_data'),
                color: const Color(0xFFF59E0B),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildActionTile(
                  isDark,
                  icon: Icons.cached_rounded,
                  title: l10n.get('clear_image_cache'),
                  subtitle: l10n.get('clear_image_cache_sub'),
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    _showSnack('Image cache cleared successfully');
                  },
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  isDark,
                  icon: Icons.refresh_rounded,
                  title: l10n.get('refresh_all_data'),
                  subtitle: l10n.get('refresh_all_data_sub'),
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    ref.invalidate(userProfileProvider);
                    ref.read(dataRefreshProvider.notifier).state++;
                    _showSnack('Data refreshed successfully');
                  },
                ),
              ]),
            ),

            // ─── Help & Feedback ───────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.feedback_rounded,
                title: l10n.get('section_help'),
                color: const Color(0xFF6366F1),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildActionTile(
                  isDark,
                  icon: Icons.send_rounded,
                  title: l10n.get('send_feedback'),
                  subtitle: l10n.get('send_feedback_sub'),
                  color: const Color(0xFF3B82F6),
                  onTap: _openFeedbackSheet,
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  isDark,
                  icon: Icons.help_outline_rounded,
                  title: l10n.get('help_center'),
                  subtitle: l10n.get('help_center_sub'),
                  color: const Color(0xFF10B981),
                  onTap: () => _showSnack('Coming soon'),
                ),
              ]),
            ),

            // ─── About ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.info_rounded,
                title: l10n.get('section_about'),
                color: const Color(0xFF64748B),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildInfoTile(
                  isDark,
                  icon: Icons.apps_rounded,
                  title: l10n.get('app_version'),
                  trailing: '2.0.0',
                  color: const Color(0xFF6366F1),
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  isDark,
                  icon: Icons.description_rounded,
                  title: l10n.get('terms'),
                  subtitle: l10n.get('terms_sub'),
                  color: const Color(0xFF64748B),
                  onTap: () => _showSnack('Coming soon'),
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  isDark,
                  icon: Icons.privacy_tip_rounded,
                  title: l10n.get('privacy_policy'),
                  subtitle: l10n.get('privacy_policy_sub'),
                  color: const Color(0xFF64748B),
                  onTap: () => _showSnack('Coming soon'),
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  isDark,
                  icon: Icons.star_rounded,
                  title: l10n.get('rate_app'),
                  subtitle: l10n.get('rate_app_sub'),
                  color: const Color(0xFFF59E0B),
                  onTap: () => _showSnack('Coming soon'),
                ),
              ]),
            ),

            // ─── Sign Out ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: _buildSignOutButton(isDark),
              ),
            ),

            // ─── Footer ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'CaseFlow',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white24
                              : const Color(0xFFCBD5E1),
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Your Practice, Perfected',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFE2E8F0),
                          letterSpacing: 0.5,
                        ).indicSafe,
                      ),
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

  // ═══════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroHeader(
    BuildContext context,
    dynamic profile,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
      child: Row(
        children: [
          // Avatar
          Container(
            padding: EdgeInsets.all(3.r),
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
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ProfileAvatar(
              avatarUrl: profile?.avatarUrl,
              name: profile?.fullName,
              radius: 32,
              showBorder: false,
            ),
          ),
          SizedBox(width: 16.w),
          // Name & email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName ?? 'User',
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  profile?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ).indicSafe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8.h),
                // Subscription badge
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        profile?.subscriptionTier == 'free'
                            ? Icons.layers_rounded
                            : Icons.workspace_premium_rounded,
                        color: profile?.subscriptionTier == 'free'
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFFFBBF24),
                        size: 12,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        (profile?.subscriptionTier ?? 'Free').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 1,
                        ).indicSafe,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    bool isDark, {
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          SizedBox(width: 10.w),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 1.5,
            ).indicSafe,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, {required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ).indicSafe,
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ).indicSafe,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _buildPremiumSwitch(value, color, onChanged),
        ],
      ),
    );
  }

  Widget _buildPremiumSwitch(
    bool value,
    Color activeColor,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        width: 48.w,
        height: 28.h,
        padding: EdgeInsets.all(3.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          gradient: value
              ? LinearGradient(
                  colors: [activeColor, activeColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: value ? null : const Color(0xFFE2E8F0),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22.w,
            height: 22.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                    : [const Color(0xFFF59E0B), const Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDark ? l10n.get('dark_mode') : l10n.get('light_mode'),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ).indicSafe,
                ),
                SizedBox(height: 2.h),
                Text(
                  isDark
                      ? l10n.get('dark_mode_sub')
                      : l10n.get('light_mode_sub'),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ).indicSafe,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _buildPremiumSwitch(
            _isDarkMode,
            const Color(0xFF6366F1),
            (v) async {
              setState(() => _isDarkMode = v);
              await _saveBool('settings_dark_mode', v);
              if (mounted) {
                ref.read(themeModeProvider.notifier).state =
                    v ? ThemeMode.dark : ThemeMode.light;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : const Color(0xFF1E293B),
                      ).indicSafe,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ).indicSafe,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Language ────────────────────────────────────────────
  // Tappable version of the info tile. The trailing chip shows the active
  // language in its own script, so a user who cannot read English can still
  // recognise the current setting and find their way back here.
  Widget _buildLanguageTile(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final current = LocaleService.languageFor(ref.watch(localeProvider));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showLanguagePicker,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 18,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  l10n.get('language'),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ).indicSafe.indicSafe,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  current.label,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ).indicSafe.indicSafe,
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                Icons.chevron_right_rounded,
                color:
                    isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  l10n.get('choose_language'),
                  style: GoogleFonts.inter(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ).indicSafe.indicSafe,
                ),
                SizedBox(height: 6.h),
                Text(
                  l10n.get('language_sheet_note'),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    height: 1.45,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ).indicSafe.indicSafe,
                ),
                SizedBox(height: 16.h),
                ...LocaleService.supported.map(
                  (lang) => _buildLanguageOption(sheetContext, isDark, lang),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext sheetContext,
    bool isDark,
    AppLanguage lang,
  ) {
    // `read`, not `watch`: this runs inside the modal route's builder, which
    // is outside this widget's build. Watching there would not rebuild the
    // sheet anyway, and the sheet is popped as soon as a language is picked.
    final selected = ref.read(localeProvider).languageCode == lang.code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () async {
          await ref.read(localeProvider.notifier).setLocale(lang.locale);
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF0EA5E9).withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0EA5E9)
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Native script first — this is the line a user who cannot
                    // read English needs to recognise.
                    Text(
                      lang.label,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : const Color(0xFF1E293B),
                      ).indicSafe.indicSafe,
                    ),
                    if (lang.label != lang.englishName) ...[
                      SizedBox(height: 2.h),
                      Text(
                        lang.englishName,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ).indicSafe,
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    bool isDark, {
    required IconData icon,
    required String title,
    required String trailing,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ).indicSafe,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ).indicSafe,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Divider(
        height: 1.h,
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
      ),
    );
  }

  Widget _buildSignOutButton(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final shouldSignOut = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Text(
                l10n.get('sign_out'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              content: Text(
                'Are you sure you want to sign out of CaseFlow?',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ).indicSafe,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    l10n.get('cancel'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ).indicSafe,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    l10n.get('sign_out'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ).indicSafe,
                  ),
                ),
              ],
            ),
          );
          if (shouldSignOut == true && mounted) {
            await SupabaseService.signOut();
          }
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                l10n.get('sign_out'),
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                ).indicSafe,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFeedbackSheet() {
    try {
      FeedbackSheet.show(context, screenName: 'Settings');
    } catch (e) {
      debugPrint('Failed to open feedback sheet: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8.w),
            Text(message, style: GoogleFonts.inter(fontSize: 13.sp).indicSafe),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        backgroundColor: const Color(0xFF334155),
      ),
    );
  }
}
