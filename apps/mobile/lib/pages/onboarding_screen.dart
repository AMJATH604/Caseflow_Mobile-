import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      title: 'One Dashboard,\nEvery Case',
      subtitle:
          'Track hearings, documents, deadlines, and client communications from a single command center. Never miss a date again.',
      gradientColors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
      accentColor: Color(0xFF42A5F5),
      illustrationColors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
    ),
    _OnboardingSlide(
      icon: Icons.auto_awesome_rounded,
      accentIcon: Icons.psychology_rounded,
      title: 'AI-Powered Legal\nIntelligence',
      subtitle:
          'Get instant case summaries, legal research assistance, and smart reminders powered by advanced AI. Your virtual junior is here.',
      gradientColors: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF8E24AA)],
      accentColor: Color(0xFFCE93D8),
      illustrationColors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
    ),
    _OnboardingSlide(
      icon: Icons.verified_user_rounded,
      accentIcon: Icons.shield_rounded,
      title: 'Bank-Grade\nSecurity',
      subtitle:
          'Your data is encrypted end-to-end, hosted on secure government-compliant servers. Only you can access your practice data.',
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
                                borderRadius: BorderRadius.circular(20.r),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14.sp,
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
                                height: 8.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4.r),
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

                          SizedBox(height: 32.h),

                          // CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 58.h,
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
                                  borderRadius: BorderRadius.circular(18.r),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == _slides.length - 1
                                        ? 'Get Started'
                                        : 'Continue',
                                    style: GoogleFonts.outfit(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
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
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Spacer(flex: 1),

          // Illustration area
          AnimatedBuilder(
            animation: _iconPulseController,
            builder: (context, _) {
              final pulse =
                  1.0 + 0.05 * sin(_iconPulseController.value * 2 * pi);
              return Container(
                width: 200.w,
                height: 200.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      slide.accentColor.withValues(alpha: 0.2),
                      slide.accentColor.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: [0.3, 0.6, 1.0],
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
                          width: 140.w,
                          height: 140.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 2.w,
                            ),
                          ),
                        ),
                        // Inner circle
                        Container(
                          width: 110.w,
                          height: 110.h,
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
                              width: 1.5.w,
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
                            width: 40.w,
                            height: 40.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: slide.accentColor.withValues(alpha: 0.25),
                              border: Border.all(
                                color: slide.accentColor.withValues(alpha: 0.4),
                                width: 1.5.w,
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

          SizedBox(height: 48.h),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 32.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2.h,
              letterSpacing: -0.5,
            ),
          ),

          SizedBox(height: 20.h),

          // Ornamental divider
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30.w,
                height: 1.5.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFD4AF37).withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 6.w,
                height: 6.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 30.w,
                height: 1.5.h,
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

          SizedBox(height: 20.h),

          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.6.h,
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
