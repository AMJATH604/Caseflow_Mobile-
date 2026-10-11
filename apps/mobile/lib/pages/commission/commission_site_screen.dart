import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../components/commission/cm_kit.dart';
import '../../models/commission_models.dart';
import '../../services/commission_service.dart';
import '../../theme/app_theme.dart';
import '../commission_sketch_screen.dart';
import '../commission_witness_screen.dart';
import 'commission_data.dart';
import 'commission_measure_screen.dart';

/// "At the site": a dark, full-screen mode for the inspection itself — big
/// buttons that work in sunlight and with one hand, everything tied to this
/// visit with its time and GPS point.
class CommissionSiteScreen extends ConsumerStatefulWidget {
  final String commissionId;
  final String visitId;
  const CommissionSiteScreen({super.key, required this.commissionId, required this.visitId});

  @override
  ConsumerState<CommissionSiteScreen> createState() => _SiteState();
}

class _SiteState extends ConsumerState<CommissionSiteScreen> {
  static const _bg = Color(0xFF0B1220);
  static const _panel = Color(0xFF111A2E);
  static const _edge = Color(0xFF1E293B);

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  double? _lat, _lng, _accuracy;
  bool _gpsTried = false;
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    _gps();
    _speech.initialize().then((ok) {
      if (mounted) setState(() => _speechReady = ok);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _gps() async {
    final p = await CommissionService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _gpsTried = true;
      _lat = p?.latitude;
      _lng = p?.longitude;
      _accuracy = p?.accuracy;
    });
  }

  void _refresh() => ref.invalidate(commissionBundleProvider(widget.commissionId));

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppTheme.error : null,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Photo ───────────────────────────────────────────────────
  Future<void> _photo(CommissionBundle b) async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (shot == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await shot.readAsBytes();
      final n = b.evidence.length + 1;
      await CommissionService.uploadEvidence(
        commissionId: widget.commissionId,
        visitId: widget.visitId,
        fileBytes: bytes,
        fileName: 'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg',
        caption: 'Photo $n',
      );
      _refresh();
      _toast(_lat != null ? 'Photo $n saved with GPS' : 'Photo $n saved — no GPS');
    } catch (e) {
      _toast('Photo not saved: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Voice note (dictation into an observation) ─────────────
  Future<void> _voice() async {
    if (!_speechReady) return _toast('Voice typing is not available on this phone.', error: true);
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'en_IN',
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 8),
      onResult: (r) async {
        if (!r.finalResult || r.recognizedWords.trim().isEmpty) return;
        if (mounted) setState(() => _listening = false);
        try {
          await CommissionService.createObservation({
            'commission_id': widget.commissionId,
            'visit_id': widget.visitId,
            'observation_type': 'general',
            'content': r.recognizedWords.trim(),
          });
          _refresh();
          _toast('Note saved from voice');
        } catch (e) {
          _toast('Note not saved: $e', error: true);
        }
      },
    );
  }

