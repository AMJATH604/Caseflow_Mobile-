import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../components/error_state_widget.dart';
import '../theme/app_theme.dart';

class HearingsScreen extends ConsumerStatefulWidget {
  const HearingsScreen({super.key});

  @override
  ConsumerState<HearingsScreen> createState() => _HearingsScreenState();
}

class _HearingsScreenState extends ConsumerState<HearingsScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  String _view = "calendar"; // calendar, list

  @override
  Widget build(BuildContext context) {
    final hearingsAsync = ref.watch(hearingsProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(isMobile),
              const SizedBox(height: 24),
              Expanded(
                child: hearingsAsync.when(
                  data: (hearings) => _view == "calendar"
                      ? _buildCalendarView(isMobile, hearings)
                      : _buildListView(isMobile, hearings),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                  error: (err, stack) => ErrorStateWidget(
                    error: err,
                    onRetry: () => ref.invalidate(hearingsProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Court Schedule",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "TEMPORAL CASE MANAGEMENT",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38, 
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: AppTheme.cardDecoration(isDark: Theme.of(context).brightness == Brightness.dark),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _viewToggleBtn("calendar", Icons.calendar_today_rounded),
              _viewToggleBtn("list", Icons.format_list_bulleted_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewToggleBtn(String value, IconData icon) {
    final isSelected = _view == value;
    return GestureDetector(
      onTap: () => setState(() => _view = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon, 
          size: 18, 
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38)
        ),
      ),
    );
  }

  // ─── CALENDAR VIEW ───────────────────────────────────
  Widget _buildCalendarView(bool isMobile, List<dynamic> hearings) {
    return Column(
      children: [
        _buildCalendarGrid(hearings),
        const SizedBox(height: 24),
        // Hearings for the selected date
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.1)),
                ),
                child: const Icon(Icons.event_note_rounded, size: 18, color: AppTheme.accent),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(_selectedDate).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                    Text(
                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700, 
                        fontSize: 18, 
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildDayHearings(hearings),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(List<dynamic> hearings) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // Sun=0

    final hearingDays = <int, int>{};
    for (var h in hearings) {
      final d = h.hearingDate;
      if (d.year == _focusedMonth.year && d.month == _focusedMonth.month) {
        hearingDays[d.day] = (hearingDays[d.day] ?? 0) + 1;
      }
    }

    final totalCells = startWeekday + lastDay.day;
    final rows = ((totalCells) / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(isDark: Theme.of(context).brightness == Brightness.dark),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circularNavBtn(Icons.chevron_left_rounded, () => setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                })),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                      letterSpacing: 1.5),
                ),
                _circularNavBtn(Icons.chevron_right_rounded, () => setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                })),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: ["S", "M", "T", "W", "T", "F", "S"]
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(rows, (row) {
            return Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final day = cellIndex - startWeekday + 1;

                if (day < 1 || day > lastDay.day) {
                  return const Expanded(child: SizedBox(height: 44));
                }

                final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                final isToday = DateUtils.isSameDay(cellDate, DateTime.now());
                final isSelected = DateUtils.isSameDay(cellDate, _selectedDate);
                final count = hearingDays[day] ?? 0;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = cellDate),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accent
                            : isToday
                                ? AppTheme.accent.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected 
                              ? AppTheme.accent 
                              : isToday 
                                  ? AppTheme.accent.withValues(alpha: 0.2)
                                  : Colors.transparent
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (count > 0 && !isSelected)
                            Positioned(
                              top: 6, right: 6,
                              child: Container(
                                width: 4, height: 4,
                                decoration: const BoxDecoration(color: AppTheme.accentViolet, shape: BoxShape.circle),
                              ),
                            ),
                          Text(
                            '$day',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : (count > 0 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _circularNavBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceLight : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _buildDayHearings(List<dynamic> hearings) {
    final dayHearings = hearings
        .where((h) => DateUtils.isSameDay(h.hearingDate, _selectedDate))
        .toList();

    if (dayHearings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded, size: 40, color: Color(0xFF1F1F2E)),
            const SizedBox(height: 16),
            Text("NO SCHEDULED HEARINGS",
                style: GoogleFonts.inter(
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontSize: 11)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: dayHearings.length,
      itemBuilder: (context, index) {
        final h = dayHearings[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppTheme.cardDecoration(),
          child: InkWell(
            onTap: () => context.push('/cases/${h.caseId}'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.1)),
                    ),
                    child: const Center(child: Icon(Icons.gavel_rounded, size: 20, color: AppTheme.accent)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(
                            h.caseTitle ?? "Unknown Case",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          (h.purpose ?? h.stage ?? "Hearing").toUpperCase(),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6B7280), 
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF1F1F2E), size: 18),
                    onPressed: () => _deleteHearing(h.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── LIST VIEW ──────────────────────────────────────
  Widget _buildListView(bool isMobile, List<dynamic> hearings) {
    if (hearings.isEmpty) {
      return Center(
        child: Text(
          "No hearing records found", 
          style: GoogleFonts.inter(color: const Color(0xFF4B5563), fontWeight: FontWeight.w600, fontSize: 13)
        )
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: hearings.length,
      itemBuilder: (context, index) {
        final h = hearings[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppTheme.cardDecoration(),
          child: InkWell(
            onTap: () => context.push('/cases/${h.caseId}'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceLight : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('dd').format(h.hearingDate),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                        ),
                        Text(
                          DateFormat('MMM').format(h.hearingDate).toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(
                            h.caseTitle ?? "Unknown Case",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          (h.purpose ?? "HEARING").toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF6B7280), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF1F1F2E), size: 18),
                    onPressed: () => _deleteHearing(h.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _deleteHearing(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        title: const Text("Delete Hearing Reflection?"),
        content: const Text("This will remove the entry from your court schedule."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text("Remove", style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.deleteHearing(id);
      ref.invalidate(hearingsProvider);
    }
  }
}
