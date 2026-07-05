import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Premium Color Palette
class _C {
  static const primary = Color(0xFF4F46E5);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const accent = Color(0xFFF59E0B);
  static const violet = Color(0xFF7C3AED);
  static const blue = Color(0xFF2563EB);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
}

class BarEventsScreen extends ConsumerStatefulWidget {
  final String associationId;
  const BarEventsScreen({super.key, required this.associationId});

  @override
  ConsumerState<BarEventsScreen> createState() => _BarEventsScreenState();
}

class _BarEventsScreenState extends ConsumerState<BarEventsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String _selectedCategory = 'all';

  final _categoryColors = {
    'meeting': const Color(0xFF2563EB),
    'holiday': const Color(0xFFEF4444),
    'lecture': const Color(0xFF10B981),
    'sports': const Color(0xFFF59E0B),
    'annual': const Color(0xFF7C3AED),
  };

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(barEventsProvider(widget.associationId));

    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AppBar(
        title: Text(
          'Events & Calendar',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
            color: _C.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.textPrimary),
      ),
      body: eventsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _C.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48,
                  color: _C.danger.withValues(alpha: 0.5)),
              SizedBox(height: 12.h),
              Text('Failed to load events',
                  style: GoogleFonts.inter(color: _C.textMuted)),
            ],
          ),
        ),
        data: (events) => _buildContent(events),
      ),
    );
  }

  Widget _buildContent(List<BarEvent> allEvents) {
    final eventMap = <DateTime, List<BarEvent>>{};
    for (final event in allEvents) {
      final date = DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
      );
      eventMap.putIfAbsent(date, () => []).add(event);
    }

    final selectedDate = _selectedDay ?? _focusedDay;
    final normalizedSelected = DateTime(
      selectedDate.year, selectedDate.month, selectedDate.day);
    final dayEvents = eventMap[normalizedSelected] ?? [];

    final filteredAll = _selectedCategory == 'all'
        ? allEvents
        : allEvents.where((e) => e.category == _selectedCategory).toList();

    return Column(
      children: [
        // ── Calendar ──
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TableCalendar(
            firstDay: DateTime(2024),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            eventLoader: (day) {
              final normalized = DateTime(day.year, day.month, day.day);
              return eventMap[normalized] ?? [];
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: _C.primary,
              ),
              selectedDecoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              defaultTextStyle: GoogleFonts.inter(
                fontSize: 14.sp,
                color: _C.textPrimary,
              ),
              weekendTextStyle: GoogleFonts.inter(
                fontSize: 14.sp,
                color: _C.danger.withValues(alpha: 0.7),
              ),
              outsideTextStyle: GoogleFonts.inter(
                fontSize: 14.sp,
                color: const Color(0xFFCBD5E1),
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                shape: BoxShape.circle,
              ),
              markerSize: 6,
              markersMaxCount: 3,
            ),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: _C.border),
                borderRadius: BorderRadius.circular(8.r),
              ),
              formatButtonTextStyle: GoogleFonts.inter(
                fontSize: 12.sp,
                color: _C.textSecondary,
              ),
              titleTextStyle: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: _C.textPrimary,
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF475569),
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF475569),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _C.textMuted,
              ),
              weekendStyle: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _C.danger.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // ── Category Chips ──
        SizedBox(
          height: 40.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            children: [
              _buildCategoryChip('all', 'All', null),
              _buildCategoryChip('meeting', '📋 Meeting', _categoryColors['meeting']),
              _buildCategoryChip('holiday', '🏖️ Holiday', _categoryColors['holiday']),
              _buildCategoryChip('lecture', '🎓 Lecture', _categoryColors['lecture']),
              _buildCategoryChip('sports', '🏏 Sports', _categoryColors['sports']),
              _buildCategoryChip('annual', '🎉 Annual', _categoryColors['annual']),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // ── Events List ──
        Expanded(
          child: dayEvents.isNotEmpty
              ? _buildDayEvents(dayEvents)
              : _buildAllEvents(filteredAll),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String key, String label, Color? color) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _C.textSecondary,
          ),
        ),
        selectedColor: color ?? _C.primary,
        backgroundColor: _C.card,
        side: BorderSide(
          color: isSelected ? (color ?? _C.primary) : _C.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        showCheckmark: false,
        onSelected: (_) {
          setState(() {
            _selectedCategory = key;
            _selectedDay = null;
          });
        },
      ),
    );
  }

  Widget _buildDayEvents(List<BarEvent> events) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            children: [
              Text(
                'Events on ${DateFormat('dd MMM yyyy').format(_selectedDay ?? _focusedDay)}',
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${events.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _C.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...events.map((e) => _buildEventCard(e)),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget _buildAllEvents(List<BarEvent> events) {
    final upcoming = events
        .where((e) => e.eventDate.isAfter(DateTime.now().subtract(const Duration(days: 1))))
        .toList();
    final past = events
        .where((e) => e.eventDate.isBefore(DateTime.now().subtract(const Duration(days: 1))))
        .toList();

    if (upcoming.isEmpty && past.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.h,
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Icon(
                Icons.event_rounded,
                size: 36,
                color: _C.primary.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No events',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _C.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      children: [
        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader('Upcoming Events', upcoming.length),
          ...upcoming.map((e) => _buildEventCard(e)),
          SizedBox(height: 16.h),
        ],
        if (past.isNotEmpty) ...[
          _buildSectionHeader('Past Events', past.length),
          ...past.map((e) => _buildEventCard(e, isPast: true)),
        ],
        SizedBox(height: 32.h),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: _C.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BarEvent event, {bool isPast = false}) {
    final color = _categoryColors[event.category] ?? _C.textSecondary;

    return GestureDetector(
      onTap: () => _showEventDetail(event),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: isPast ? 0.5 : 1.0,
          child: Row(
            children: [
              // Color strip
              Container(
                width: 4.w,
                height: 80.h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    bottomLeft: Radius.circular(16.r),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Date column
              Container(
                width: 52.w,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd').format(event.eventDate),
                      style: GoogleFonts.inter(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(event.eventDate).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Details
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: _C.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          if (event.startTime != null) ...[
                            Icon(Icons.schedule_rounded, size: 13, color: _C.textMuted),
                            SizedBox(width: 4.w),
                            Text(
                              event.startTime!,
                              style: GoogleFonts.inter(fontSize: 12.sp, color: _C.textMuted),
                            ),
                            SizedBox(width: 12.w),
                          ],
                          if (event.location != null) ...[
                            Icon(Icons.location_on_rounded, size: 13, color: _C.textMuted),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                event.location!,
                                style: GoogleFonts.inter(fontSize: 12.sp, color: _C.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Category badge
              Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    event.categoryLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetail(BarEvent event) {
    final color = _categoryColors[event.category] ?? _C.textSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
        ),
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Category + Date
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    event.categoryLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('EEEE, dd MMM yyyy').format(event.eventDate),
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: _C.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Title
            Text(
              event.title,
              style: GoogleFonts.inter(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            SizedBox(height: 16.h),

            // Time & Location
            if (event.startTime != null || event.location != null)
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  children: [
                    if (event.startTime != null)
                      Row(
                        children: [
                          Container(
                            width: 36.w,
                            height: 36.h,
                            decoration: BoxDecoration(
                              color: _C.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: const Icon(Icons.schedule_rounded,
                                size: 18, color: _C.primary),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            '${event.startTime}${event.endTime != null ? ' — ${event.endTime}' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: _C.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    if (event.startTime != null && event.location != null)
                      SizedBox(height: 12.h),
                    if (event.location != null)
                      Row(
                        children: [
                          Container(
                            width: 36.w,
                            height: 36.h,
                            decoration: BoxDecoration(
                              color: _C.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                size: 18, color: _C.danger),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: _C.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            // Description
            if (event.description != null) ...[
              SizedBox(height: 16.h),
              Text(
                event.description!,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: _C.textSecondary,
                  height: 1.6.h,
                ),
              ),
            ],

            // Agenda
            if (event.agenda != null) ...[
              SizedBox(height: 20.h),
              Text(
                'Agenda',
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                event.agenda!,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: _C.textSecondary,
                  height: 1.6.h,
                ),
              ),
            ],
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}
