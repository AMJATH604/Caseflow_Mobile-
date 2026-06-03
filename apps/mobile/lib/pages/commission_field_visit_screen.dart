import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/commission_models.dart';
import '../services/commission_service.dart';
import '../theme/app_theme.dart';
import 'commission_witness_screen.dart';
import 'commission_sketch_screen.dart';

class CommissionFieldVisitScreen extends ConsumerStatefulWidget {
  final String commissionId;
  final String visitId;
  const CommissionFieldVisitScreen({
    super.key,
    required this.commissionId,
    required this.visitId,
  });
  @override
  ConsumerState<CommissionFieldVisitScreen> createState() =>
      _CommissionFieldVisitScreenState();
}

class _CommissionFieldVisitScreenState
    extends ConsumerState<CommissionFieldVisitScreen> {
  Commission? _commission;
  CommissionVisit? _visit;
  List<CommissionObservation> _observations = [];
  List<CommissionEvidence> _evidence = [];
  List<CommissionWitness> _witnesses = [];
  bool _loading = true;

  // Timer
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // GPS
  double? _lat, _lng;
  String _gpsStatus = 'Acquiring...';
  // ignore: unused_field — _lng is tracked alongside _lat for GPS pair

  // Speech
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // Activity feed
  final List<_ActivityItem> _feed = [];

  @override
  void initState() {
    super.initState();
    _load();
    _initSpeech();
    _startTimer();
    _fetchGPS();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    setState(() {});
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _fetchGPS() async {
    final pos = await CommissionService.getCurrentLocation();
    if (pos != null && mounted) {
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _gpsStatus =
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      });
    } else {
      setState(() => _gpsStatus = 'GPS unavailable');
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await CommissionService.fetchCommissionById(
        widget.commissionId,
      );
      final visits = await CommissionService.fetchVisits(widget.commissionId);
      final v = visits.firstWhere(
        (vi) => vi.id == widget.visitId,
        orElse: () => visits.first,
      );
      final o = await CommissionService.fetchVisitObservations(widget.visitId);
      final e = await CommissionService.fetchEvidence(widget.commissionId);
      final w = await CommissionService.fetchWitnesses(widget.commissionId);

      // Build activity feed from existing data
      _feed.clear();
      if (v.checkinTime != null)
        _feed.add(
          _ActivityItem(
            time: v.checkinTime!.toLocal(),
            icon: Icons.gps_fixed,
            text: 'Checked in',
            color: AppTheme.success,
          ),
        );
      for (final obs in o) {
        _feed.add(
          _ActivityItem(
            time: obs.createdAt.toLocal(),
            icon: Icons.mic,
            text: '[${obs.observationType}] ${obs.content}',
            color: AppTheme.accentViolet,
          ),
        );
      }
      for (final ev in e.where((x) => x.visitId == widget.visitId)) {
        _feed.add(
          _ActivityItem(
            time: ev.createdAt.toLocal(),
            icon: Icons.camera_alt,
            text: 'Photo #${ev.sequenceNumber}: ${ev.caption ?? "Evidence"}',
            color: AppTheme.info,
          ),
        );
      }
      for (final wi in w.where((x) => x.visitId == widget.visitId)) {
        _feed.add(
          _ActivityItem(
            time: wi.createdAt.toLocal(),
            icon: Icons.person,
            text: 'Witness: ${wi.witnessName}',
            color: AppTheme.warning,
          ),
        );
      }
      _feed.sort((a, b) => a.time.compareTo(b.time));

      // Calculate elapsed time
      if (v.checkinTime != null) {
        _elapsed = DateTime.now().difference(v.checkinTime!);
      }

      setState(() {
        _commission = c;
        _visit = v;
        _observations = o;
        _evidence = e;
        _witnesses = w;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // GPS + Timer Header
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                    child: Row(
                      children: [
                        // GPS Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          _lat != null
                                              ? AppTheme.success
                                              : AppTheme.warning,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_lat != null
                                                  ? AppTheme.success
                                                  : AppTheme.warning)
                                              .withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'GPS: $_gpsStatus',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _commission?.commissionType.label ??
                                    'Field Visit',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Timer
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.timer,
                                color: AppTheme.success,
                                size: 20,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDuration(_elapsed),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              'Field Visit',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFF0F172A),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),

          // Quick Action Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      _actionCard(
                        dk,
                        Icons.camera_alt,
                        'Photo',
                        AppTheme.info,
                        _capturePhoto,
                      ),
                      const SizedBox(width: 8),
                      _actionCard(
                        dk,
                        Icons.mic,
                        _isListening ? 'Stop' : 'Dictate',
                        _isListening ? AppTheme.error : AppTheme.accentViolet,
                        _speechAvailable ? _toggleDictation : () {},
                      ),
                      const SizedBox(width: 8),
                      _actionCard(
                        dk,
                        Icons.note_add,
                        'Note',
                        AppTheme.success,
                        _addQuickNote,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _actionCard(
                        dk,
                        Icons.person_add,
                        'Witness',
                        AppTheme.warning,
                        _addWitness,
                      ),
                      const SizedBox(width: 8),
                      _actionCard(
                        dk,
                        Icons.draw,
                        'Sketch',
                        const Color(0xFF8B5CF6),
                        _openSketchPad,
                      ),
                      const SizedBox(width: 8),
                      _actionCard(
                        dk,
                        Icons.warning_amber,
                        'Block',
                        AppTheme.error,
                        _reportObstruction,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Check Out button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _checkOut,
                      icon: const Icon(Icons.gps_not_fixed, size: 20),
                      label: Text(
                        'Check Out & End Visit',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF64748B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Listening indicator
          if (_isListening)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.error.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '🎤 Listening... Speak your observation clearly',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Activity Feed Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Activity Feed',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: dk ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_feed.length} events',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: dk ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Activity Feed List
          _feed.isEmpty
              ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 48,
                          color: dk ? Colors.white12 : Colors.black12,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start capturing evidence, notes, and witnesses',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: dk ? Colors.white38 : Colors.black38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) =>
                      _buildFeedItem(dk, _feed[i], i == _feed.length - 1),
                  childCount: _feed.length,
                ),
              ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _actionCard(
    bool dk,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => Expanded(
    child: Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildFeedItem(bool dk, _ActivityItem item, bool isLast) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 14, color: item.color),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('hh:mm a').format(item.time),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: dk ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.text,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: dk ? Colors.white70 : const Color(0xFF1E293B),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ─── Actions ──────────────────────────────────────────

  Future<void> _capturePhoto() async {
    // Explicitly request GPS permissions BEFORE opening camera
    bool gpsAvailable = false;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Turn on Location for GPS-tagged evidence'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
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
          content: Text('⚠️ GPS unavailable — photo saved without coordinates'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
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
        visitId: widget.visitId,
        fileBytes: bytes,
        fileName: name,
        caption: 'Photo #${_evidence.length + 1}',
      );
      setState(
        () => _feed.add(
          _ActivityItem(
            time: DateTime.now(),
            icon: Icons.camera_alt,
            text:
                'Photo #${_evidence.length + 1} captured${gpsAvailable ? ' (GPS ✓)' : ''}',
            color: AppTheme.info,
          ),
        ),
      );
      _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gpsAvailable
                  ? '📸 Photo captured with GPS'
                  : '📸 Photo captured (no GPS)',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 1),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
    }
  }

  void _toggleDictation() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) async {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            try {
              await CommissionService.createObservation({
                'commission_id': widget.commissionId,
                'visit_id': widget.visitId,
                'observation_type': 'general',
                'content': result.recognizedWords,
              });
              setState(
                () => _feed.add(
                  _ActivityItem(
                    time: DateTime.now(),
                    icon: Icons.mic,
                    text: result.recognizedWords,
                    color: AppTheme.accentViolet,
                  ),
                ),
              );
              _load();
            } catch (e) {
              debugPrint('Observation save error: $e');
            }
          }
        },
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 8),
        localeId: 'en_IN',
      );
    }
  }

  void _addQuickNote() {
    final ctrl = TextEditingController();
    final dk = Theme.of(context).brightness == Brightness.dark;
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Note',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: dk ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              types
                                  .map(
                                    (t) => ChoiceChip(
                                      label: Text(
                                        t,
                                        style: GoogleFonts.inter(fontSize: 11),
                                      ),
                                      selected: selType == t,
                                      onSelected: (v) => ss(() => selType = t),
                                      selectedColor: AppTheme.success
                                          .withValues(alpha: 0.15),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: ctrl,
                          maxLines: 4,
                          autofocus: true,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: dk ? Colors.white : const Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Write observation...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (ctrl.text.isEmpty) return;
                              await CommissionService.createObservation({
                                'commission_id': widget.commissionId,
                                'visit_id': widget.visitId,
                                'observation_type': selType,
                                'content': ctrl.text,
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Save',
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

  Future<void> _addWitness() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CommissionWitnessScreen(
              commissionId: widget.commissionId,
              visitId: widget.visitId,
            ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openSketchPad() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CommissionSketchScreen(
              commissionId: widget.commissionId,
              visitId: widget.visitId,
            ),
      ),
    );
    if (result == true) _load();
  }

  void _reportObstruction() {
    final ctrl = TextEditingController();
    final dk = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Text(
                        'Report Obstruction',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Describe the obstruction...\ne.g., "Respondent\'s men blocked entry to the property"',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (ctrl.text.isEmpty) return;
                        await CommissionService.reportObstruction(
                          widget.visitId,
                          ctrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(
                          () => _feed.add(
                            _ActivityItem(
                              time: DateTime.now(),
                              icon: Icons.warning_amber,
                              text: '⚠️ Obstruction: ${ctrl.text}',
                              color: AppTheme.error,
                            ),
                          ),
                        );
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('⚠️ Obstruction reported'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Report Obstruction',
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
    );
  }

  Future<void> _checkOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('End Field Visit?'),
            content: Text(
              'Duration: ${_formatDuration(_elapsed)}\nThis will record your checkout GPS and end the visit timer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Check Out',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    try {
      await CommissionService.checkOut(widget.visitId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Checked out! Duration: ${_formatDuration(_elapsed)}',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
    }
  }
}

class _ActivityItem {
  final DateTime time;
  final IconData icon;
  final String text;
  final Color color;
  _ActivityItem({
    required this.time,
    required this.icon,
    required this.text,
    required this.color,
  });
}
