import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/commission_models.dart';
import '../../theme/app_theme.dart';

/// The Advocate Commissioner module's own small design kit, so every screen
/// of the module shares one look: light cards on a cool ground, violet for
/// progress, the app's blue for actions.
class Cm {
  static const violet = Color(0xFF6366F1);
  static const violetDeep = Color(0xFF4F46E5);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const line = Color(0xFFE2E8F0);
  static const ground = Color(0xFFF8FAFC);

  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color bg(BuildContext c) => dark(c) ? const Color(0xFF0B0F1A) : ground;
  static Color card(BuildContext c) => dark(c) ? const Color(0xFF111827) : Colors.white;
  static Color border(BuildContext c) => dark(c) ? const Color(0xFF1F2937) : line;
  static Color text(BuildContext c) => dark(c) ? Colors.white : ink;
  static Color sub(BuildContext c) => dark(c) ? const Color(0xFF94A3B8) : muted;

  static TextStyle title(BuildContext c, {double size = 15}) => GoogleFonts.inter(
        fontSize: size.sp,
        fontWeight: FontWeight.w600,
        color: text(c),
      );
  static TextStyle body(BuildContext c, {double size = 13, Color? color}) => GoogleFonts.inter(
        fontSize: size.sp,
        height: 1.45,
        color: color ?? sub(c),
      );
  static TextStyle display(BuildContext c, {double size = 21, Color? color}) => GoogleFonts.outfit(
        fontSize: size.sp,
        fontWeight: FontWeight.w700,
        color: color ?? text(c),
      );
}

IconData cmTypeIcon(CommissionType t) => switch (t) {
      CommissionType.localInvestigation => Icons.travel_explore_rounded,
      CommissionType.partition => Icons.grid_view_rounded,
      CommissionType.survey => Icons.straighten_rounded,
      CommissionType.recordingEvidence => Icons.record_voice_over_rounded,
      CommissionType.sale => Icons.gavel_rounded,
      CommissionType.accounts => Icons.account_balance_rounded,
      CommissionType.scientificInvestigation => Icons.science_rounded,
      CommissionType.ministerialAct => Icons.assignment_turned_in_rounded,
    };

/// A screen of the module: back arrow, a title and optional actions.
class CmScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;
  final Widget? bottom;

  const CmScaffold({super.key, required this.title, required this.body, this.actions = const [], this.bottom});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cm.bg(context),
      appBar: AppBar(
        backgroundColor: Cm.bg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(title, style: Cm.display(context, size: 20), overflow: TextOverflow.ellipsis),
        actions: actions,
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h), child: bottom),
            ),
    );
  }
}

class CmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const CmCard({super.key, required this.child, this.padding, this.color, this.borderColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: color ?? Cm.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor ?? Cm.border(context)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(16.r), onTap: onTap, child: box),
    );
  }
}

/// "NEXT STEP"-style small caps label.
class CmLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const CmLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: color ?? Cm.sub(context),
        ),
      );
}

enum CmTone { blue, green, amber, red, gray, violet }

class CmPill extends StatelessWidget {
  final String text;
  final CmTone tone;
  const CmPill(this.text, {super.key, this.tone = CmTone.gray});

  @override
  Widget build(BuildContext context) {
    final dk = Cm.dark(context);
    final (bg, fg) = switch (tone) {
      CmTone.blue => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      CmTone.green => (const Color(0xFFD1FAE5), const Color(0xFF047857)),
      CmTone.amber => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      CmTone.red => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      CmTone.violet => (const Color(0xFFEDE9FE), const Color(0xFF5B21B6)),
      CmTone.gray => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: dk ? fg.withValues(alpha: 0.22) : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: dk ? Colors.white : fg,
        ),
      ),
    );
  }
}

/// Six segments: done, current, to come.
class CmStageBar extends StatelessWidget {
  final int done; // stages completed
  final bool onDark;
  const CmStageBar({super.key, required this.done, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < CommissionStage.values.length; i++) ...[
          if (i > 0) SizedBox(width: 4.w),
          Expanded(
            child: Container(
              height: 6.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: onDark
                    ? Colors.white.withValues(alpha: i < done ? 1 : (i == done ? 0.55 : 0.25))
                    : (i < done
                        ? Cm.violet
                        : (i == done ? const Color(0xFFA5B4FC) : (Cm.dark(context) ? const Color(0xFF1F2937) : Cm.line))),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A tappable row: tinted icon, title, one line of status, chevron.
class CmNavRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const CmNavRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 2.w),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: color.withValues(alpha: Cm.dark(context) ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(icon, color: color, size: 20.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Cm.title(context, size: 14)),
                  SizedBox(height: 2.h),
                  Text(subtitle, style: Cm.body(context, size: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: Cm.faint, size: 22.r),
          ],
        ),
      ),
    );
  }
}

class CmButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool outlined;
  final bool busy;

  const CmButton(this.label, {super.key, this.icon, this.onPressed, this.color, this.outlined = false, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(width: 20.r, height: 20.r, child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? Cm.text(context) : Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 19.r), SizedBox(width: 8.w)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w600))),
            ],
          );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r));
    if (outlined) {
      return SizedBox(
        height: 48.h,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: Cm.text(context),
            side: BorderSide(color: Cm.dark(context) ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            shape: shape,
          ),
          child: child,
        ),
      );
    }
    return SizedBox(
      height: 50.h,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppTheme.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: (color ?? AppTheme.accent).withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: shape,
        ),
        child: child,
      ),
    );
  }
}

/// Label + value pairs, aligned.
class CmFacts extends StatelessWidget {
  final List<(String, String)> rows;
  const CmFacts(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 3.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 112.w, child: Text(k, style: Cm.body(context, size: 13))),
                Expanded(child: Text(v, style: Cm.title(context, size: 13).copyWith(fontWeight: FontWeight.w500))),
              ],
            ),
          ),
      ],
    );
  }
}

class CmEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const CmEmpty({super.key, required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(color: Cm.violet.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 30.r, color: Cm.violet),
            ),
            SizedBox(height: 14.h),
            Text(title, textAlign: TextAlign.center, style: Cm.display(context, size: 18)),
            SizedBox(height: 6.h),
            Text(body, textAlign: TextAlign.center, style: Cm.body(context)),
            if (action != null) ...[SizedBox(height: 18.h), action!],
          ],
        ),
      ),
    );
  }
}

/// A text field in the module's style.
class CmField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboard;
  final IconData? icon;
  final ValueChanged<String>? onChanged;

  const CmField(this.controller, this.label,
      {super.key, this.hint, this.maxLines = 1, this.keyboard, this.icon, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14.sp, color: Cm.text(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        prefixIcon: icon == null ? null : Icon(icon, size: 19.r),
        filled: true,
        fillColor: Cm.dark(context) ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Cm.border(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Cm.border(context))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      ),
    );
  }
}

/// Bottom sheet frame used by every editor in the module.
Future<T?> showCmSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext, StateSetter) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
          decoration: BoxDecoration(
            color: Cm.card(ctx),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 10.h),
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: Cm.border(ctx), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 12.w, 4.h),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: Cm.display(ctx, size: 20))),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
                    child: builder(ctx, ss),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A date (and optional time) field that opens the pickers.
class CmDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool withTime;
  final ValueChanged<DateTime> onPicked;

  const CmDateField({super.key, required this.label, required this.value, required this.onPicked, this.withTime = false});

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Choose'
        : withTime
            ? _fmtDateTime(value!)
            : _fmtDate(value!);
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 10),
          lastDate: DateTime(now.year + 5),
        );
        if (d == null) return;
        if (!withTime) return onPicked(d);
        if (!context.mounted) return;
        final t = await showTimePicker(
          context: context,
          initialTime: value != null ? TimeOfDay.fromDateTime(value!) : const TimeOfDay(hour: 10, minute: 30),
        );
        onPicked(DateTime(d.year, d.month, d.day, t?.hour ?? 10, t?.minute ?? 30));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Cm.dark(context) ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          suffixIcon: Icon(withTime ? Icons.schedule_rounded : Icons.calendar_today_rounded, size: 18.r),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Cm.border(context))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Cm.border(context))),
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        ),
        child: Text(text, style: GoogleFonts.inter(fontSize: 14.sp, color: value == null ? Cm.faint : Cm.text(context))),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String _fmtDateTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_fmtDate(d)} · $h:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String cmDate(DateTime? d) => d == null ? '—' : _fmtDate(d.toLocal());
String cmDateTime(DateTime? d) => d == null ? '—' : _fmtDateTime(d.toLocal());
String cmRupees(double? v) {
  if (v == null) return '—';
  final whole = v.round();
  final s = whole.abs().toString();
  // Indian grouping: 1,23,45,678
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return '${whole < 0 ? '-' : ''}₹$out';
}
