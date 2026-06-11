import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/providers.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late PageController _carouselController;
  Timer? _carouselTimer;
  int _currentCarouselPage = 0;
  int _lastSlidesCount = 0;

  List<Color> _parseGradientColors(List<dynamic>? hexList) {
    if (hexList == null || hexList.isEmpty) {
      return [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)];
    }
    try {
      return hexList.map((hex) {
        final cleanHex = hex.toString().replaceAll('#', '').trim();
        if (cleanHex.length == 6) {
          return Color(int.parse('FF$cleanHex', radix: 16));
        } else if (cleanHex.length == 8) {
          return Color(int.parse(cleanHex, radix: 16));
        }
        return const Color(0xFF3B82F6);
      }).toList();
    } catch (e) {
      return [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)];
    }
  }

  IconData _parseIconData(String? iconName) {
    switch (iconName) {
      case 'balance_rounded':
        return Icons.balance_rounded;
      case 'translate_rounded':
        return Icons.translate_rounded;
      case 'account_balance_rounded':
        return Icons.account_balance_rounded;
      case 'tips_and_updates_rounded':
        return Icons.tips_and_updates_rounded;
      case 'spellcheck_rounded':
        return Icons.spellcheck_rounded;
      case 'gavel_rounded':
        return Icons.gavel_rounded;
      case 'info_rounded':
        return Icons.info_rounded;
      case 'record_voice_over_rounded':
        return Icons.record_voice_over_rounded;
      case 'menu_book_rounded':
        return Icons.menu_book_rounded;
      default:
        return Icons.gavel_rounded;
    }
  }

  // ─── CAROUSEL SLIDE DATA ───
  static const List<_CarouselSlide> _carouselSlides = [
    _CarouselSlide(
      type: '\ud83d\udcd6 DID YOU KNOW?',
      title: 'Every Indian has the right to know the law',
      body:
          'Browse your Everyday Legal Encyclopedia — 200+ legal concepts explained in simple terms.',
      gradientColors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      icon: Icons.menu_book_rounded,
      action: 'Explore Guides',
      detailTitle: 'Ignorantia Juris Non Excusat',
      detailBody:
          'Ignorance of the law is not an excuse. Under Indian law, every citizen is presumed to know the legal rules that apply to them.\n\nOur Everyday Legal Encyclopedia breaks down complex laws, civil disputes, criminal procedures, and constitutional provisions into plain, simple language so you are never left in the dark.',
      customRoutePath: '/know-your-rights',
    ),
    _CarouselSlide(
      type: '\u2696\ufe0f LEGAL WORD OF THE DAY',
      title: 'Habeas Corpus',
      body:
          'A court order demanding that a detained person be brought before the court to determine if their detention is lawful.',
      gradientColors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
      icon: Icons.translate_rounded,
      action: 'Learn More',
      detailTitle: 'Habeas Corpus (Writ of Liberty)',
      detailBody:
          "A Latin term meaning 'to have the body'. It is a constitutional writ that protects individual liberty against unlawful or arbitrary detention.\n\nWhen filed, the High Court or Supreme Court orders the detaining authority to bring the detained person to court to examine the validity of their arrest. If the detention lacks legal basis, the person is set free immediately.",
      customRoutePath: '/citizen-tools',
      toolId: 'legal_dictionary',
    ),
    _CarouselSlide(
      type: '\ud83d\udcdc CONSTITUTIONAL FACT',
      title: 'Article 21 — Right to Life',
      body:
          'No person shall be deprived of life or personal liberty except according to procedure established by law.',
      gradientColors: [Color(0xFFB45309), Color(0xFFD97706)],
      icon: Icons.account_balance_rounded,
      action: 'Read Constitution',
      detailTitle: 'Article 21 — Cornerstone of Liberty',
      detailBody:
          "Article 21 guarantees that 'No person shall be deprived of his life or personal liberty except according to procedure established by law.'\n\nThe Supreme Court has interpreted this dynamically to include the right to privacy, clean drinking water, pollution-free air, speedy trial, livelihood, and free legal aid for the underprivileged.",
      customRoutePath: '/citizen-tools',
      toolId: 'bare_acts',
    ),
    _CarouselSlide(
      type: '\ud83d\udca1 LEGAL TIP',
      title: 'Zero FIR — File Anywhere!',
      body:
          'You can file an FIR at ANY police station in India regardless of jurisdiction. Police cannot refuse under Section 154 CrPC.',
      gradientColors: [Color(0xFF065F46), Color(0xFF10B981)],
      icon: Icons.tips_and_updates_rounded,
      action: 'Know Your Rights',
      detailTitle: 'Zero FIR (First Information Report)',
      detailBody:
          "A Zero FIR can be filed at any police station regardless of where the crime took place.\n\nThe station is legally obligated to accept your complaint, mark it as 'Zero FIR' (without a serial number), and subsequently transfer it to the police station with the appropriate jurisdiction. This ensures critical evidence is collected immediately.",
      customRoutePath: '/know-your-rights',
    ),
    _CarouselSlide(
      type: '\u2696\ufe0f LEGAL WORD',
      title: 'Caveat',
      body:
          'A notice filed in court to prevent any order from being passed without hearing the person who filed the caveat (caveator).',
      gradientColors: [Color(0xFF1E40AF), Color(0xFF6366F1)],
      icon: Icons.spellcheck_rounded,
      action: 'Legal Dictionary',
      detailTitle: 'Caveat Petition',
      detailBody:
          'Under Section 148A of the Civil Procedure Code, a Caveat is a precautionary petition filed by a person who fears that an ex-parte case may be filed against them.\n\nOnce logged, the Court cannot pass any interim order or injunction without first notifying the Caveator and giving them an opportunity to present their side of the case.',
      customRoutePath: '/citizen-tools',
      toolId: 'legal_dictionary',
    ),
    _CarouselSlide(
      type: '\ud83c\udfdb\ufe0f LANDMARK CASE',
      title: 'Kesavananda Bharati v. Kerala (1973)',
      body:
          'The Supreme Court established the Basic Structure Doctrine — Parliament cannot alter the fundamental framework of the Constitution.',
      gradientColors: [Color(0xFF991B1B), Color(0xFFDC2626)],
      icon: Icons.gavel_rounded,
      action: 'Explore Cases',
      detailTitle: 'The Basic Structure Doctrine',
      detailBody:
          "The most critical judgment in Indian legal history. By a 7:6 majority, a 13-judge Supreme Court bench ruled that while Parliament has the power to amend the Constitution, it cannot alter or destroy its 'Basic Structure' — including democracy, secularism, rule of law, and judicial independence.",
      customRoutePath: '/know-your-rights',
    ),
    _CarouselSlide(
      type: '\ud83d\udca1 KNOW YOUR RIGHT',
      title: 'RTI — Right to Information',
      body:
          'Under the RTI Act 2005, every citizen can request information from any public authority. They must respond within 30 days.',
      gradientColors: [Color(0xFF0E7490), Color(0xFF06B6D4)],
      icon: Icons.info_rounded,
      action: 'Learn RTI',
      detailTitle: 'Right to Information Act, 2005',
      detailBody:
          "The RTI Act empowers citizens to request records, documents, and info from government authorities to ensure transparency.\n\nPublic Information Officers must respond within 30 days. If the query concerns a citizen's life or personal liberty, the response must be provided within 48 hours.",
      customRoutePath: '/know-your-rights',
    ),
    _CarouselSlide(
      type: '\u2696\ufe0f LEGAL WORD',
      title: 'Suo Motu',
      body:
          'When a court takes cognizance and action on its own motion, without any petition or complaint from a party.',
      gradientColors: [Color(0xFF6B21A8), Color(0xFF9333EA)],
      icon: Icons.record_voice_over_rounded,
      action: 'Legal Dictionary',
      detailTitle: 'Suo Motu Cognizance',
      detailBody:
          "Meaning 'on its own motion'. This is when a court initiates legal proceedings on its own, without any party filing a petition.\n\nCourts take Suo Motu action based on media reports, letters, or public disasters, demonstrating the proactive role of the judiciary in upholding justice and protecting public interest.",
      customRoutePath: '/citizen-tools',
      toolId: 'legal_dictionary',
    ),
  ];

  final List<_FeatureItem> _features = [
    const _FeatureItem(
      'Know Your Rights',
      'Everyday legal guides',
      Icons.menu_book_rounded,
      [Color(0xFFD4AF37), Color(0xFFB8860B)],
      '/know-your-rights',
    ),
    const _FeatureItem(
      'Bare Acts',
      'BNS, BNSS, CPC, Constitution',
      Icons.library_books_rounded,
      [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      '/citizen-tools',
      toolId: 'bare_acts',
    ),
    const _FeatureItem(
      'Court Fee',
      'Calculate court fees',
      Icons.calculate_rounded,
      [Color(0xFFF59E0B), Color(0xFFEF6C00)],
      '/citizen-tools',
      toolId: 'court-fee',
    ),
    const _FeatureItem(
      'Legal Dictionary',
      '500+ legal terms',
      Icons.import_contacts_rounded,
      [Color(0xFFEF4444), Color(0xFFDC2626)],
      '/citizen-tools',
      toolId: 'legal_dictionary',
    ),
    const _FeatureItem(
      'Track My Case',
      'CNR case lookup',
      Icons.search_rounded,
      [Color(0xFF10B981), Color(0xFF059669)],
      '/track-case',
    ),
    const _FeatureItem(
      'AI Legal Help',
      'Ask legal questions',
      Icons.auto_awesome_rounded,
      [Color(0xFF6366F1), Color(0xFF4F46E5)],
      '/ai-chat',
    ),
    const _FeatureItem(
      'Find Advocate',
      'Search lawyers near you',
      Icons.person_search_rounded,
      [Color(0xFF3B82F6), Color(0xFF2563EB)],
      '/advocate-directory',
    ),
    const _FeatureItem(
      'Legal News',
      'Latest legal updates',
      Icons.newspaper_rounded,
      [Color(0xFFDC2626), Color(0xFFB91C1C)],
      '/legal-pulse',
    ),
    const _FeatureItem(
      'Court Holidays',
      '2026 holiday calendar',
      Icons.calendar_month_rounded,
      [Color(0xFFFF6B35), Color(0xFFE65100)],
      '/citizen-tools',
      toolId: 'holiday_list',
    ),
    const _FeatureItem(
      'Stamp Duty',
      'Calculate stamp values',
      Icons.receipt_long_rounded,
      [Color(0xFFFFB300), Color(0xFFF57F17)],
      '/citizen-tools',
      toolId: 'stamp_values',
    ),
    const _FeatureItem(
      'Interest',
      'Calculate interest',
      Icons.percent_rounded,
      [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
      '/citizen-tools',
      toolId: 'interest',
    ),
    const _FeatureItem(
      'Partition Share',
      'Hindu & Muslim law',
      Icons.family_restroom_rounded,
      [Color(0xFFEC407A), Color(0xFFC62828)],
      '/citizen-tools',
      toolId: 'partition_calculator',
    ),
    const _FeatureItem(
      'MACT Claims',
      'Accident compensation',
      Icons.directions_car_rounded,
      [Color(0xFFE53935), Color(0xFFB71C1C)],
      '/citizen-tools',
      toolId: 'mact_calculator',
    ),
    const _FeatureItem(
      'Maintenance',
      'Sec 144 BNSS / HAMA',
      Icons.account_balance_wallet_rounded,
      [Color(0xFF7C4DFF), Color(0xFF651FFF)],
      '/citizen-tools',
      toolId: 'maintenance_calculator',
    ),
    const _FeatureItem(
      'Legal Templates',
      'PDF & Word drafts',
      Icons.description_rounded,
      [Color(0xFFD4AF37), Color(0xFFB8860B)],
      '/citizen-tools',
      toolId: 'legal_templates',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _carouselController = PageController();
  }

  void _startCarouselAutoScroll(int slidesCount) {
    _carouselTimer?.cancel();
    if (slidesCount == 0) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted) return;
      _currentCarouselPage = (_currentCarouselPage + 1) % slidesCount;
      _carouselController.animateToPage(
        _currentCarouselPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _resetCarouselTimer() {
    _carouselTimer?.cancel();
    // Resume auto-scroll after 8 seconds of inactivity
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) _startCarouselAutoScroll(_lastSlidesCount);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    final slidesAsync = ref.watch(carouselSlidesProvider);
    final List<_CarouselSlide> activeSlides = slidesAsync.maybeWhen(
      data: (data) {
        if (data.isEmpty) return _carouselSlides;
        return data.map((json) {
          return _CarouselSlide(
            type: json['type'] ?? '',
            title: json['title'] ?? '',
            body: json['body'] ?? '',
            gradientColors: _parseGradientColors(json['gradient_colors']),
            icon: _parseIconData(json['icon_name']),
            action: json['action'] ?? 'Learn More',
            detailTitle: json['detail_title'] ?? '',
            detailBody: json['detail_body'] ?? '',
            customRoutePath: json['custom_route_path'],
            toolId: json['tool_id'],
          );
        }).toList();
      },
      orElse: () => _carouselSlides,
    );

    final activeSlidesCount = activeSlides.length;
    if (_carouselTimer == null || _lastSlidesCount != activeSlidesCount) {
      _lastSlidesCount = activeSlidesCount;
      _startCarouselAutoScroll(activeSlidesCount);
    }

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

              // Carousel
              _buildCarousel(activeSlides),
              const SizedBox(height: 24),

              // Quick Actions
              _buildSectionTitle('Quick Actions'),
              const SizedBox(height: 12),
              _buildQuickActions(),
              const SizedBox(height: 24),

              // All Tools Grid
              _buildSectionTitle('Legal Resources'),
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
          'Legal Knowledge Hub',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Know Your Rights. Protect Your Future.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCarousel(List<_CarouselSlide> activeSlides) {
    final screenWidth = MediaQuery.of(context).size.width;
    final carouselHeight = (screenWidth * 0.52).clamp(180.0, 240.0);

    return Column(
      children: [
        SizedBox(
          height: carouselHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _resetCarouselTimer();
              }
              return false;
            },
            child: PageView.builder(
              controller: _carouselController,
              itemCount: activeSlides.length,
              onPageChanged: (index) {
                setState(() => _currentCarouselPage = index);
              },
              itemBuilder: (context, index) {
                final slide = activeSlides[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => _showSlideDetailBottomSheet(context, slide),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: slide.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: slide.gradientColors[0].withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Slide type label
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    slide.type,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withValues(
                                        alpha: 0.95,
                                      ),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Title
                                Text(
                                  slide.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Body
                                Expanded(
                                  child: Text(
                                    slide.body,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Action button
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${slide.action} \u2192',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
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
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Icon(
                              slide.icon,
                              size: 32,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(activeSlides.length, (index) {
            final isActive = index == _currentCarouselPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color:
                    isActive
                        ? const Color(0xFF2563EB)
                        : Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFFCBD5E1),
              ),
            );
          }),
        ),
      ],
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
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF0F172A),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final isGuest = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/guest');
    final trackRoute = isGuest ? '/guest-track-case' : '/track-case';
    final toolsRoute = isGuest ? '/guest-tools' : '/citizen-tools';
    final rightsRoute =
        isGuest ? '/guest-know-your-rights' : '/know-your-rights';

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildQuickActionCard(
            'Know Your\nRights',
            Icons.menu_book_rounded,
            const [Color(0xFFD4AF37), Color(0xFFB8860B)],
            () => context.push(rightsRoute),
          ),
          _buildQuickActionCard('Track\nMy Case', Icons.search_rounded, const [
            Color(0xFF10B981),
            Color(0xFF059669),
          ], () => context.push(trackRoute)),
          _buildQuickActionCard(
            'AI Legal\nHelp',
            Icons.auto_awesome_rounded,
            const [Color(0xFF6366F1), Color(0xFF4F46E5)],
            () {
              if (isGuest) {
                _showAuthRequiredDialog(context, 'AI Legal Help');
              } else {
                context.push('/ai-chat');
              }
            },
          ),
          _buildQuickActionCard(
            'Find an\nAdvocate',
            Icons.person_search_rounded,
            const [Color(0xFF3B82F6), Color(0xFF2563EB)],
            () {
              if (isGuest) {
                _showAuthRequiredDialog(context, 'Find Advocate');
              } else {
                context.push('/advocate-directory');
              }
            },
          ),
          _buildQuickActionCard(
            'Court\nFee',
            Icons.calculate_rounded,
            const [Color(0xFFF59E0B), Color(0xFFEF6C00)],
            () => context.push('$toolsRoute?tool=court-fee'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String label,
    IconData icon,
    List<Color> gradient,
    VoidCallback onTap,
  ) {
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
        childAspectRatio:
            isMobile
                ? (MediaQuery.of(context).size.width > 360 ? 1.05 : 0.95)
                : 1.05,
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
        final progress = ((_animController.value - delay) / (1.0 - delay))
            .clamp(0.0, 1.0);
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
          final isGuest = GoRouterState.of(
            context,
          ).matchedLocation.startsWith('/guest');

          String targetRoute = feature.route;
          if (isGuest) {
            if (targetRoute == '/citizen-tools') {
              targetRoute = '/guest-tools';
            } else if (targetRoute == '/track-case') {
              targetRoute = '/guest-track-case';
            } else if (targetRoute == '/know-your-rights') {
              targetRoute = '/guest-know-your-rights';
            }
          }

          final requiresAuth =
              feature.route == '/ai-chat' ||
              feature.route == '/advocate-directory' ||
              feature.route == '/legal-pulse';

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
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).brightness == Brightness.dark
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
                  color:
                      Theme.of(context).brightness == Brightness.dark
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
                  color:
                      Theme.of(context).brightness == Brightness.dark
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
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
            title: Text(
              'Sign In Required',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF0F172A),
              ),
            ),
            content: Text(
              'You need to sign in or create an account to use $featureName.\n\nIt takes less than a minute and unlocks personalized legal tools, saved cases, and AI legal help.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF4B5563),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Sign In / Sign Up',
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

  void _showSlideDetailBottomSheet(BuildContext context, _CarouselSlide slide) {
    final isGuest = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/guest');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle & Top Gradient Area
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: slide.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Header Row with Icon & Label
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  slide.type,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slide.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Detail Content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.detailTitle,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Elegant divider line
                    Container(
                      width: 60,
                      height: 3,
                      decoration: BoxDecoration(
                        color: slide.gradientColors[0],
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Detail Text
                    Text(
                      slide.detailBody,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color:
                            isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Action Button
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        final baseRoute =
                            slide.customRoutePath ?? '/know-your-rights';
                        String targetRoute = baseRoute;
                        if (isGuest) {
                          if (baseRoute == '/citizen-tools') {
                            targetRoute = '/guest-tools';
                          } else if (baseRoute == '/know-your-rights') {
                            targetRoute = '/guest-know-your-rights';
                          }
                        }

                        if (slide.toolId != null) {
                          context.push('$targetRoute?tool=${slide.toolId}');
                        } else {
                          context.push(targetRoute);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: slide.gradientColors,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: slide.gradientColors[0].withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              slide.action,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
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
        );
      },
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

  const _FeatureItem(
    this.title,
    this.subtitle,
    this.icon,
    this.gradient,
    this.route, {
    this.toolId,
  });
}

class _CarouselSlide {
  final String type;
  final String title;
  final String body;
  final List<Color> gradientColors;
  final IconData icon;
  final String action;
  final String detailTitle;
  final String detailBody;
  final String? customRoutePath;
  final String? toolId;

  const _CarouselSlide({
    required this.type,
    required this.title,
    required this.body,
    required this.gradientColors,
    required this.icon,
    required this.action,
    required this.detailTitle,
    required this.detailBody,
    this.customRoutePath,
    this.toolId,
  });
}
