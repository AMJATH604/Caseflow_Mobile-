import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/onboarding_service.dart';
import '../router/app_router.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _cardController;
  String? _hoveredRole;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Stop infinite animations after 12s
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted) _bgController.stop();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                Color(0xFF0A0E27),
                Color(0xFF141B3D),
                Color(0xFF0D1B3E),
                Color(0xFF1A1040),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.0,
                0.3 + 0.1 * sin(_bgController.value * pi),
                0.6 + 0.1 * cos(_bgController.value * pi),
                1.0,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: SizedBox(
                height: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Title
                      AnimatedBuilder(
                        animation: _cardController,
                        builder: (context, child) {
                          final opacity = (_cardController.value * 2).clamp(0.0, 1.0);
                          return Opacity(opacity: opacity, child: child);
                        },
                        child: Column(
                          children: [
                            // Logo
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Welcome to CaseFlow",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "How would you like to use CaseFlow?",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Role Cards
                      AnimatedBuilder(
                        animation: _cardController,
                        builder: (context, child) {
                          final progress = ((_cardController.value - 0.2) / 0.8).clamp(0.0, 1.0);
                          return Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - progress)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            // Advocate Card
                            _buildRoleCard(
                              role: 'advocate',
                              icon: Icons.gavel_rounded,
                              title: "I'm an Advocate",
                              subtitle: "Full case management, hearings,\nclients, payments & AI tools",
                              gradient: const [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                              accentColor: const Color(0xFF3B82F6),
                              onTap: () => _selectRole('advocate'),
                            ),
                            const SizedBox(height: 16),

                            // Citizen Card
                            _buildRoleCard(
                              role: 'citizen',
                              icon: Icons.person_rounded,
                              title: "I'm a Citizen",
                              subtitle: "Know your rights, track cases,\ncalculators & legal guides",
                              gradient: const [Color(0xFF065F46), Color(0xFF10B981)],
                              accentColor: const Color(0xFF34D399),
                              onTap: () => _selectRole('citizen'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Guest Mode
                      AnimatedBuilder(
                        animation: _cardController,
                        builder: (context, child) {
                          final progress = ((_cardController.value - 0.4) / 0.6).clamp(0.0, 1.0);
                          return Opacity(opacity: progress, child: child);
                        },
                        child: TextButton(
                          onPressed: _enterGuestMode,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                              const SizedBox(width: 10),
                              Text(
                                "Just Explore (Guest Mode)",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Bottom tagline
                      Text(
                        "Every Indian has the right to know the law",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isHovered = _hoveredRole == role;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRole = role),
      onExit: (_) => setState(() => _hoveredRole = null),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovered ? accentColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.1),
              width: isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[1].withValues(alpha: isHovered ? 0.4 : 0.2),
                blurRadius: isHovered ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _selectRole(String role) {
    GuestModeService.isGuestMode = false;
    context.go('/login?role=$role');
  }

  void _enterGuestMode() async {
    GuestModeService.isGuestMode = true;
    await OnboardingService.completeOnboarding();
    if (mounted) {
      context.go('/guest-home');
    }
  }
}
