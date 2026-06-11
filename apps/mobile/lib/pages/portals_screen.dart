import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../components/epay_court_fee_sheet.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

class PortalsScreen extends StatefulWidget {
  const PortalsScreen({super.key});

  @override
  State<PortalsScreen> createState() => _PortalsScreenState();
}

class _PortalsScreenState extends State<PortalsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _locations = {};
  String? _selectedState;
  String? _selectedDistrict;
  String _selectedType = 'certified_copy';
  bool _isLoading = true;
  bool _isRedirecting = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadLocations();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/json/india_locations.json',
      );
      final data = await json.decode(response);
      if (mounted) {
        setState(() {
          _locations = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRedirect() async {
    if (_selectedType == 'court_fee_payment') {
      EPayCourtFeeSheet.show(context);
      return;
    }

    if (_selectedState == null || _selectedDistrict == null) return;

    setState(() => _isRedirecting = true);

    try {
      final url = await SupabaseService.getDistrictPortalUrl(
        _selectedState!,
        _selectedDistrict!,
        _selectedType,
      );

      // Track portal access
      AnalyticsService.logPortalAccessed(
        _selectedState!,
        _selectedDistrict!,
        _selectedType,
      );

      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showError('Could not launch $url');
        }
      } else {
        final typeLabel =
            _selectedType == 'certified_copy'
                ? 'Certified copy'
                : 'Video conferencing';
        _showError('$typeLabel portal not available for this district yet.');
      }
    } catch (e) {
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isRedirecting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
              : CustomScrollView(
                slivers: [
                  // Premium Header
                  SliverToBoxAdapter(child: _buildHeader()),
                  // Quick Access Bar
                  SliverToBoxAdapter(child: _buildQuickAccessBar()),
                  // Service Cards
                  SliverToBoxAdapter(child: _buildServiceGrid()),
                  // Location Selector
                  SliverToBoxAdapter(child: _buildLocationSection()),
                  // Action Button
                  SliverToBoxAdapter(child: _buildActionSection()),
                  // Footer Disclaimer
                  SliverToBoxAdapter(child: _buildFooter()),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
    );
  }

  // ─── Premium Header ────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E7490).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'OFFICIAL PORTALS',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Court Portals',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Access official district court services, certified copies,\nvideo conferencing & court fee payments',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Access Stat Bar ─────────────────────────────
  Widget _buildQuickAccessBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          _buildStatChip(
            Icons.verified_rounded,
            '36 States',
            const Color(0xFF6366F1),
          ),
          const SizedBox(width: 10),
          _buildStatChip(
            Icons.domain_rounded,
            '600+ Districts',
            const Color(0xFF0EA5E9),
          ),
          const SizedBox(width: 10),
          _buildStatChip(
            Icons.security_rounded,
            'Secure Access',
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Service Selection Grid ────────────────────────────
  Widget _buildServiceGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SELECT SERVICE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPremiumServiceCard(
                  'certified_copy',
                  Icons.file_copy_rounded,
                  'Certified\nCopies',
                  'CC Status & Track',
                  const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPremiumServiceCard(
                  'video_conference',
                  Icons.videocam_rounded,
                  'Video\nConference',
                  'VC Links & Info',
                  const Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPremiumServiceCard(
                  'holiday_list',
                  Icons.event_note_rounded,
                  'Holiday\nCalendar',
                  'Court Holidays',
                  const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPremiumServiceCard(
                  'court_fee_payment',
                  Icons.account_balance_wallet_rounded,
                  'Court Fee\nPayment',
                  'eCourts ePay',
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumServiceCard(
    String type,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? color.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? color.withValues(alpha: 0.15)
                            : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? color : color.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color:
                    isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF334155),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color:
                    isSelected
                        ? color.withValues(alpha: 0.8)
                        : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Location Selector ─────────────────────────────────
  Widget _buildLocationSection() {
    final isEPay = _selectedType == 'court_fee_payment';
    if (isEPay) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SELECT JURISDICTION',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // State Dropdown
                _buildPremiumDropdown(
                  label: 'State / UT',
                  hint: 'Select state or union territory',
                  icon: Icons.location_on_rounded,
                  value: _selectedState,
                  items: _locations.keys.toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedState = val;
                      _selectedDistrict = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // District Dropdown
                _buildPremiumDropdown(
                  label: 'District Court',
                  hint: 'Select district',
                  icon: Icons.gavel_rounded,
                  value: _selectedDistrict,
                  items:
                      _selectedState == null
                          ? []
                          : (_locations[_selectedState!] as List)
                              .map((d) => d.toString())
                              .toList(),
                  onChanged: (val) => setState(() => _selectedDistrict = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFFCBD5E1),
            ),
            prefixIcon: Icon(icon, size: 18, color: AppTheme.accent),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF94A3B8),
          ),
          items:
              items
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ─── Action Button ─────────────────────────────────────
  Widget _buildActionSection() {
    final isEPay = _selectedType == 'court_fee_payment';
    final canProceed =
        isEPay ||
        (_selectedState != null &&
            _selectedDistrict != null &&
            !_isRedirecting);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canProceed ? AppTheme.accent : const Color(0xFFE2E8F0),
                foregroundColor:
                    canProceed ? Colors.white : const Color(0xFF94A3B8),
                elevation: canProceed ? 4 : 0,
                shadowColor:
                    canProceed
                        ? AppTheme.accent.withValues(alpha: 0.4)
                        : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: canProceed ? _handleRedirect : null,
              child:
                  _isRedirecting
                      ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isEPay
                                ? Icons.payment_rounded
                                : Icons.open_in_new_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEPay
                                ? 'Open Court Fee Payment'
                                : 'Access Official Portal',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer ────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shield_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You will be securely redirected to the official eCourts portal maintained by the Government of India.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
