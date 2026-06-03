import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _bgAnimController;
  late AnimationController _iconPulseController;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.dashboard_customize_rounded,
      accentIcon: Icons.gavel_rounded,
      title: "One Dashboard,\nEvery Case",
      subtitle:
          "Track hearings, documents, deadlines, and client communications from a single command center. Never miss a date again.",
      gradientColors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
      accentColor: Color(0xFF42A5F5),
      illustrationColors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
    ),
    _OnboardingSlide(
      icon: Icons.auto_awesome_rounded,
      accentIcon: Icons.psychology_rounded,
      title: "AI-Powered Legal\nIntelligence",
      subtitle:
          "Get instant case summaries, legal research assistance, and smart reminders powered by advanced AI. Your virtual junior is here.",
      gradientColors: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF8E24AA)],
      accentColor: Color(0xFFCE93D8),
      illustrationColors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
    ),
    _OnboardingSlide(
      icon: Icons.verified_user_rounded,
      accentIcon: Icons.shield_rounded,
      title: "Bank-Grade\nSecurity",
      subtitle:
          "Your data is encrypted end-to-end, hosted on secure government-compliant servers. Only you can access your practice data.",
      gradientColors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
      accentColor: Color(0xFF81C784),
      illustrationColors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // FIX: Stop infinite animations after 12s to prevent memory pressure
    // crash on low-end devices (same pattern as login_screen fix).
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted) {
        _bgAnimController.stop();
        _iconPulseController.stop();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgAnimController.dispose();
    _iconPulseController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    context.go('/role-selection');
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnimController,
        builder:
            (context, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    slide.gradientColors[0],
                    slide.gradientColors[1],
                    slide.gradientColors[2].withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [
                    0.0,
                    0.4 + 0.1 * sin(_bgAnimController.value * pi),
                    1.0,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Skip button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _completeOnboarding,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            child: Text(
                              "Skip",
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Page view
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _slides.length,
                        itemBuilder: (context, index) {
                          return _buildSlide(_slides[index], screenHeight);
                        },
                      ),
                    ),

                    // Bottom section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      child: Column(
                        children: [
                          // Dots indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _slides.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: _currentPage == i ? 28 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color:
                                      _currentPage == i
                                          ? Colors.white
                                          : Colors.white.withValues(
                                            alpha: 0.25,
                                          ),
                                  boxShadow:
                                      _currentPage == i
                                          ? [
                                            BoxShadow(
                                              color: Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ]
                                          : null,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: slide.gradientColors[0],
                                elevation: 8,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.25,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == _slides.length - 1
                                        ? "Get Started"
                                        : "Continue",
                                    style: GoogleFonts.outfit(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    _currentPage == _slides.length - 1
                                        ? Icons.arrow_forward_rounded
                                        : Icons.east_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide, double screenHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          // Illustration area
          AnimatedBuilder(
            animation: _iconPulseController,
            builder: (context, _) {
              final pulse =
                  1.0 + 0.05 * sin(_iconPulseController.value * 2 * pi);
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      slide.accentColor.withValues(alpha: 0.2),
                      slide.accentColor.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
                child: Center(
                  child: Transform.scale(
                    scale: pulse,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background ring
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 2,
                            ),
                          ),
                        ),
                        // Inner circle
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 52,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        // Orbiting accent icon
                        Transform.translate(
                          offset: Offset(
                            55 * cos(_iconPulseController.value * 2 * pi),
                            55 * sin(_iconPulseController.value * 2 * pi),
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: slide.accentColor.withValues(alpha: 0.25),
                              border: Border.all(
                                color: slide.accentColor.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              slide.accentIcon,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 20),

          // Ornamental divider
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFD4AF37).withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4AF37).withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final IconData accentIcon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color accentColor;
  final List<Color> illustrationColors;

  const _OnboardingSlide({
    required this.icon,
    required this.accentIcon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColor,
    required this.illustrationColors,
  });
}
