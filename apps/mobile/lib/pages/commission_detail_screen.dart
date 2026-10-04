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
import '../services/back_interceptors.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/commission_models.dart';
import '../services/commission_service.dart';
import '../services/storage_links.dart';
import '../theme/app_theme.dart';
import 'commission_witness_screen.dart';
import 'commission_sketch_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../components/commission/commission_evidence_tab.dart';
import '../components/commission/commission_sketches_tab.dart';
import '../components/commission/commission_witnesses_tab.dart';

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
    BackInterceptors.add(_handleBackPress);
    _tabs = TabController(length: 6, vsync: this);
    _load();
    _initSpeech();
  }

  /// Back closes an open field visit before leaving the commission.
  bool _handleBackPress() {
    if (_activeVisitId == null) return false;
    setState(() => _activeVisitId = null);
    return true;
  }

  @override
  void dispose() {
    BackInterceptors.remove(_handleBackPress);
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
      // All eight lists at once rather than one after another; a list that
      // fails stays empty instead of reporting "Commission not found".
      final id = widget.commissionId;
      final cF = CommissionService.fetchCommissionById(id);
      final vF = _orEmpty(CommissionService.fetchVisits(id));
      final oF = _orEmpty(CommissionService.fetchObservations(id));
      final eF = _orEmpty(CommissionService.fetchEvidence(id));
      final wF = _orEmpty(CommissionService.fetchWitnesses(id));
      final skF = _orEmpty(CommissionService.fetchSketches(id));
      final docsF = _orEmpty(CommissionService.fetchCommissionDocuments(id));
      final c = await cF;
      final v = await vF;
      final o = await oF;
      final e = await eF;
      final w = await wF;
      final sk = await skF;
      final docs = await docsF;
      if (!mounted) return;
      final active =
          v.where((vi) => vi.visitStatus == VisitStatus.checkedIn).toList();
      setState(() {
        _commission = c;
        _visits = v;
        _observations = o;
        _evidence = e;
        _witnesses = w;
        _sketches = sk;
        _documents = docs;
        _activeVisitId = active.isNotEmpty ? active.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static Future<List<T>> _orEmpty<T>(Future<List<T>> f) async {
    try {
      return await f;
    } catch (e) {
      debugPrint('Commission detail: a list failed to load: $e');
      return <T>[];
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'The record',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
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
            const Tab(text: 'By visit'),
            Tab(text: 'Photos (${_evidence.length})'),
            Tab(text: 'Notes (${_observations.length})'),
            Tab(text: 'Witnesses (${_witnesses.length})'),
            Tab(text: 'Sketches (${_sketches.length})'),
            Tab(text: 'Documents (${_documents.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _byVisitTab(dk),
          _evidenceTab(dk),
          _notesTab(dk),
          _witnessesTab(dk),
          _sketchesTab(dk),
          _documentsTab(dk),
        ],
      ),
    );
  }

  // ─── BY VISIT ────────────────────────────────────────────
  /// Everything recorded, grouped under the visit it belongs to, newest
  /// visit first — the order the report's memo of inspection follows.
  Widget _byVisitTab(bool dk) {
    if (_visits.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(28.r),
          child: Text(
            'No visits yet. Start a site visit from the commission page — everything you record there appears here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: dk ? Colors.white54 : Colors.black45),
          ),
        ),
      );
    }
    final fmtT = DateFormat('hh:mm a');
    final fmtD = DateFormat('dd MMM yyyy');
    final n = _visits.length;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 40.h),
      itemCount: n,
      itemBuilder: (_, i) {
        final v = _visits[i];
        final items = <(DateTime, IconData, Color, String, String)>[
          for (final o in _observations.where((x) => x.visitId == v.id))
            (o.createdAt, Icons.notes_rounded, const Color(0xFF334155),
                o.observationType == 'general' ? 'Observation' : 'Observation · ${o.observationType}', o.content),
          for (final e in _evidence.where((x) => x.visitId == v.id))
            (e.createdAt, Icons.photo_camera_rounded, const Color(0xFF1D4ED8), 'Photo ${e.sequenceNumber}',
                [if (e.caption != null) e.caption!, e.latitude != null ? 'GPS ${e.locationText}' : 'No GPS'].join(' · ')),
          for (final w in _witnesses.where((x) => x.visitId == v.id))
            (w.createdAt, Icons.record_voice_over_rounded, const Color(0xFF6D28D9), 'Witness: ${w.witnessName}',
                [if (w.displayIdNumber != null) '${w.idLabel} ${w.displayIdNumber}', if (w.signatureUrl != null) 'signed'].join(' · ')),
          for (final s in _sketches.where((x) => x.visitId == v.id))
            (s.createdAt, Icons.draw_rounded, const Color(0xFFBE185D), 'Sketch: ${s.title}', s.sketchTypeLabel),
        ]..sort((a, b) => a.$1.compareTo(b.$1));
        return Container(
          margin: EdgeInsets.only(bottom: 14.h),
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: dk ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: dk ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Visit ${n - i}', style: GoogleFonts.outfit(fontSize: 17.sp, fontWeight: FontWeight.w700, color: dk ? Colors.white : const Color(0xFF0F172A))),
                  SizedBox(width: 8.w),
                  Text(fmtD.format(v.visitDate), style: GoogleFonts.inter(fontSize: 12.sp, color: dk ? Colors.white54 : Colors.black45)),
                  const Spacer(),
                  Text(v.visitStatus.label,
                      style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w700,
                          color: v.visitStatus == VisitStatus.obstructed ? AppTheme.error : const Color(0xFF16A34A))),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                [
                  if (v.checkinTime != null) 'In ${fmtT.format(v.checkinTime!.toLocal())}',
                  if (v.checkoutTime != null) 'out ${fmtT.format(v.checkoutTime!.toLocal())}',
                  if (v.durationText != null) '(${v.durationText})',
                  if (v.checkinLat != null && !(v.checkinLat == 0 && v.checkinLng == 0))
                    'GPS ${v.checkinLat!.toStringAsFixed(5)}, ${v.checkinLng!.toStringAsFixed(5)}',
                ].join(' · '),
                style: GoogleFonts.inter(fontSize: 12.sp, color: dk ? Colors.white60 : Colors.black54),
              ),
              if (v.personsPresent != null) ...[
                SizedBox(height: 4.h),
                Text('Present: ${v.personsPresent}', style: GoogleFonts.inter(fontSize: 12.sp, color: dk ? Colors.white70 : Colors.black87)),
              ],
              if (v.obstructionDetails != null) ...[
                SizedBox(height: 4.h),
                Text('Obstruction: ${v.obstructionDetails}', style: GoogleFonts.inter(fontSize: 12.sp, color: AppTheme.error)),
              ],
              if (items.isNotEmpty) Divider(height: 18.h, color: dk ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9)),
              for (final it in items)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(7.r),
                        decoration: BoxDecoration(color: it.$3.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9.r)),
                        child: Icon(it.$2, size: 16.r, color: it.$3),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(it.$4, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: dk ? Colors.white : const Color(0xFF0F172A)))),
                                Text(fmtT.format(it.$1.toLocal()), style: GoogleFonts.inter(fontSize: 11.sp, color: dk ? Colors.white38 : Colors.black38)),
                              ],
                            ),
                            if (it.$5.isNotEmpty)
                              Text(it.$5, style: GoogleFonts.inter(fontSize: 12.sp, color: dk ? Colors.white60 : Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (items.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Text('Nothing recorded on this visit.', style: GoogleFonts.inter(fontSize: 12.sp, color: dk ? Colors.white38 : Colors.black38)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _evidenceTab(bool dk) => CommissionEvidenceTab(
    evidence: _evidence,
    isDark: dk,
    onCaptureEvidence: _captureEvidence,
    onDownloadAll: _downloadAllPhotos,
    onDownloadSingle: _downloadSinglePhoto,
  );

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
  Widget _witnessesTab(bool dk) => CommissionWitnessesTab(
    witnesses: _witnesses,
    isDark: dk,
    currentlyPlayingId: _currentlyPlayingId,
    onRecordWitness: _goWitness,
    onPlayAudio: _playWitnessAudio,
    onDeleteWitness: (w) async {
      await CommissionService.deleteWitness(w.id);
      _load();
    },
  );

  // ─── SKETCHES TAB (Phase 2) ──────────────────────────────
  Widget _sketchesTab(bool dk) => CommissionSketchesTab(
    sketches: _sketches,
    isDark: dk,
    onCreateSketch: () => _openSketchPad(),
    onEditSketch: _editSketch,
    onDeleteSketch: _deleteSketch,
    onDownloadSketch: _downloadSingleSketch,
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
                          final uri = Uri.parse(
                            await StorageLinks.resolve(url),
                          );
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
      await _audioPlayer.play(
        UrlSource(await StorageLinks.resolve(w.audioUrl!)),
      );
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
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
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

}
