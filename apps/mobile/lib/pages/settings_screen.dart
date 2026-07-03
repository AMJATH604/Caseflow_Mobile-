import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../services/fcm_service.dart';
import '../components/profile_avatar.dart';
import '../components/profile_detail_sheet.dart';
import '../theme/app_theme.dart';

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
          _dmNotifications = prefs.getBool('settings_dm_notif') ?? true;
          _chamberNotifications =
              prefs.getBool('settings_chamber_notif') ?? true;
          _hearingReminders = prefs.getBool('settings_hearing_reminders') ?? true;
          _notifSound = prefs.getBool('settings_notif_sound') ?? true;
          _notifVibration = prefs.getBool('settings_notif_vibration') ?? true;
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

            // ─── Notification Settings ────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                color: const Color(0xFF3B82F6),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildToggleTile(
                  isDark,
                  icon: Icons.chat_bubble_rounded,
                  title: 'Direct Messages',
                  subtitle: 'Get notified for new DM conversations',
                  value: _dmNotifications,
                  color: const Color(0xFF6366F1),
                  onChanged: (v) {
                    setState(() => _dmNotifications = v);
                    _saveBool('settings_dm_notif', v);
                  },
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  isDark,
                  icon: Icons.forum_rounded,
                  title: 'Chamber Messages',
                  subtitle: 'Notifications for firm chamber discussions',
                  value: _chamberNotifications,
                  color: const Color(0xFF0EA5E9),
                  onChanged: (v) {
                    setState(() => _chamberNotifications = v);
                    _saveBool('settings_chamber_notif', v);
                  },
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  isDark,
                  icon: Icons.event_rounded,
                  title: 'Hearing Reminders',
                  subtitle: 'Receive reminders before upcoming hearings',
                  value: _hearingReminders,
                  color: const Color(0xFFF59E0B),
                  onChanged: (v) {
                    setState(() => _hearingReminders = v);
                    _saveBool('settings_hearing_reminders', v);
                  },
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  isDark,
                  icon: Icons.volume_up_rounded,
                  title: 'Notification Sound',
                  subtitle: 'Play a sound for incoming notifications',
                  value: _notifSound,
                  color: const Color(0xFF10B981),
                  onChanged: (v) {
                    setState(() => _notifSound = v);
                    _saveBool('settings_notif_sound', v);
                  },
                ),
                _buildDivider(isDark),
                _buildToggleTile(
                  isDark,
                  icon: Icons.vibration_rounded,
                  title: 'Vibration',
                  subtitle: 'Vibrate on notification',
                  value: _notifVibration,
                  color: const Color(0xFF8B5CF6),
                  onChanged: (v) {
                    setState(() => _notifVibration = v);
                    _saveBool('settings_notif_vibration', v);
                  },
                ),
              ]),
            ),

            // ─── Appearance ───────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.palette_rounded,
                title: 'Appearance',
                color: const Color(0xFF8B5CF6),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildDarkModeToggle(isDark),
                _buildDivider(isDark),
                _buildInfoTile(
                  isDark,
                  icon: Icons.language_rounded,
                  title: 'Language',
                  trailing: 'English',
                  color: const Color(0xFF0EA5E9),
                ),
              ]),
            ),

            // ─── Privacy ─────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.shield_rounded,
                title: 'Privacy',
                color: const Color(0xFF10B981),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildToggleTile(
                  isDark,
                  icon: Icons.public_rounded,
                  title: 'Public Directory',
                  subtitle: 'Show your profile in the advocate directory',
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
                    } catch (_) {}
                  },
                ),
              ]),
            ),

            // ─── Data & Storage ──────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.storage_rounded,
                title: 'Data & Storage',
                color: const Color(0xFFF59E0B),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildActionTile(
                  isDark,
                  icon: Icons.cached_rounded,
                  title: 'Clear Image Cache',
                  subtitle: 'Free up space by clearing cached images',
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
                  title: 'Refresh All Data',
                  subtitle: 'Force re-sync all data from server',
                  color: const Color(0xFF3B82F6),
                  onTap: () {
                    ref.invalidate(userProfileProvider);
                    ref.read(dataRefreshProvider.notifier).state++;
                    _showSnack('Data refreshed successfully');
                  },
                ),
              ]),
            ),

            // ─── About ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                isDark,
                icon: Icons.info_rounded,
                title: 'About',
                color: const Color(0xFF64748B),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildSettingsCard(isDark, children: [
                _buildInfoTile(
                  isDark,
                  icon: Icons.apps_rounded,
                  title: 'App Version',
                  trailing: '2.0.0',
                  color: const Color(0xFF6366F1),
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  isDark,
                  icon: Icons.description_rounded,
                  title: 'Terms & Conditions',
                  subtitle: 'Read our terms of service',
                  color: const Color(0xFF64748B),
                  onTap: () => _showSnack('Coming soon'),
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  isDark,
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  color: const Color(0xFF64748B),
                  onTap: () => _showSnack('Coming soon'),
                ),
                _buildDivider(isDark),
                _buildActionTile(
                  isDark,
                  icon: Icons.star_rounded,
                  title: 'Rate CaseFlow',
                  subtitle: 'Help us improve with your feedback',
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
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white24
                              : const Color(0xFFCBD5E1),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Practice, Perfected',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFE2E8F0),
                          letterSpacing: 0.5,
                        ),
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
      child: Row(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(3),
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
          const SizedBox(width: 16),
          // Name & email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName ?? 'User',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Subscription badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 6),
                      Text(
                        (profile?.subscriptionTier ?? 'Free').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Edit profile arrow
          GestureDetector(
            onTap: () => ProfileDetailSheet.show(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: Colors.white70,
                size: 18,
              ),
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, {required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
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
            width: 22,
            height: 22,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                    : [const Color(0xFFF59E0B), const Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDark ? 'Dark Mode' : 'Light Mode',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark
                      ? 'Switch to light theme'
                      : 'Switch to dark theme',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
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

  Widget _buildInfoTile(
    bool isDark, {
    required IconData icon,
    required String title,
    required String trailing,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
      ),
    );
  }

  Widget _buildSignOutButton(bool isDark) {
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
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Sign Out',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              content: Text(
                'Are you sure you want to sign out of CaseFlow?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          );
          if (shouldSignOut == true && mounted) {
            await SupabaseService.signOut();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(message, style: GoogleFonts.inter(fontSize: 13)),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF334155),
      ),
    );
  }
}
