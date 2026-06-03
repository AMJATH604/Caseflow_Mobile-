import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status.toLowerCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 10, color: config.color),
          const SizedBox(width: 6),
          Text(
            status.isEmpty ? "UNKNOWN" : status.toUpperCase(),
            style: GoogleFonts.inter(
              color: config.color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getConfig(String s) {
    switch (s) {
      case 'active':
      case 'approved':
      case 'paid':
        return _StatusConfig(AppTheme.success, Icons.check_circle_rounded);
      case 'pending':
      case 'submitted':
      case 'drafting':
      case 'scheduled':
        return _StatusConfig(AppTheme.warning, Icons.schedule_rounded);
      case 'closed':
      case 'rejected':
      case 'unpaid':
      case 'disposed':
        return _StatusConfig(AppTheme.error, Icons.cancel_rounded);
      case 'filing':
        return _StatusConfig(AppTheme.accent, Icons.upload_file_rounded);
      case 'hearing':
      case 'arguments':
        return _StatusConfig(AppTheme.accentViolet, Icons.gavel_rounded);
      default:
        return _StatusConfig(
          const Color(0xFF6B7280),
          Icons.info_outline_rounded,
        );
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  const _StatusConfig(this.color, this.icon);
}
