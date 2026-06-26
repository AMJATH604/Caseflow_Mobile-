import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';

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
    final eventsAsync =
        ref.watch(barEventsProvider(widget.associationId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Events & Calendar',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('Failed to load events', style: GoogleFonts.inter()),
            ],
          ),
        ),
        data: (events) => _buildContent(events),
      ),
    );
  }

  Widget _buildContent(List<BarEvent> allEvents) {
    // Build events map for calendar
    final eventMap = <DateTime, List<BarEvent>>{};
    for (final event in allEvents) {
      final date = DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
      );
      eventMap.putIfAbsent(date, () => []).add(event);
    }

    // Events for selected day
    final selectedDate = _selectedDay ?? _focusedDay;
    final normalizedSelected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final dayEvents = eventMap[normalizedSelected] ?? [];

    // Filter by category
    final filteredAll = _selectedCategory == 'all'
        ? allEvents
        : allEvents.where((e) => e.category == _selectedCategory).toList();

    return Column(
      children: [
        // ── Calendar ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: AppTheme.cardDecoration(),
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
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: (day) {
              final normalized = DateTime(day.year, day.month, day.day);
              return eventMap[normalized] ?? [];
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFF0891B2).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              todayTextStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0891B2),
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF0891B2),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              defaultTextStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF1E293B),
              ),
              weekendTextStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFEF4444),
              ),
              outsideTextStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFCBD5E1),
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              markerSize: 6,
              markersMaxCount: 3,
            ),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF475569),
              ),
              titleTextStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
              weekendStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFEF4444).withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Category Chips ──
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryChip('all', 'All', null),
              _buildCategoryChip('meeting', '📋 Meeting', _categoryColors['meeting']!),
              _buildCategoryChip('holiday', '🏖️ Holiday', _categoryColors['holiday']!),
              _buildCategoryChip('lecture', '🎓 Lecture', _categoryColors['lecture']!),
              _buildCategoryChip('sports', '🏏 Sports', _categoryColors['sports']!),
              _buildCategoryChip('annual', '🎉 Annual', _categoryColors['annual']!),
            ],
          ),
        ),
        const SizedBox(height: 12),

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
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
        selectedColor: color ?? const Color(0xFF0891B2),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected
              ? (color ?? const Color(0xFF0891B2))
              : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Events on ${DateFormat('dd/MM/yyyy').format(_selectedDay ?? _focusedDay)}',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        ...events.map((e) => _buildEventCard(e)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAllEvents(List<BarEvent> events) {
    final upcoming = events
        .where(
          (e) => e.eventDate.isAfter(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
        )
        .toList();
    final past = events
        .where(
          (e) => e.eventDate.isBefore(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
        )
        .toList();

    if (upcoming.isEmpty && past.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.event_rounded,
                size: 40,
                color: Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No events',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader('Upcoming Events', upcoming.length),
          ...upcoming.map((e) => _buildEventCard(e)),
          const SizedBox(height: 16),
        ],
        if (past.isNotEmpty) ...[
          _buildSectionHeader('Past Events', past.length),
          ...past.map((e) => _buildEventCard(e, isPast: true)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BarEvent event, {bool isPast = false}) {
    final color = _categoryColors[event.category] ?? const Color(0xFF475569);

    return GestureDetector(
      onTap: () => _showEventDetail(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppTheme.cardDecoration(),
        child: Opacity(
          opacity: isPast ? 0.6 : 1.0,
          child: Row(
            children: [
              // Color strip
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Date column
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd').format(event.eventDate),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(event.eventDate).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (event.startTime != null) ...[
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.startTime!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (event.location != null) ...[
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                event.location!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
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
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.categoryLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
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
    final color = _categoryColors[event.category] ?? const Color(0xFF475569);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category + Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.categoryLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('EEEE, dd/MM/yyyy').format(event.eventDate),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              event.title,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),

            // Time & Location
            if (event.startTime != null || event.location != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (event.startTime != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${event.startTime}${event.endTime != null ? ' — ${event.endTime}' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    if (event.startTime != null && event.location != null)
                      const SizedBox(height: 10),
                    if (event.location != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1E293B),
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
              const SizedBox(height: 16),
              Text(
                event.description!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF475569),
                  height: 1.6,
                ),
              ),
            ],

            // Agenda
            if (event.agenda != null) ...[
              const SizedBox(height: 16),
              Text(
                'Agenda',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event.agenda!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF475569),
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
