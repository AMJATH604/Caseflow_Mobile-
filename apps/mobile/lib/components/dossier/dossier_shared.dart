import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─── REUSABLE COLLAPSIBLE SECTION WIDGET ──────────────

class DossierSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;
  final bool initiallyExpanded;
  final String? badgeText;
  final Color? badgeColor;
  final Widget? trailing;

  const DossierSection({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
    this.initiallyExpanded = false,
    this.badgeText,
    this.badgeColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          leading: Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: badgeColor ?? color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}

// ─── HELPER WIDGETS ─────────────────────────────────

class DossierHelper {
  static Widget addButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: const Icon(Icons.add_rounded, size: 18, color: AppTheme.accent),
      ),
    );
  }

  static Widget emptyHint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0.h),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFFCBD5E1),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.sp,
                color: Color(0xFF94A3B8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget dossierRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.sp,
                color: Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  static Widget statMini(String label, int count, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFCBD5E1), size: 16),
          SizedBox(height: 12.h),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -1,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.sp,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
