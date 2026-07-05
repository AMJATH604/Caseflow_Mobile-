import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/commission_models.dart';
import '../services/commission_service.dart';
import '../theme/app_theme.dart';
import 'commissions_screen.dart';
import 'commission_report_screen.dart';
import 'commission_field_visit_screen.dart';
import 'commission_witness_screen.dart';
import 'commission_sketch_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CommissionDetailScreen extends ConsumerStatefulWidget {
  final String commissionId;
  const CommissionDetailScreen({super.key, required this.commissionId});
  @override
  ConsumerState<CommissionDetailScreen> createState() =>
      _CommissionDetailScreenState();
}

class _CommissionDetailScreenState extends ConsumerState<CommissionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Commission? _commission;
  List<CommissionVisit> _visits = [];
  List<CommissionObservation> _observations = [];
  List<CommissionEvidence> _evidence = [];
  List<CommissionExpense> _expenses = [];
  List<CommissionWitness> _witnesses = [];
  List<CommissionSketch> _sketches = [];
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String? _activeVisitId;

  // Speech to text
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 8, vsync: this);
    _load();
    _initSpeech();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _speech.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await CommissionService.fetchCommissionById(
        widget.commissionId,
      );
      final v = await CommissionService.fetchVisits(widget.commissionId);
      final o = await CommissionService.fetchObservations(widget.commissionId);
      final e = await CommissionService.fetchEvidence(widget.commissionId);
      final ex = await CommissionService.fetchExpenses(widget.commissionId);
      final w = await CommissionService.fetchWitnesses(widget.commissionId);
      final sk = await CommissionService.fetchSketches(widget.commissionId);
      final docs = await CommissionService.fetchCommissionDocuments(
        widget.commissionId,
      );
      final active =
          v.where((vi) => vi.visitStatus == VisitStatus.checkedIn).toList();
      setState(() {
        _commission = c;
        _visits = v;
        _observations = o;
        _evidence = e;
        _expenses = ex;
        _witnesses = w;
        _sketches = sk;
        _documents = docs;
        _activeVisitId = active.isNotEmpty ? active.first.id : null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_commission == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Commission not found')),
      );
    }
    final c = _commission!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          c.commissionType.label,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(v, c),
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: 'edit_status',
                    child: Text('Change Status'),
                  ),
                  const PopupMenuItem(
                    value: 'generate_report',
                    child: Text('Generate Report'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete Commission',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: dk ? Colors.white38 : Colors.black38,
          labelStyle: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Visits'),
            const Tab(text: 'Evidence'),
            const Tab(text: 'Notes'),
            Tab(text: 'Witnesses (${_witnesses.length})'),
            Tab(text: 'Sketches (${_sketches.length})'),
            Tab(text: 'Documents (${_documents.length})'),
            const Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _overviewTab(dk, c),
          _visitsTab(dk),
          _evidenceTab(dk),
          _notesTab(dk),
          _witnessesTab(dk),
          _sketchesTab(dk),
          _documentsTab(dk),
          _expensesTab(dk),
        ],
      ),
    );
  }

  // ─── OVERVIEW TAB ────────────────────────────────────────
  Widget _overviewTab(bool dk, Commission c) => ListView(
    padding: EdgeInsets.all(16.r),
    children: [
      // Start Field Visit Button (Phase 2)
      if (_activeVisitId != null)
        Container(
          margin: EdgeInsets.only(bottom: 12.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _goFieldVisit(_activeVisitId!),
              borderRadius: BorderRadius.circular(16.r),
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Row(
                  children: [
                    Icon(Icons.gps_fixed, color: Colors.white, size: 28),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Field Visit',
                            style: GoogleFonts.outfit(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Tap to open field workspace',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

      // Commission Info
      _infoCard(dk, 'Commission Info', [
        _row('Type', c.commissionType.label, dk),
        _row('Status', c.status.label, dk),
        if (c.courtName != null) _row('Court', c.courtName!, dk),
        if (c.caseNumberRef != null) _row('Case No.', c.caseNumberRef!, dk),
        if (c.warrantDate != null)
          _row(
            'Warrant Date',
            DateFormat('dd MMM yyyy').format(c.warrantDate!),
            dk,
          ),
        if (c.deadlineDate != null)
          _row(
            'Deadline',
            DateFormat('dd MMM yyyy').format(c.deadlineDate!),
            dk,
            highlight: c.isOverdue,
          ),
        if (c.daysRemaining != null)
          _row(
            'Days Left',
            c.isOverdue
                ? 'OVERDUE by ${(-c.daysRemaining!)} days'
                : '${c.daysRemaining} days',
            dk,
            highlight: c.isOverdue,
          ),
      ]),
      SizedBox(height: 12.h),

      // Timeline (Phase 2)
      _buildTimeline(dk, c),
      SizedBox(height: 12.h),

      _infoCard(dk, 'Property Details', [
        if (c.propertyDescription != null)
          _row('Description', c.propertyDescription!, dk),
        if (c.surveyNumber != null) _row('Survey No.', c.surveyNumber!, dk),
        _row('Location', c.locationSummary, dk),
      ]),
      SizedBox(height: 12.h),
      if (c.partyPetitioner != null || c.partyRespondent != null)
        _infoCard(dk, 'Parties', [
          if (c.partyPetitioner != null)
            _row('Petitioner', c.partyPetitioner!, dk),
          if (c.partyRespondent != null)
            _row('Respondent', c.partyRespondent!, dk),
        ]),
      SizedBox(height: 12.h),
      if (c.scopeOfWork != null)
        _infoCard(dk, 'Scope of Work', [
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Text(
              c.scopeOfWork!,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: dk ? Colors.white70 : Colors.black54,
                height: 1.5.h,
              ),
            ),
          ),
        ]),
      SizedBox(height: 16.h),
      // Quick Action Buttons
      Row(
        children: [
          Expanded(
            child: _actionBtn(
              dk,
              Icons.gps_fixed,
              'Check In',
              AppTheme.success,
              () => _checkIn(),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _actionBtn(
              dk,
              Icons.camera_alt,
              'Capture',
              AppTheme.info,
              () => _captureEvidence(),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _actionBtn(
              dk,
              Icons.note_add,
              'Add Note',
              AppTheme.accentViolet,
              () => _addNote(),
            ),
          ),
        ],
      ),
      SizedBox(height: 8.h),
      Row(
        children: [
          Expanded(
            child: _actionBtn(
              dk,
              Icons.person_add,
              'Witness',
              AppTheme.warning,
              () => _goWitness(),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _actionBtn(
              dk,
              Icons.picture_as_pdf,
              'Report',
              AppTheme.error,
              () => _goReport(),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _actionBtn(
              dk,
              Icons.gps_not_fixed,
              'Check Out',
              const Color(0xFF64748B),
              () => _checkOut(),
            ),
          ),
        ],
      ),
    ],
  );

  // ─── TIMELINE (Phase 2) ─────────────────────────────────
  Widget _buildTimeline(bool dk, Commission c) {
    final events = <_TimelineEvent>[];
    if (c.warrantDate != null) {
      events.add(
        _TimelineEvent(
          date: c.warrantDate!,
          title: 'Warrant Received',
          icon: Icons.description,
          color: AppTheme.accent,
          done: true,
        ),
      );
    }
    for (int i = 0; i < _visits.length; i++) {
      final v = _visits[_visits.length - 1 - i]; // reverse to chronological
      events.add(
        _TimelineEvent(
          date: v.visitDate,
          title: 'Site Visit #${i + 1}',
          subtitle:
              '📸 ${_evidence.where((e) => e.visitId == v.id).length} photos, 📝 ${_observations.where((o) => o.visitId == v.id).length} notes',
          icon: Icons.location_on,
          color: AppTheme.success,
          done: true,
        ),
      );
    }
    if (_witnesses.isNotEmpty) {
      events.add(
        _TimelineEvent(
          date: _witnesses.first.createdAt,
          title: '${_witnesses.length} Witness(es) Recorded',
          icon: Icons.person,
          color: AppTheme.warning,
          done: true,
        ),
      );
    }
    if (_sketches.isNotEmpty) {
      events.add(
        _TimelineEvent(
          date: _sketches.first.createdAt,
          title: '${_sketches.length} Sketch(es) Created',
          icon: Icons.draw,
          color: const Color(0xFF8B5CF6),
          done: true,
        ),
      );
    }
    if (c.status == CommissionStatus.reportDrafting ||
        c.status == CommissionStatus.submitted) {
      events.add(
        _TimelineEvent(
          date: DateTime.now(),
          title: 'Report Generated',
          icon: Icons.picture_as_pdf,
          color: AppTheme.error,
          done: true,
        ),
      );
    }
    if (c.deadlineDate != null) {
      events.add(
        _TimelineEvent(
          date: c.deadlineDate!,
          title: 'Deadline',
          icon: Icons.flag,
          color: c.isOverdue ? AppTheme.error : AppTheme.warning,
          done:
              c.status == CommissionStatus.submitted ||
              c.status == CommissionStatus.closed,
        ),
      );
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return _infoCard(dk, 'Commission Timeline', [
      Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          children:
              events.asMap().entries.map((entry) {
                final e = entry.value;
                final isLast = entry.key == events.length - 1;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 12.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: e.done ? e.color : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: e.color, width: 2.w),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2.w,
                                margin: EdgeInsets.symmetric(vertical: 2.h),
                                color:
                                    dk
                                        ? const Color(0xFF2D2D3F)
                                        : AppTheme.borderLight,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DateFormat('dd MMM').format(e.date),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.sp,
                                      color:
                                          dk ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (e.title == 'Deadline' && c.isOverdue)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        'OVERDUE',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                e.title,
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      dk
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                ),
                              ),
                              if (e.subtitle != null)
                                Text(
                                  e.subtitle!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: dk ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    ]);
  }

  Widget _infoCard(bool dk, String title, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(
        color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: dk ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
        Divider(height: 1.h),
        ...children,
      ],
    ),
  );

  Widget _row(String label, String value, bool dk, {bool highlight = false}) =>
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            SizedBox(
              width: 100.w,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: dk ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color:
                      highlight
                          ? AppTheme.error
                          : (dk ? Colors.white : const Color(0xFF1E293B)),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _actionBtn(
    bool dk,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => Material(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12.r),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ─── VISITS TAB ──────────────────────────────────────────
  Widget _visitsTab(bool dk) {
    if (_visits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off,
              size: 48,
              color: dk ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 12.h),
            Text(
              'No visits recorded yet',
              style: GoogleFonts.inter(
                color: dk ? Colors.white38 : Colors.black38,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: _checkIn,
              icon: const Icon(Icons.gps_fixed, size: 18),
              label: const Text('Check In Now'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.r),
      itemCount: _visits.length,
      itemBuilder: (_, i) {
        final v = _visits[i];
        final sc =
            v.visitStatus == VisitStatus.checkedIn
                ? AppTheme.success
                : v.visitStatus == VisitStatus.completed
                ? AppTheme.info
                : v.visitStatus == VisitStatus.obstructed
                ? AppTheme.error
                : AppTheme.warning;
        return GestureDetector(
          onTap:
              v.visitStatus == VisitStatus.checkedIn
                  ? () => _goFieldVisit(v.id)
                  : null,
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: dk ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color:
                    v.visitStatus == VisitStatus.checkedIn
                        ? AppTheme.success
                        : (dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight),
                width: v.visitStatus == VisitStatus.checkedIn ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: sc, size: 20),
                    SizedBox(width: 8.w),
                    Text(
                      DateFormat('dd MMM yyyy').format(v.visitDate),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: dk ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        v.visitStatus.label,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: sc,
                        ),
                      ),
                    ),
                  ],
                ),
                if (v.checkinTime != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    'Check-in: ${DateFormat('hh:mm a').format(v.checkinTime!.toLocal())}',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: dk ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
                if (v.checkinLat != null && v.checkinLat != 0)
                  Text(
                    'GPS: ${v.checkinLat!.toStringAsFixed(6)}, ${v.checkinLng!.toStringAsFixed(6)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.sp,
                      color: dk ? Colors.white38 : Colors.black38,
                    ),
                  ),
                if (v.checkinAddress != null)
                  Text(
                    '📍 ${v.checkinAddress}',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: dk ? Colors.white38 : Colors.black38,
                    ),
                  ),
                if (v.checkoutTime != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'Check-out: ${DateFormat('hh:mm a').format(v.checkoutTime!.toLocal())}${v.durationText != null ? ' (${v.durationText})' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: dk ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
                if (v.personsPresent != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'Present: ${v.personsPresent}',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: dk ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
                if (v.obstructionDetails != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '⚠️ ${v.obstructionDetails}',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: AppTheme.error,
                    ),
                  ),
                ],
                if (v.visitStatus == VisitStatus.checkedIn) ...[
                  SizedBox(height: 8.h),
                  Text(
                    '🟢 Active — Tap to open Field Visit',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── EVIDENCE TAB ────────────────────────────────────────
  Widget _evidenceTab(bool dk) {
    if (_evidence.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: dk ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 12.h),
            Text(
              'No evidence captured',
              style: GoogleFonts.inter(
                color: dk ? Colors.white38 : Colors.black38,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: _captureEvidence,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Capture Photo'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (_evidence.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloadAllPhotos,
                icon: const Icon(Icons.download_for_offline, size: 18),
                label: Text(
                  'Download All Photos for Print',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.info,
                  side: BorderSide(color: AppTheme.info.withValues(alpha: 0.5)),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(16.r),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: _evidence.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Material(
                  color:
                      dk
                          ? const Color(0xFF1E1E2E)
                          : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14.r),
                  child: InkWell(
                    onTap: _captureEvidence,
                    borderRadius: BorderRadius.circular(14.r),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo,
                          size: 32,
                          color: AppTheme.accent,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Add Photo',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final ev = _evidence[i - 1];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(13.r),
                            ),
                            child: Image.network(
                              ev.fileUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    color:
                                        dk
                                            ? Colors.white10
                                            : Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 32,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(13.r),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${ev.sequenceNumber}${ev.caption != null ? ' - ${ev.caption}' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: dk ? Colors.white70 : Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                ev.locationText,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.sp,
                                  color: dk ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Download button overlay
                    Positioned(
                      top: 6.h,
                      right: 6.w,
                      child: GestureDetector(
                        onTap: () => _downloadSinglePhoto(ev),
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── NOTES TAB ───────────────────────────────────────────
  Widget _notesTab(bool dk) {
    if (_observations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 48,
              color: dk ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 12.h),
            Text(
              'No observations recorded',
              style: GoogleFonts.inter(
                color: dk ? Colors.white38 : Colors.black38,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: _addNote,
              icon: const Icon(Icons.note_add, size: 18),
              label: const Text('Add Note'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        ..._observations.map(
          (o) => Container(
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: dk ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentViolet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        o.observationType.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentViolet,
                        ),
                      ),
                    ),
                    Spacer(),
                    Text(
                      DateFormat(
                        'dd MMM, hh:mm a',
                      ).format(o.createdAt.toLocal()),
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: dk ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppTheme.error,
                      ),
                      onPressed: () async {
                        await CommissionService.deleteObservation(o.id);
                        _load();
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  o.content,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: dk ? Colors.white : const Color(0xFF1E293B),
                    height: 1.5.h,
                  ),
                ),
                if (o.tags.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 4,
                    children:
                        o.tags
                            .map(
                              (t) => Chip(
                                label: Text(
                                  '#$t',
                                  style: GoogleFonts.inter(fontSize: 10.sp),
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 60.h),
      ],
    );
  }

  // ─── WITNESSES TAB (Phase 2) ─────────────────────────────
  Widget _witnessesTab(bool dk) {
    if (_witnesses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search,
              size: 48,
              color: dk ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 12.h),
            Text(
              'No witnesses recorded',
              style: GoogleFonts.inter(
                color: dk ? Colors.white38 : Colors.black38,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: _goWitness,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Record Witness'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.r),
      itemCount: _witnesses.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Material(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.r),
              child: InkWell(
                onTap: _goWitness,
                borderRadius: BorderRadius.circular(14.r),
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: AppTheme.warning),
                      SizedBox(width: 12.w),
                      Text(
                        'Record New Witness',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final w = _witnesses[i - 1];
        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: dk ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child:
                    w.photoUrl != null
                        ? Image.network(
                          w.photoUrl!,
                          width: 56.w,
                          height: 56.h,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _witnessAvatar(dk, w),
                        )
                        : _witnessAvatar(dk, w),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.witnessName,
                      style: GoogleFonts.outfit(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: dk ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${w.idLabel}${w.idNumber != null ? ': ${w.idNumber}' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: dk ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    if (w.statementText != null) ...[
                      SizedBox(height: 6.h),
                      Text(
                        w.statementText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: dk ? Colors.white70 : Colors.black54,
                          height: 1.4.h,
                        ),
                      ),
                    ],
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        if (w.audioUrl != null) ...[
                          GestureDetector(
                            onTap: () => _playWitnessAudio(w),
                            child: _witnessTag(
                              _currentlyPlayingId == w.id
                                  ? Icons.stop
                                  : Icons.play_arrow,
                              _currentlyPlayingId == w.id
                                  ? 'Playing...'
                                  : 'Original Voice',
                              _currentlyPlayingId == w.id
                                  ? AppTheme.error
                                  : AppTheme.accentViolet,
                            ),
                          ),
                        ],
                        if (w.signatureUrl != null)
                          _witnessTag(Icons.draw, 'Signed', AppTheme.success),
                        Spacer(),
                        Text(
                          w.locationText,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.sp,
                            color: dk ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: AppTheme.error.withValues(alpha: 0.5),
                ),
                onPressed: () async {
                  await CommissionService.deleteWitness(w.id);
                  _load();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _witnessAvatar(bool dk, CommissionWitness w) => Container(
    width: 56.w,
    height: 56.h,
    decoration: BoxDecoration(
      color: AppTheme.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Center(
      child: Text(
        w.witnessName.isNotEmpty ? w.witnessName[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          color: AppTheme.warning,
        ),
      ),
    ),
  );

  Widget _witnessTag(IconData icon, String label, Color color) => Container(
    margin: EdgeInsets.only(right: 6.w),
    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        SizedBox(width: 3.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );

  // ─── SKETCHES TAB (Phase 2) ──────────────────────────────
  Widget _sketchesTab(bool dk) {
    if (_sketches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.draw,
              size: 48,
              color: dk ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 12.h),
            Text(
              'No sketches created',
              style: GoogleFonts.inter(
                color: dk ? Colors.white38 : Colors.black38,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: () => _openSketchPad(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Sketch'),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.all(16.r),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _sketches.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Material(
            color:
                dk
                    ? const Color(0xFF1E1E2E)
                    : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14.r),
            child: InkWell(
              onTap: () => _openSketchPad(),
              borderRadius: BorderRadius.circular(14.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 32, color: Color(0xFF8B5CF6)),
                  SizedBox(height: 8.h),
                  Text(
                    'New Sketch',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final sk = _sketches[i - 1];
        return GestureDetector(
          onTap: () => _editSketch(sk),
          onLongPress: () => _deleteSketch(sk),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(13.r),
                        ),
                        child:
                            sk.sketchImageUrl != null
                                ? Image.network(
                                  sk.sketchImageUrl!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  errorBuilder:
                                      (_, __, ___) => _sketchPlaceholder(dk),
                                )
                                : _sketchPlaceholder(dk),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(13.r),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sk.title,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color:
                                  dk ? Colors.white70 : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            sk.sketchTypeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              color: dk ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Download button
                if (sk.sketchImageUrl != null)
                  Positioned(
                    top: 4.h,
                    left: 4.w,
                    child: GestureDetector(
                      onTap: () => _downloadSingleSketch(sk),
                      child: Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Delete button in corner
                Positioned(
                  top: 4.h,
                  right: 4.w,
                  child: GestureDetector(
                    onTap: () => _deleteSketch(sk),
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sketchPlaceholder(bool dk) => Container(
    color:
        dk
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
    child: Center(
      child: Icon(
        Icons.draw,
        size: 32,
        color: dk ? Colors.white12 : Colors.black12,
      ),
    ),
  );

  // ─── DOCUMENTS TAB (Vault) ───────────────────────────────
  Widget _documentsTab(bool dk) {
    return Stack(
      children: [
        if (_documents.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open,
                  size: 56,
                  color: dk ? Colors.white24 : Colors.black12,
                ),
                SizedBox(height: 16.h),
                Text(
                  'DOCUMENT VAULT EMPTY',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                    color: dk ? Colors.white24 : Colors.black26,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Upload court warrants, orders, maps, etc.',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: dk ? Colors.white38 : Colors.black38,
                  ),
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: _uploadDocument,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: _documents.length,
            itemBuilder: (_, i) {
              final doc = _documents[i];
              final name = doc['name'] as String? ?? 'Unknown';
              return Container(
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: _docColor(name).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        _docIcon(name),
                        color: _docColor(name),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color:
                                  dk ? Colors.white : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            'SECURE VAULT',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                              color: dk ? Colors.white24 : Colors.black26,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: AppTheme.info,
                        size: 22,
                      ),
                      tooltip: 'Download',
                      onPressed: () async {
                        final url = doc['url'] as String?;
                        if (url != null) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: AppTheme.error.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      tooltip: 'Delete',
                      onPressed: () => _deleteDocument(name),
                    ),
                  ],
                ),
              );
            },
          ),
        // FAB for upload
        Positioned(
          bottom: 24.h,
          right: 24.w,
          child: FloatingActionButton(
            heroTag: 'upload_comm_doc',
            onPressed: _uploadDocument,
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            elevation: 8,
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ],
    );
  }

  IconData _docIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return Icons.image;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Color _docColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return AppTheme.error;
    if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return AppTheme.info;
    if (['doc', 'docx'].contains(ext)) return AppTheme.accent;
    return AppTheme.warning;
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    try {
      setState(() => _loading = true);
      await CommissionService.uploadCommissionDocument(
        commissionId: widget.commissionId,
        fileBytes: file.bytes!,
        fileName: file.name,
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${file.name}" uploaded to vault'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Document?'),
            content: Text(
              'Are you sure you want to delete "$fileName"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    try {
      await CommissionService.deleteCommissionDocument(
        widget.commissionId,
        fileName,
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$fileName" deleted'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // ─── EXPENSES TAB ────────────────────────────────────────
  Widget _expensesTab(bool dk) {
    final double total = _expenses.fold(0, (sum, e) => sum + e.amount);
    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(16.r),
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.white, size: 28),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Expenses',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '₹${total.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _addExpense,
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _expenses.isEmpty
                  ? Center(
                    child: Text(
                      'No expenses recorded',
                      style: GoogleFonts.inter(
                        color: dk ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  )
                  : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: _expenses.length,
                    itemBuilder: (_, i) {
                      final e = _expenses[i];
                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color:
                                dk
                                    ? const Color(0xFF2D2D3F)
                                    : AppTheme.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: const Icon(
                                Icons.receipt,
                                color: AppTheme.warning,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.expenseType.label,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.sp,
                                      color:
                                          dk
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (e.description != null)
                                    Text(
                                      e.description!,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        color:
                                            dk
                                                ? Colors.white54
                                                : Colors.black45,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(e.expenseDate),
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      color:
                                          dk ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${e.amount.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color:
                                    dk ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            SizedBox(width: 4.w),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppTheme.error.withValues(alpha: 0.6),
                              ),
                              onPressed: () async {
                                await CommissionService.deleteExpense(e.id);
                                _load();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  // ─── AUDIO PLAYBACK ──────────────────────────────────────

  Future<void> _playWitnessAudio(CommissionWitness w) async {
    if (_currentlyPlayingId == w.id) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
      return;
    }

    if (w.audioUrl == null) return;

    try {
      setState(() => _currentlyPlayingId = w.id);
      await _audioPlayer.play(UrlSource(w.audioUrl!));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _currentlyPlayingId = null);
      });
    } catch (e) {
      setState(() => _currentlyPlayingId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // ─── ACTIONS ─────────────────────────────────────────────

  Future<void> _checkIn() async {
    try {
      final visit = await CommissionService.checkIn(widget.commissionId);
      setState(() => _activeVisitId = visit.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Checked in! GPS: ${visit.checkinLat?.toStringAsFixed(4)}, ${visit.checkinLng?.toStringAsFixed(4)}',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
        // Auto-open field visit screen
        _goFieldVisit(visit.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _checkOut() async {
    if (_activeVisitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active visit to check out from')),
      );
      return;
    }
    try {
      await CommissionService.checkOut(_activeVisitId!);
      setState(() => _activeVisitId = null);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Checked out — GPS recorded'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _captureEvidence() async {
    String? visitId = _activeVisitId;
    if (visitId == null && _visits.isNotEmpty) visitId = _visits.first.id;
    if (visitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check in first before capturing evidence'),
        ),
      );
      return;
    }

    // Explicitly request GPS permissions and position BEFORE opening camera
    bool gpsAvailable = false;
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Please turn on Location/GPS for evidence tagging',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever &&
          serviceEnabled) {
        gpsAvailable = true;
      }
    } catch (_) {}

    if (!gpsAvailable && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ GPS unavailable — photo will be saved without coordinates',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;
    try {
      final bytes = await photo.readAsBytes();
      final name = 'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await CommissionService.uploadEvidence(
        commissionId: widget.commissionId,
        visitId: visitId,
        fileBytes: bytes,
        fileName: name,
        caption: 'Photo #${_evidence.length + 1}',
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gpsAvailable
                  ? '📸 Evidence captured with GPS'
                  : '📸 Evidence captured (no GPS)',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _ensureStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      // For Android 13+ (API 33+), use photos permission
      final photosStatus = await Permission.photos.status;
      if (!photosStatus.isGranted) {
        await Permission.photos.request();
      }
    }
  }

  Future<void> _downloadAllPhotos() async {
    if (_evidence.isEmpty) return;

    await _ensureStoragePermission();
    setState(() => _loading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📥 Saving photos to CaseFlow/Evidence...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      int saved = 0;
      for (final ev in _evidence) {
        final bytes = await CommissionService.downloadFile(
          'commission-evidence',
          ev.fileUrl,
        );
        if (bytes != null) {
          final result = await ImageGallerySaverPlus.saveImage(
            bytes,
            quality: 100,
            name:
                'CaseFlow_Evidence_${ev.sequenceNumber}_${DateTime.now().millisecondsSinceEpoch}',
          );
          if (result['isSuccess'] == true) saved++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $saved/${_evidence.length} photos saved to gallery',
            ),
            backgroundColor: AppTheme.success,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () async {
                // Also offer share option
                final tempDir = await getTemporaryDirectory();
                final List<XFile> files = [];
                for (final ev in _evidence) {
                  final bytes = await CommissionService.downloadFile(
                    'commission-evidence',
                    ev.fileUrl,
                  );
                  if (bytes != null) {
                    final file = File(
                      '${tempDir.path}/evidence_${ev.sequenceNumber}.jpg',
                    );
                    await file.writeAsBytes(bytes);
                    files.add(XFile(file.path));
                  }
                }
                if (files.isNotEmpty) {
                  Share.shareXFiles(files, text: 'Commission Evidence Photos');
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadSinglePhoto(CommissionEvidence ev) async {
    await _ensureStoragePermission();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 Downloading photo #${ev.sequenceNumber}...'),
        duration: const Duration(seconds: 1),
      ),
    );
    try {
      final bytes = await CommissionService.downloadFile(
        'commission-evidence',
        ev.fileUrl,
      );
      if (bytes != null) {
        await ImageGallerySaverPlus.saveImage(
          bytes,
          quality: 100,
          name:
              'CaseFlow_Evidence_${ev.sequenceNumber}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Photo #${ev.sequenceNumber} saved to gallery'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to download photo'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _downloadSingleSketch(CommissionSketch sk) async {
    if (sk.sketchImageUrl == null) return;
    await _ensureStoragePermission();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 Downloading sketch: ${sk.title}...'),
        duration: const Duration(seconds: 1),
      ),
    );
    try {
      final bytes = await CommissionService.downloadFile(
        'commission-sketches',
        sk.sketchImageUrl!,
      );
      if (bytes != null) {
        await ImageGallerySaverPlus.saveImage(
          bytes,
          quality: 100,
          name:
              'CaseFlow_Sketch_${sk.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ "${sk.title}" saved to gallery'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to download sketch'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _addNote() {
    final dk = Theme.of(context).brightness == Brightness.dark;
    final contentCtrl = TextEditingController();
    String selType = 'general';
    final types = [
      'general',
      'boundary',
      'encroachment',
      'construction',
      'measurement',
      'condition',
      'access',
    ];
    bool isListening = false;

    String? visitId = _activeVisitId;
    if (visitId == null && _visits.isNotEmpty) visitId = _visits.first.id;
    if (visitId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please check in first')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, ss) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Observation',
                          style: GoogleFonts.outfit(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: dk ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              types
                                  .map(
                                    (t) => ChoiceChip(
                                      label: Text(
                                        t,
                                        style: GoogleFonts.inter(fontSize: 11.sp),
                                      ),
                                      selected: selType == t,
                                      onSelected: (v) => ss(() => selType = t),
                                      selectedColor: AppTheme.accentViolet
                                          .withValues(alpha: 0.15),
                                    ),
                                  )
                                  .toList(),
                        ),
                        SizedBox(height: 16.h),
                        TextField(
                          controller: contentCtrl,
                          maxLines: 5,
                          autofocus: true,
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: dk ? Colors.white : const Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Write your observation...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        // Voice dictation button (Phase 2)
                        if (_speechAvailable)
                          SizedBox(
                            width: double.infinity,
                            height: 40.h,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                if (!isListening) {
                                  ss(() => isListening = true);
                                  await _speech.listen(
                                    onResult: (result) {
                                      ss(() {
                                        contentCtrl.text =
                                            '${contentCtrl.text} ${result.recognizedWords}'
                                                .trim();
                                        contentCtrl.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset: contentCtrl.text.length,
                                              ),
                                            );
                                      });
                                    },
                                    listenFor: const Duration(minutes: 2),
                                    pauseFor: const Duration(seconds: 8),
                                    localeId: 'en_IN',
                                  );
                                } else {
                                  await _speech.stop();
                                  ss(() => isListening = false);
                                }
                              },
                              icon: Icon(
                                isListening ? Icons.stop : Icons.mic,
                                size: 16,
                                color:
                                    isListening
                                        ? AppTheme.error
                                        : AppTheme.accentViolet,
                              ),
                              label: Text(
                                isListening ? 'Stop Dictation' : '🎤 Dictate',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    isListening
                                        ? AppTheme.error
                                        : AppTheme.accentViolet,
                                side: BorderSide(
                                  color:
                                      isListening
                                          ? AppTheme.error
                                          : AppTheme.accentViolet,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (contentCtrl.text.isEmpty) return;
                              await CommissionService.createObservation({
                                'commission_id': widget.commissionId,
                                'visit_id': visitId,
                                'observation_type': selType,
                                'content': contentCtrl.text,
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                            child: Text(
                              'Save Note',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _addExpense() {
    final dk = Theme.of(context).brightness == Brightness.dark;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    ExpenseType selType = ExpenseType.travel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, ss) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Expense',
                          style: GoogleFonts.outfit(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: dk ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              ExpenseType.values
                                  .map(
                                    (t) => ChoiceChip(
                                      label: Text(
                                        t.label,
                                        style: GoogleFonts.inter(fontSize: 11.sp),
                                      ),
                                      selected: selType == t,
                                      onSelected: (v) => ss(() => selType = t),
                                      selectedColor: AppTheme.warning
                                          .withValues(alpha: 0.15),
                                    ),
                                  )
                                  .toList(),
                        ),
                        SizedBox(height: 16.h),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.outfit(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: descCtrl,
                          style: GoogleFonts.inter(fontSize: 14.sp),
                          decoration: InputDecoration(
                            hintText: 'Description (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: () async {
                              final amt = double.tryParse(amountCtrl.text);
                              if (amt == null || amt <= 0) return;
                              await CommissionService.createExpense({
                                'commission_id': widget.commissionId,
                                'expense_type': selType.dbValue,
                                'amount': amt,
                                'description':
                                    descCtrl.text.isNotEmpty
                                        ? descCtrl.text
                                        : null,
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                            child: Text(
                              'Add Expense',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _goReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CommissionReportScreen(commissionId: widget.commissionId),
      ),
    );
  }

  void _goFieldVisit(String visitId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CommissionFieldVisitScreen(
              commissionId: widget.commissionId,
              visitId: visitId,
            ),
      ),
    );
    if (result == true) _load();
  }

  void _goWitness() async {
    String? visitId = _activeVisitId;
    if (visitId == null && _visits.isNotEmpty) visitId = _visits.first.id;
    if (visitId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please check in first')));
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CommissionWitnessScreen(
              commissionId: widget.commissionId,
              visitId: visitId!,
            ),
      ),
    );
    if (result == true) _load();
  }

  void _openSketchPad({CommissionSketch? sketch}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CommissionSketchScreen(
              commissionId: widget.commissionId,
              visitId: _activeVisitId,
              existingSketch: sketch,
            ),
      ),
    );
    if (result == true) _load();
  }

  void _editSketch(CommissionSketch sketch) => _openSketchPad(sketch: sketch);

  void _deleteSketch(CommissionSketch sketch) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Sketch?'),
            content: Text(
              'Are you sure you want to delete "${sketch.title}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await CommissionService.deleteSketch(sketch.id);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sketch deleted'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _handleAction(String action, Commission c) async {
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Delete Commission?'),
              content: const Text(
                'This will permanently delete all visits, evidence, notes, witnesses, sketches, and expenses.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
      );
      if (confirm == true) {
        await CommissionService.deleteCommission(c.id);
        ref.invalidate(commissionsProvider);
        if (mounted) Navigator.pop(context);
      }
    } else if (action == 'edit_status') {
      _showStatusPicker(c);
    } else if (action == 'generate_report') {
      _goReport();
    }
  }

  void _showStatusPicker(Commission c) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Text(
                'Change Status',
                style: GoogleFonts.outfit(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              ...CommissionStatus.values.map(
                (s) => ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 12,
                    color: s == c.status ? AppTheme.accent : Colors.grey,
                  ),
                  title: Text(s.label),
                  selected: s == c.status,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await CommissionService.updateCommission(c.id, {
                      'status': s.dbValue,
                    });
                    _load();
                  },
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
    );
  }
}

class _TimelineEvent {
  final DateTime date;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool done;
  _TimelineEvent({
    required this.date,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.done = false,
  });
}