  // ── Typed note ──────────────────────────────────────────────
  Future<void> _note() async {
    final text = TextEditingController();
    var kind = 'general';
    const kinds = {
      'general': 'General',
      'boundary': 'Boundary',
      'encroachment': 'Encroachment',
      'construction': 'Construction',
      'condition': 'Condition',
      'possession': 'Possession',
      'access': 'Access',
    };
    final saved = await showCmSheet<bool>(
      context,
      title: 'Observation',
      builder: (ctx, ss) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in kinds.entries)
                ChoiceChip(label: Text(e.value), selected: kind == e.key, onSelected: (_) => ss(() => kind = e.key)),
            ],
          ),
          SizedBox(height: 10.h),
          CmField(text, 'What you saw', hint: 'East wall is a common wall, about 9 inches thick.', maxLines: 5),
          SizedBox(height: 16.h),
          CmButton('Save note', icon: Icons.check_rounded, onPressed: () async {
            if (text.text.trim().isEmpty) return;
            await CommissionService.createObservation({
              'commission_id': widget.commissionId,
              'visit_id': widget.visitId,
              'observation_type': kind,
              'content': text.text.trim(),
            });
            if (ctx.mounted) Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  // ── Who is present ──────────────────────────────────────────
  Future<void> _present(CommissionBundle b, CommissionVisit v) async {
    final here = {for (final p in b.parties) p.id: p.attended == true};
    final others = TextEditingController(text: _othersFrom(v.personsPresent, b.parties));
    final saved = await showCmSheet<bool>(
      context,
      title: 'Who is present',
      builder: (ctx, ss) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (b.parties.isEmpty)
            Text('Add the parties in Notice to parties to tick them here.', style: Cm.body(ctx))
          else
            for (final p in b.parties)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: here[p.id],
                onChanged: (x) => ss(() => here[p.id] = x ?? false),
                title: Text(p.name),
                subtitle: Text('${p.roleText}${p.advocate != null ? ' · ${p.advocate}' : ''}'),
              ),
          SizedBox(height: 8.h),
          CmField(others, 'Others present', hint: 'Revenue Inspector, chain man, neighbours', maxLines: 2),
          SizedBox(height: 16.h),
          CmButton('Save', icon: Icons.check_rounded, onPressed: () async {
            final names = <String>[
              for (final p in b.parties)
                if (here[p.id] == true) '${p.name} (${p.roleText}${p.advocate != null ? ', with ${p.advocate}' : ''})',
            ];
            final o = others.text.trim();
            final text = [if (names.isNotEmpty) names.join('; '), if (o.isNotEmpty) 'Others: $o'].join('. ');
            await CommissionService.updateVisit(v.id, {'persons_present': text.isEmpty ? null : text});
            for (final p in b.parties) {
              await CommissionService.saveParty(p.commissionId, {'attended': here[p.id]}, id: p.id);
            }
            if (ctx.mounted) Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (saved == true) _refresh();
  }

  String _othersFrom(String? present, List<CommissionParty> parties) {
    if (present == null) return '';
    final i = present.indexOf('Others: ');
    return i < 0 ? '' : present.substring(i + 8).trim();
  }

  // ── Obstruction / end ───────────────────────────────────────
  Future<void> _obstruction() async {
    final text = TextEditingController();
    final saved = await showCmSheet<bool>(
      context,
      title: 'Report obstruction',
      builder: (ctx, ss) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This ends the visit and records it as obstructed. Note who obstructed and how.', style: Cm.body(ctx)),
          SizedBox(height: 10.h),
          CmField(text, 'What happened', hint: 'The 2nd defendant locked the gate and refused entry.', maxLines: 4),
          SizedBox(height: 16.h),
          CmButton('Record obstruction', icon: Icons.report_rounded, color: AppTheme.error, onPressed: () async {
            if (text.text.trim().isEmpty) return;
            await CommissionService.reportObstruction(widget.visitId, text.text.trim());
            if (ctx.mounted) Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (saved == true && mounted) {
      _refresh();
      Navigator.of(context).pop();
    }
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this visit?'),
        content: Text('Time on site: ${_fmt(_elapsed)}. Your check-out time and GPS point are recorded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep recording')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Check out')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CommissionService.checkOut(widget.visitId);
      _refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('Could not check out: $e', error: true);
    }
  }

  String _fmt(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(commissionBundleProvider(widget.commissionId));
    final b = async.valueOrNull;
    CommissionVisit? v;
    if (b != null) {
      for (final x in b.visits) {
        if (x.id == widget.visitId) v = x;
      }
    }
    final visitNo = b == null || v == null ? null : b.visits.reversed.toList().indexWhere((x) => x.id == v!.id) + 1;
    final photos = b?.evidence.where((e) => e.visitId == widget.visitId).length ?? 0;
    final notes = b?.observations.where((o) => o.visitId == widget.visitId).length ?? 0;
    final wits = b?.witnesses.where((w) => w.visitId == widget.visitId).length ?? 0;
    final meas = b?.measurements.where((m) => m.visitId == widget.visitId).length ?? 0;
    final present = b?.parties.where((p) => p.attended == true).toList() ?? const <CommissionParty>[];
    final absent = b?.parties.where((p) => p.attended == false).toList() ?? const <CommissionParty>[];

    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to the commission',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(999)),
                        child: Text('● AT SITE', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      Expanded(
                        child: Text(
                          '${visitNo != null && visitNo > 0 ? 'Visit $visitNo · ' : ''}${_fmt(_elapsed)}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: _end,
                        child: Text('Check out', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFFF87171))),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                    children: [
                      _panelBox(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.my_location_rounded, size: 18.r, color: _lat != null ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    _lat != null
                                        ? 'GPS ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}${_accuracy != null ? ' · ±${_accuracy!.round()} m' : ''}'
                                        : (_gpsTried ? 'GPS unavailable — turn on location' : 'Finding your location…'),
                                    style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFFCBD5E1)),
                                  ),
                                ),
                                IconButton(tooltip: 'Refresh GPS', onPressed: _gps, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8))),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            InkWell(
                              onTap: b == null || v == null ? null : () => _present(b, v!),
                              borderRadius: BorderRadius.circular(10.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 4.h),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    for (final p in present) _chip('${p.name} ✓', const Color(0xFF14532D), const Color(0xFFBBF7D0)),
                                    for (final p in absent) _chip('${p.name} absent', const Color(0xFF7F1D1D), const Color(0xFFFECACA)),
                                    _chip(present.isEmpty && absent.isEmpty ? 'Who is present?' : 'Edit present', _edge, const Color(0xFFCBD5E1)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10.h,
                        crossAxisSpacing: 10.w,
                        childAspectRatio: 1.55,
                        children: [
                          _big('Photo', Icons.photo_camera_rounded, const Color(0xFF2563EB), b == null || _busy ? null : () => _photo(b)),
                          _big('Measure', Icons.square_foot_rounded, const Color(0xFF0F766E),
                              () => _open(CommissionMeasureScreen(commissionId: widget.commissionId, visitId: widget.visitId))),
                          _big('Witness', Icons.record_voice_over_rounded, const Color(0xFF7C3AED),
                              () => _open(CommissionWitnessScreen(commissionId: widget.commissionId, visitId: widget.visitId))),
                          _big(_listening ? 'Listening… tap to stop' : 'Voice note', _listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                              const Color(0xFFB45309), _voice),
                          _big('Sketch', Icons.draw_rounded, const Color(0xFFBE185D),
                              () => _open(CommissionSketchScreen(commissionId: widget.commissionId, visitId: widget.visitId))),
                          _big('Note', Icons.edit_note_rounded, const Color(0xFF334155), _note),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _panelBox(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('THIS VISIT', style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: const Color(0xFF94A3B8))),
                            SizedBox(height: 6.h),
                            Text('$photos photos · $meas measurements · $wits ${wits == 1 ? 'witness' : 'witnesses'} · $notes notes',
                                style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFFE2E8F0))),
                          ],
                        ),
                      ),
                      if (_busy) ...[
                        SizedBox(height: 12.h),
                        const LinearProgressIndicator(minHeight: 3),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                  child: CmButton('Report obstruction', icon: Icons.report_gmailerrorred_rounded, color: const Color(0xFFDC2626), onPressed: _obstruction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelBox(Widget child) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: _edge)),
        child: child,
      );

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _big(String label, IconData icon, Color color, VoidCallback? onTap) => Material(
        color: onTap == null ? color.withValues(alpha: 0.4) : color,
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 30.r),
                SizedBox(height: 6.h),
                Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      );
}
