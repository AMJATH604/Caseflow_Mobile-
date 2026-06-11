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
  // Phase 1 (Midnight Navy Intro) controllers
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _scaleLineController;

  // Phase 2 (Ambedkar Portrait & Parchment Fade-in) controllers
  late AnimationController _fadeOutController;
  late AnimationController _portraitController;
  late AnimationController _quoteController;

  // Phase 1 animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _scaleLineWidth;
  late Animation<double> _indicatorOpacity;

  // Phase 2 animations
  late Animation<double> _navyOpacity;
  late Animation<double> _portraitOpacity;
  late Animation<double> _portraitScale;
  late Animation<double> _quoteOpacity;
  late Animation<Offset> _quoteSlide;

  @override
  void initState() {
    super.initState();

    // --- PHASE 1 INITIALIZATION ---
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
      CurvedAnimation(
        parent: _scaleLineController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Particle controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // --- PHASE 2 INITIALIZATION ---
    // Fade out of the initial navy elements
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _navyOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeInOut),
    );

    // Fade in and scale of the Ambedkar portrait and parchment layer
    _portraitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _portraitOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _portraitController, curve: Curves.easeIn),
    );
    _portraitScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _portraitController, curve: Curves.easeOutCubic),
    );

    // Fade in and slide of the legal quote
    _quoteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _quoteOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _quoteController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    _quoteSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _quoteController, curve: Curves.easeOutCubic),
    );

    // --- ANIMATION SCHEDULING ---
    // Start Phase 1
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _scaleLineController.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _textController.forward();
    });

    // Start Phase 2 (Transition to Ambedkar portrait)
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _fadeOutController.forward();
        _portraitController.forward();
      }
    });

    // Start Phase 2 Quote Fade-in
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        _quoteController.forward();
      }
    });

    // Safety-stop infinite animations after 5s to save resources
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _bgController.stop();
        _particleController.stop();
      }
    });

    // Navigate to Onboarding / Dashboard after intro has finished showing
    Timer(const Duration(milliseconds: 5600), () async {
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
    _fadeOutController.dispose();
    _portraitController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = (screenWidth / 390).clamp(0.85, 1.15);
    final logoSize = (120 * scaleFactor).clamp(90.0, 140.0);
    final titleFontSize = (38 * scaleFactor).clamp(28.0, 44.0);
    final taglineFontSize = (14 * scaleFactor).clamp(11.0, 16.0);

    return Scaffold(
      body: Stack(
        children: [
          // ─── LAYER 1: MIDNIGHT NAVY TECH SPLASH SCREEN ───
          AnimatedBuilder(
            animation: Listenable.merge([
              _bgController,
              _particleController,
              _navyOpacity,
            ]),
            builder: (context, _) {
              return Opacity(
                opacity: _navyOpacity.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [
                        Color(0xFF0A0E27), // Deep midnight
                        Color(0xFF141B3D), // Dark navy
                        Color(0xFF0D1B3E), // Royal navy
                        Color(0xFF1A1040), // Deep purple navy
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
                          builder:
                              (context, _) => Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFF2563EB).withValues(
                                        alpha: _glowOpacity.value * 0.35,
                                      ),
                                      const Color(0xFF6366F1).withValues(
                                        alpha: _glowOpacity.value * 0.15,
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                        ),
                      ),

                      // Main content
                      SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(flex: 3),

                              // Animated Logo
                              AnimatedBuilder(
                                animation: _logoController,
                                builder:
                                    (context, child) => Opacity(
                                      opacity: _logoOpacity.value,
                                      child: Transform.scale(
                                        scale: _logoScale.value,
                                        child: child,
                                      ),
                                    ),
                                child: Container(
                                  width: logoSize,
                                  height: logoSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF2563EB,
                                        ).withValues(alpha: 0.4),
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
                                builder:
                                    (context, _) => SizedBox(
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
                                builder:
                                    (context, _) => SlideTransition(
                                      position: _titleSlide,
                                      child: Opacity(
                                        opacity: _titleOpacity.value,
                                        child: Text(
                                          AppConstants.appName.toUpperCase(),
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: titleFontSize,
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
                                builder:
                                    (context, _) => Opacity(
                                      opacity: _taglineOpacity.value,
                                      child: Text(
                                        'Empowering Justice, Streamlining Law',
                                        style: GoogleFonts.inter(
                                          fontSize: taglineFontSize,
                                          fontWeight: FontWeight.w400,
                                          color: const Color(0xFFD4AF37),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                              ),

                              const Spacer(flex: 2),

                              // Loading indicator
                              AnimatedBuilder(
                                animation: _textController,
                                builder:
                                    (context, _) => Opacity(
                                      opacity: _indicatorOpacity.value,
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            width: 160,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                backgroundColor: Colors.white
                                                    .withValues(alpha: 0.12),
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFFD4AF37)),
                                                minHeight: 3.0,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            'Preparing your workspace\u2026',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                              letterSpacing: 1.2,
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
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ─── LAYER 2: PARCHMENT & GOLD AMBEDKAR SPLASH SCREEN ───
          AnimatedBuilder(
            animation: Listenable.merge([
              _portraitController,
              _quoteController,
            ]),
            builder: (context, _) {
              if (_portraitOpacity.value == 0.0) return const SizedBox.shrink();
              return Opacity(
                opacity: _portraitOpacity.value,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0A0E27), // Deep midnight navy
                        Color(0xFF141B3D), // Dark navy
                        Color(0xFF1A1040), // Deep purple navy
                        Color(0xFF0D1117), // Near black
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),

                        // Elegant gilded framed circular illustration
                        Transform.scale(
                          scale: _portraitScale.value,
                          child: Container(
                            width: 250 * scaleFactor,
                            height: 250 * scaleFactor,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFD4AF37),
                                width: 4.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 50,
                                  spreadRadius: 8,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF6B531F,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 35,
                                  spreadRadius: 3,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(125),
                              child: Image.asset(
                                'assets/images/ambedkar_splash.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(flex: 1),

                        // Inspiring constitution quote
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: FadeTransition(
                            opacity: _quoteOpacity,
                            child: SlideTransition(
                              position: _quoteSlide,
                              child: Column(
                                children: [
                                  Text(
                                    "“Constitution is not a mere lawyers' document, it is a vehicle of Life, and its spirit is always the spirit of Age.”",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 17 * scaleFactor,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                      color: const Color(0xFFF5F0E8),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '— DR. B.R. AMBEDKAR',
                                    style: GoogleFonts.inter(
                                      fontSize: 12 * scaleFactor,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFD4AF37),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // Premium matching linear loading indicator
                        Opacity(
                          opacity: _quoteOpacity.value,
                          child: Column(
                            children: [
                              SizedBox(
                                width: 160,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFD4AF37),
                                        ),
                                    minHeight: 3.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Entering Dharma & Document\u2026',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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
        top:
            MediaQuery.of(context).size.height *
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
                .withValues(
                  alpha:
                      0.15 +
                      0.15 * sin(_particleController.value * 2 * pi + index),
                ),
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
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.6 * progress)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final midX = size.width / 2;
    final midY = size.height / 2;

    // Left line
    canvas.drawLine(Offset(0, midY), Offset(midX - 20 * progress, midY), paint);

    // Right line
    canvas.drawLine(
      Offset(midX + 20 * progress, midY),
      Offset(size.width, midY),
      paint,
    );

    // Center diamond
    if (progress > 0.5) {
      final diamondPaint =
          Paint()
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
