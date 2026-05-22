import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  final List<_FeatureItem> _features = [
    _FeatureItem("Know Your Rights", "Everyday legal guides", Icons.menu_book_rounded, const [Color(0xFFD4AF37), Color(0xFFB8860B)], "/know-your-rights"),
    _FeatureItem("Bare Acts", "BNS, BNSS, CPC, Constitution", Icons.library_books_rounded, const [Color(0xFF8B5CF6), Color(0xFF6366F1)], "/citizen-tools", toolId: "bare_acts"),
    _FeatureItem("Court Fee", "Calculate court fees", Icons.calculate_rounded, const [Color(0xFFF59E0B), Color(0xFFEF6C00)], "/citizen-tools", toolId: "court-fee"),
    _FeatureItem("Legal Dictionary", "500+ legal terms", Icons.import_contacts_rounded, const [Color(0xFFEF4444), Color(0xFFDC2626)], "/citizen-tools", toolId: "legal_dictionary"),
    _FeatureItem("Track My Case", "CNR case lookup", Icons.search_rounded, const [Color(0xFF10B981), Color(0xFF059669)], "/track-case"),
    _FeatureItem("AI Legal Help", "Ask legal questions", Icons.auto_awesome_rounded, const [Color(0xFF6366F1), Color(0xFF4F46E5)], "/ai-chat"),
    _FeatureItem("Find Advocate", "Search lawyers near you", Icons.person_search_rounded, const [Color(0xFF3B82F6), Color(0xFF2563EB)], "/advocate-directory"),
    _FeatureItem("Legal News", "Latest legal updates", Icons.newspaper_rounded, const [Color(0xFFDC2626), Color(0xFFB91C1C)], "/legal-pulse"),
    _FeatureItem("Court Holidays", "2026 holiday calendar", Icons.calendar_month_rounded, const [Color(0xFFFF6B35), Color(0xFFE65100)], "/citizen-tools", toolId: "holiday_list"),
    _FeatureItem("Stamp Duty", "Calculate stamp values", Icons.receipt_long_rounded, const [Color(0xFFFFB300), Color(0xFFF57F17)], "/citizen-tools", toolId: "stamp_values"),
    _FeatureItem("Interest", "Calculate interest", Icons.percent_rounded, const [Color(0xFF9C27B0), Color(0xFF7B1FA2)], "/citizen-tools", toolId: "interest"),
    _FeatureItem("Partition Share", "Hindu & Muslim law", Icons.family_restroom_rounded, const [Color(0xFFEC407A), Color(0xFFC62828)], "/citizen-tools", toolId: "partition_calculator"),
    _FeatureItem("MACT Claims", "Accident compensation", Icons.directions_car_rounded, const [Color(0xFFE53935), Color(0xFFB71C1C)], "/citizen-tools", toolId: "mact_calculator"),
    _FeatureItem("Maintenance", "Sec 144 BNSS / HAMA", Icons.account_balance_wallet_rounded, const [Color(0xFF7C4DFF), Color(0xFF651FFF)], "/citizen-tools", toolId: "maintenance_calculator"),
    _FeatureItem("Legal Templates", "PDF & Word drafts", Icons.description_rounded, const [Color(0xFFD4AF37), Color(0xFFB8860B)], "/citizen-tools", toolId: "legal_templates"),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // Banner
              _buildBanner(),
              const SizedBox(height: 24),

              // Quick Actions
              _buildSectionTitle("Quick Actions"),
              const SizedBox(height: 12),
              _buildQuickActions(),
              const SizedBox(height: 24),

              // All Tools Grid
              _buildSectionTitle("Legal Resources"),
              const SizedBox(height: 12),
              _buildFeaturesGrid(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Legal Knowledge Hub",
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Know Your Rights. Protect Your Future.",
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    final isGuest = GoRouterState.of(context).matchedLocation.startsWith('/guest');
    final targetRoute = isGuest ? '/guest-know-your-rights' : '/know-your-rights';

    return InkWell(
      onTap: () => context.push(targetRoute),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // Premium deep blue gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.5), // Elegant gold border
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, color: Color(0xFFD4AF37), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "EVERYDAY LEGAL ENCYCLOPEDIA",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD4AF37),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Did You Know? Every Indian has the right to know the law. Tap here to browse your Everyday Legal Encyclopedia in simple terms.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      "Explore Guides →",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.gavel_rounded, size: 40, color: Color(0xFFD4AF37)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0F172A),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final isGuest = GoRouterState.of(context).matchedLocation.startsWith('/guest');
    final trackRoute = isGuest ? '/guest-track-case' : '/track-case';
    final toolsRoute = isGuest ? '/guest-tools' : '/citizen-tools';
    final rightsRoute = isGuest ? '/guest-know-your-rights' : '/know-your-rights';

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildQuickActionCard("Know Your\nRights", Icons.menu_book_rounded, const [Color(0xFFD4AF37), Color(0xFFB8860B)], () => context.push(rightsRoute)),
          _buildQuickActionCard("Track\nMy Case", Icons.search_rounded, const [Color(0xFF10B981), Color(0xFF059669)], () => context.push(trackRoute)),
          _buildQuickActionCard("AI Legal\nHelp", Icons.auto_awesome_rounded, const [Color(0xFF6366F1), Color(0xFF4F46E5)], () {
            if (isGuest) {
              _showAuthRequiredDialog(context, "AI Legal Help");
            } else {
              context.push('/ai-chat');
            }
          }),
          _buildQuickActionCard("Find an\nAdvocate", Icons.person_search_rounded, const [Color(0xFF3B82F6), Color(0xFF2563EB)], () {
            if (isGuest) {
              _showAuthRequiredDialog(context, "Find Advocate");
            } else {
              context.push('/advocate-directory');
            }
          }),
          _buildQuickActionCard("Court\nFee", Icons.calculate_rounded, const [Color(0xFFF59E0B), Color(0xFFEF6C00)], () => context.push('$toolsRoute?tool=court-fee')),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String label, IconData icon, List<Color> gradient, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 110,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(bool isMobile) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: _features.length,
      itemBuilder: (context, index) {
        final feature = _features[index];
        return _buildFeatureCard(feature, index);
      },
    );
  }

  Widget _buildFeatureCard(_FeatureItem feature, int index) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final delay = (index * 0.05).clamp(0.0, 0.5);
        final progress = ((_animController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () {
          final isGuest = GoRouterState.of(context).matchedLocation.startsWith('/guest');
          
          String targetRoute = feature.route;
          if (isGuest) {
            if (targetRoute == "/citizen-tools") {
              targetRoute = "/guest-tools";
            } else if (targetRoute == "/track-case") {
              targetRoute = "/guest-track-case";
            } else if (targetRoute == "/know-your-rights") {
              targetRoute = "/guest-know-your-rights";
            }
          }
          
          final requiresAuth = feature.route == "/ai-chat" || 
                               feature.route == "/advocate-directory" || 
                               feature.route == "/legal-pulse";
                               
          if (isGuest && requiresAuth) {
            _showAuthRequiredDialog(context, feature.title);
          } else {
            if (feature.toolId != null) {
              context.push('$targetRoute?tool=${feature.toolId}');
            } else {
              context.push(targetRoute);
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      feature.gradient[0].withValues(alpha: 0.15),
                      feature.gradient[1].withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: feature.gradient[0].withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(feature.icon, color: feature.gradient[0], size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                feature.title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                feature.subtitle.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthRequiredDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        title: Text(
          "Sign In Required",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          "You need to sign in or create an account to use $featureName.\n\nIt takes less than a minute and unlocks personalized legal tools, saved cases, and AI legal help.",
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login?role=citizen');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              "Sign In / Sign Up",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String route;
  final String? toolId;

  const _FeatureItem(this.title, this.subtitle, this.icon, this.gradient, this.route, {this.toolId});
}
