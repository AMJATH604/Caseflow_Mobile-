import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A premium KPI card with frosted glass effect, colored accent bar,
/// animated counter, and optional pulse indicator.
class KpiCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool showPulse; // Animated pulse dot for urgent items
  final String? subtitle;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor = const Color(0xFF2563EB),
    this.onTap,
    this.showPulse = false,
    this.subtitle,
  });

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> with TickerProviderStateMixin {
  late AnimationController _countController;
  late AnimationController _pulseController;
  late Animation<double> _countAnimation;

  @override
  void initState() {
    super.initState();
    _countController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _countAnimation = CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOutCubic,
    );
    _countController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(KpiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _countController.reset();
      _countController.forward();
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numValue = int.tryParse(widget.value) ?? 0;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2030) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color:
                isDark
                    ? widget.accentColor.withValues(alpha: 0.15)
                    : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Colored accent bar
            Container(
              width: 4.w,
              height: 52.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.accentColor,
                    widget.accentColor.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(width: 16.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 18,
                          color: widget.accentColor,
                        ),
                      ),
                      const Spacer(),
                      if (widget.showPulse && numValue > 0)
                        FadeTransition(
                          opacity: _pulseController,
                          child: Container(
                            width: 8.w,
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: widget.accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accentColor.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (widget.onTap != null)
                        Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color:
                                isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFFCBD5E1),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  // Animated counter
                  AnimatedBuilder(
                    animation: _countAnimation,
                    builder: (context, child) {
                      final displayValue =
                          (_countAnimation.value * numValue).round();
                      return Text(
                        '$displayValue',
                        style: GoogleFonts.outfit(
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    widget.title.toUpperCase(),
                    style: GoogleFonts.inter(
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      widget.subtitle!,
                      style: GoogleFonts.inter(
                        color: widget.accentColor.withValues(alpha: 0.7),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact stat chip for the secondary stats row.
class StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color:
            isDark
                ? color.withValues(alpha: 0.08)
                : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(height: 6.h),
          Text(
            '$value',
            style: GoogleFonts.outfit(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8.sp,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
