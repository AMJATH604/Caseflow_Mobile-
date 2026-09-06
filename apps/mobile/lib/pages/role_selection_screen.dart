import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/onboarding_service.dart';
import '../router/app_router.dart';
import '../utils/responsive.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _titleController;
  late AnimationController _card1Controller;
  late AnimationController _card2Controller;
  late AnimationController _guestController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  String? _hoveredRole;

  @override
  void initState() {
    super.initState();

    // Background gradient animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // Logo breathing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Shimmer animation for card borders
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Staggered entry animations
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _card1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _card2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _guestController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Staggered sequence
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _card1Controller.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _card2Controller.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _guestController.forward();
    });

    // Stop infinite animations after 15s
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        _bgController.stop();
        _shimmerController.stop();
        _pulseController.stop();
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _titleController.dispose();
    _card1Controller.dispose();
    _card2Controller.dispose();
    _guestController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = (screenWidth / 390).clamp(0.82, 1.2);
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder:
            (context, _) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: const [
                    Color(0xFF050816),
                    Color(0xFF0A0E27),
                    Color(0xFF0F1A3A),
                    Color(0xFF141042),
                    Color(0xFF0A0816),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [
                    0.0,
                    0.2 + 0.05 * sin(_bgController.value * pi),
                    0.45 + 0.05 * cos(_bgController.value * pi),
                    0.75,
                    1.0,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Floating particles
                  ..._buildParticles(),

                  // Radial glow behind logo area
                  Positioned(
                    top: screenHeight * 0.08,
                    left: 0.w,
                    right: 0.w,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder:
                            (context, _) => Container(
                              width: 200 + 20 * _pulseController.value,
                              height: 200 + 20 * _pulseController.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFFD4AF37).withValues(
                                      alpha:
                                          0.08 + 0.04 * _pulseController.value,
                                    ),
                                    const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.05),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),

                  // Main content
                  SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              screenHeight -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24 * scaleFactor,
                          ),
                          child: Column(
                            children: [
                              SizedBox(height: isSmallScreen ? 30 : 50),

                              // ─── LOGO with golden glow ───
                              _buildAnimatedEntry(
                                controller: _logoController,
                                child: Column(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder:
                                          (context, child) => Container(
                                            width: 80 * scaleFactor,
                                            height: 80 * scaleFactor,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(22.r),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFD4AF37,
                                                  ).withValues(
                                                    alpha:
                                                        0.25 +
                                                        0.1 *
                                                            _pulseController
                                                                .value,
                                                  ),
                                                  blurRadius:
                                                      30 +
                                                      10 *
                                                          _pulseController
                                                              .value,
                                                  spreadRadius:
                                                      2 +
                                                      3 *
                                                          _pulseController
                                                              .value,
                                                ),
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF2563EB,
                                                  ).withValues(alpha: 0.15),
                                                  blurRadius: 40,
                                                  spreadRadius: 5,
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(22.r),
                                              child: Image.asset(
                                                'assets/images/logo.png',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: isSmallScreen ? 20 : 32),

                              // ─── TITLE ───
                              _buildAnimatedEntry(
                                controller: _titleController,
                                child: Column(
                                  children: [
                                    Text(
                                      'Welcome to CaseFlow',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 30.sp * scaleFactor,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: 8.h * scaleFactor),
                                    // Gold accent line
                                    Container(
                                      width: 60.w,
                                      height: 2.5.h,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Color(0xFFD4AF37),
                                            Colors.transparent,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(2.r),
                                      ),
                                    ),
                                    SizedBox(height: 12.h * scaleFactor),
                                    Text(
                                      'How would you like to use CaseFlow?',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp * scaleFactor,
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: isSmallScreen ? 24 : 36),

                              // ─── ADVOCATE CARD (Glassmorphism) ───
                              _buildAnimatedEntry(
                                controller: _card1Controller,
                                offsetY: 40,
                                child: _buildPremiumRoleCard(
                                  role: 'advocate',
                                  icon: Icons.gavel_rounded,
                                  title: "I'm an Advocate",
                                  subtitle: 'Full-power legal practice suite',
                                  gradient: const [
                                    Color(0xFF1E3A6F),
                                    Color(0xFF2563EB),
                                    Color(0xFF4F8AFF),
                                  ],
                                  accentColor: const Color(0xFF60A5FA),
                                  features: const [
                                    'Case & hearing management',
                                    'Client database & payments',
                                    'AI legal assistant',
                                    'E-Filing & court tools',
                                  ],
                                  featureIcon: Icons.check_circle_rounded,
                                  onTap: () => _selectRole('advocate'),
                                  scaleFactor: scaleFactor,
                                ),
                              ),

                              SizedBox(height: 16.h * scaleFactor),

                              // ─── CITIZEN CARD (Glassmorphism) ───
                              _buildAnimatedEntry(
                                controller: _card2Controller,
                                offsetY: 40,
                                child: _buildPremiumRoleCard(
                                  role: 'citizen',
                                  icon: Icons.shield_rounded,
                                  title: "I'm a Citizen",
                                  subtitle:
                                      'Know your rights, protect your future',
                                  gradient: const [
                                    Color(0xFF064E3B),
                                    Color(0xFF059669),
                                    Color(0xFF34D399),
                                  ],
                                  accentColor: const Color(0xFF6EE7B7),
                                  features: const [
                                    'Know your legal rights',
                                    'Track your court cases',
                                    'Legal calculators & tools',
                                    'AI-powered legal help',
                                  ],
                                  featureIcon: Icons.star_rounded,
                                  onTap: () => _selectRole('citizen'),
                                  scaleFactor: scaleFactor,
                                ),
                              ),

                              SizedBox(height: 20.h * scaleFactor),

                              // ─── GUEST MODE ───
                              _buildAnimatedEntry(
                                controller: _guestController,
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: _enterGuestMode,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 24 * scaleFactor,
                                          vertical: 12 * scaleFactor,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                            width: 1.w,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.explore_rounded,
                                              size: 16,
                                              color: Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                            ),
                                            SizedBox(width: 10.w),
                                            Text(
                                              'Just Explore (Guest Mode)',
                                              style: GoogleFonts.inter(
                                                fontSize: 13.sp * scaleFactor,
                                                color: Colors.white.withValues(
                                                  alpha: 0.45,
                                                ),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: isSmallScreen ? 24 : 40),

                                    // Decorative gold divider
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 40.w,
                                          height: 1.h,
                                          color: const Color(
                                            0xFFD4AF37,
                                          ).withValues(alpha: 0.3),
                                        ),
                                        SizedBox(width: 12.w),
                                        Icon(
                                          Icons.balance_rounded,
                                          size: 14,
                                          color: const Color(
                                            0xFFD4AF37,
                                          ).withValues(alpha: 0.5),
                                        ),
                                        SizedBox(width: 12.w),
                                        Container(
                                          width: 40.w,
                                          height: 1.h,
                                          color: const Color(
                                            0xFFD4AF37,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: isSmallScreen ? 12 : 16),

                                    // Bottom tagline
                                    Text(
                                      'Every Indian has the right to know the law',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp * scaleFactor,
                                        color: const Color(
                                          0xFFD4AF37,
                                        ).withValues(alpha: 0.45),
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),

                                    SizedBox(height: isSmallScreen ? 16 : 24),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  // ─── STAGGERED ENTRY ANIMATION HELPER ───
  Widget _buildAnimatedEntry({
    required AnimationController controller,
    required Widget child,
    double offsetY = 25,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, c) {
        final curved = Curves.easeOutCubic.transform(controller.value);
        return Opacity(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - curved)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  // ─── PREMIUM GLASSMORPHISM ROLE CARD ───
  Widget _buildPremiumRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required Color accentColor,
    required List<String> features,
    required IconData featureIcon,
    required VoidCallback onTap,
    required double scaleFactor,
  }) {
    final isHovered = _hoveredRole == role;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRole = role),
      onExit: (_) => setState(() => _hoveredRole = null),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    width: 1.5.w,
                    color: _getShimmerBorderColor(gradient, isHovered),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[1].withValues(
                        alpha: isHovered ? 0.4 : 0.2,
                      ),
                      blurRadius: isHovered ? 30 : 20,
                      offset: const Offset(0, 10),
                      spreadRadius: isHovered ? 2 : 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: EdgeInsets.all(20 * scaleFactor),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            gradient[0].withValues(alpha: 0.85),
                            gradient[1].withValues(alpha: 0.7),
                            gradient[2].withValues(alpha: 0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Icon + Title + Arrow
                          Row(
                            children: [
                              // Icon container with gradient bg
                              Container(
                                padding: EdgeInsets.all(14 * scaleFactor),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.2),
                                      Colors.white.withValues(alpha: 0.08),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 26 * scaleFactor,
                                ),
                              ),
                              SizedBox(width: 16.w * scaleFactor),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.outfit(
                                        fontSize: 20.sp * scaleFactor,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 3.h * scaleFactor),
                                    Text(
                                      subtitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.sp * scaleFactor,
                                        color: Colors.white.withValues(
                                          alpha: 0.65,
                                        ),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(8 * scaleFactor),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 18 * scaleFactor,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 16.h * scaleFactor),

                          // Divider
                          Container(
                            height: 1.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 14.h * scaleFactor),

                          // Feature bullets
                          ...features.map(
                            (feature) => Padding(
                              padding: EdgeInsets.only(bottom: 8.h * scaleFactor),
                              child: Row(
                                children: [
                                  Icon(
                                    featureIcon,
                                    size: 14 * scaleFactor,
                                    color: accentColor.withValues(alpha: 0.9),
                                  ),
                                  SizedBox(width: 10.w * scaleFactor),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.sp * scaleFactor,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        height: 1.3.h,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getShimmerBorderColor(List<Color> gradient, bool isHovered) {
    final t = _shimmerController.value;
    final shimmerAlpha = 0.15 + 0.2 * sin(t * 2 * pi);
    if (isHovered) {
      return gradient[1].withValues(alpha: 0.6);
    }
    return Colors.white.withValues(alpha: shimmerAlpha.clamp(0.08, 0.35));
  }

  // ─── FLOATING PARTICLES ───
  List<Widget> _buildParticles() {
    final random = Random(42);
    return List.generate(15, (index) {
      final x = random.nextDouble();
      final y = random.nextDouble();
      final size = 1.0 + random.nextDouble() * 2.0;

      return Positioned(
        left: MediaQuery.of(context).size.width * x,
        top:
            MediaQuery.of(context).size.height *
            ((y + _bgController.value * 0.15) % 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (index % 3 == 0
                    ? const Color(0xFFD4AF37)
                    : index % 3 == 1
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF6366F1))
                .withValues(
                  alpha: 0.12 + 0.1 * sin(_bgController.value * 2 * pi + index),
                ),
          ),
        ),
      );
    });
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
