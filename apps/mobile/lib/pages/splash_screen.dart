import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_constants.dart';
import '../services/onboarding_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _scaleLineController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _scaleLineWidth;
  late Animation<double> _indicatorOpacity;

  @override
  void initState() {
    super.initState();

    // Background gradient animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // Logo entrance
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Text entrance
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );
    _indicatorOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // Scale line animation
    _scaleLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleLineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleLineController, curve: Curves.easeInOutCubic),
    );

    // Particle controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Staggered animation sequence
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _scaleLineController.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _textController.forward();
    });

    // FIX: Safety-stop infinite animations after 5s in case navigation is delayed
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _bgController.stop();
        _particleController.stop();
      }
    });

    // Navigate after the show — check onboarding status
    Timer(const Duration(milliseconds: 3200), () async {
      if (!mounted) return;
      final onboardingDone = await OnboardingService.isOnboardingComplete();
      if (!mounted) return;
      if (onboardingDone) {
        context.go('/');
      } else {
        await OnboardingService.completeOnboarding();
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _scaleLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgController, _particleController]),
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF0A0E27),  // Deep midnight
                  Color(0xFF141B3D),  // Dark navy
                  Color(0xFF0D1B3E),  // Royal navy
                  Color(0xFF1A1040),  // Deep purple navy
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
            child: Stack(
              children: [
                // Floating particles
                ..._buildParticles(),

                // Radial glow behind logo
                Center(
                  child: AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, _) => Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF2563EB).withValues(alpha: _glowOpacity.value * 0.35),
                            const Color(0xFF6366F1).withValues(alpha: _glowOpacity.value * 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      // Animated Logo
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) => Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        ),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Animated scale of justice line
                      AnimatedBuilder(
                        animation: _scaleLineController,
                        builder: (context, _) => SizedBox(
                          width: 200 * _scaleLineWidth.value,
                          child: CustomPaint(
                            size: const Size(200, 30),
                            painter: _ScalesLinePainter(
                              progress: _scaleLineWidth.value,
                              color: const Color(0xFFD4AF37),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // App Name
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, _) => SlideTransition(
                          position: _titleSlide,
                          child: Opacity(
                            opacity: _titleOpacity.value,
                            child: Text(
                              AppConstants.appName.toUpperCase(),
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tagline
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, _) => Opacity(
                          opacity: _taglineOpacity.value,
                          child: Text(
                            "Your Practice, Perfected",
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Loading indicator
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, _) => Opacity(
                          opacity: _indicatorOpacity.value,
                          child: Column(
                            children: [
                              SizedBox(
                                width: 140,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFD4AF37),
                                    ),
                                    minHeight: 2.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Preparing your workspace…",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildParticles() {
    final random = Random(42); // Fixed seed for consistent placement
    return List.generate(20, (index) {
      final x = random.nextDouble();
      final y = random.nextDouble();
      final size = 1.5 + random.nextDouble() * 2.5;
      final speed = 0.5 + random.nextDouble() * 1.5;

      return Positioned(
        left: MediaQuery.of(context).size.width * x,
        top: MediaQuery.of(context).size.height *
            ((y + _particleController.value * speed * 0.3) % 1.0),
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
                .withValues(alpha: 0.15 + 0.15 * sin(_particleController.value * 2 * pi + index)),
          ),
        ),
      );
    });
  }
}

/// Draws a minimalist scales of justice ornamental line
class _ScalesLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScalesLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6 * progress)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final midX = size.width / 2;
    final midY = size.height / 2;

    // Left line
    canvas.drawLine(
      Offset(0, midY),
      Offset(midX - 20 * progress, midY),
      paint,
    );

    // Right line
    canvas.drawLine(
      Offset(midX + 20 * progress, midY),
      Offset(size.width, midY),
      paint,
    );

    // Center diamond
    if (progress > 0.5) {
      final diamondPaint = Paint()
        ..color = color.withValues(alpha: (progress - 0.5) * 2 * 0.8)
        ..style = PaintingStyle.fill;

      final path = Path();
      const ds = 5.0;
      path.moveTo(midX, midY - ds);
      path.lineTo(midX + ds, midY);
      path.lineTo(midX, midY + ds);
      path.lineTo(midX - ds, midY);
      path.close();
      canvas.drawPath(path, diamondPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScalesLinePainter old) =>
      old.progress != progress;
}
