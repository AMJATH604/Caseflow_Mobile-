import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/commission_models.dart';
import '../services/commission_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CommissionReportScreen extends ConsumerStatefulWidget {
  final String commissionId;
  const CommissionReportScreen({super.key, required this.commissionId});
  @override
  ConsumerState<CommissionReportScreen> createState() =>
      _CommissionReportScreenState();
}

class _CommissionReportScreenState
    extends ConsumerState<CommissionReportScreen> {
  Commission? _commission;
  List<CommissionVisit> _visits = [];
  List<CommissionObservation> _observations = [];
  List<CommissionEvidence> _evidence = [];
  List<CommissionExpense> _expenses = [];
  List<CommissionWitness> _witnesses = [];
  List<CommissionSketch> _sketches = [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
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
      setState(() {
        _commission = c;
        _visits = v;
        _observations = o;
        _evidence = e;
        _expenses = ex;
        _witnesses = w;
        _sketches = sk;
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
          'Generate Report',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.r),
        children: [
          // Template selection
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Template',
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _getTemplateDescription(c.commissionType),
                  style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white70),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    c.commissionType.label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Data summary cards
          _summaryCard(
            dk,
            Icons.location_on,
            'Site Visits',
            '${_visits.length} recorded',
            AppTheme.success,
          ),
          _summaryCard(
            dk,
            Icons.camera_alt,
            'Evidence',
            '${_evidence.length} photos',
            AppTheme.info,
          ),
          _summaryCard(
            dk,
            Icons.note_alt,
            'Observations',
            '${_observations.length} notes',
            AppTheme.accentViolet,
          ),
          _summaryCard(
            dk,
            Icons.person,
            'Witnesses',
            '${_witnesses.length} recorded',
            AppTheme.warning,
          ),
          _summaryCard(
            dk,
            Icons.draw,
            'Sketches',
            '${_sketches.length} drawings',
            const Color(0xFF8B5CF6),
          ),
          _summaryCard(
            dk,
            Icons.receipt,
            'Expenses',
            '₹${_expenses.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(0)}',
            AppTheme.error,
          ),
          SizedBox(height: 24.h),

          // Generate button
          SizedBox(
            height: 54.h,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generateReport,
              icon:
                  _generating
                      ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.picture_as_pdf),
              label: Text(
                _generating ? 'Generating...' : 'Generate & Preview PDF',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.sp,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 60.h),
        ],
      ),
    );
  }

  Widget _summaryCard(
    bool dk,
    IconData icon,
    String title,
    String value,
    Color color,
  ) => Container(
    margin: EdgeInsets.only(bottom: 8.h),
    padding: EdgeInsets.all(14.r),
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
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: dk ? Colors.white70 : Colors.black54,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: dk ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    ),
  );

  String _getTemplateDescription(CommissionType type) {
    switch (type) {
      case CommissionType.localInvestigation:
        return 'Property condition, encroachments, witness statements, boundary verification';
      case CommissionType.partition:
        return 'Room-wise measurements, proposed division, valuation details';
      case CommissionType.survey:
        return 'Survey marks, boundary coordinates, GPS waypoints, demarcation';
      case CommissionType.recordingEvidence:
        return 'Witness depositions, documentary evidence, cross-examination notes';
      case CommissionType.sale:
        return 'Valuation, bidding records, property condition, market analysis';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ═══  PDF GENERATION — FORMAL COURT DOCUMENT  ═════════════════
  // ═══════════════════════════════════════════════════════════════

  Future<void> _generateReport() async {
    setState(() => _generating = true);
    try {
      final c = _commission!;
      final pdf = pw.Document();
      final fmt = DateFormat('dd-MM-yyyy');
      final fmtLong = DateFormat('dd MMM yyyy');

      // ── Pre-download all images for embedding ──
      final photoData = <String, Uint8List>{};
      final signatureData = <String, Uint8List>{};
      final sketchData = <String, Uint8List>{};

      for (final e in _evidence) {
        final bytes = await CommissionService.downloadFile(
          'commission-evidence',
          e.fileUrl,
        );
        if (bytes != null) photoData[e.id] = bytes;
            }
      for (final w in _witnesses) {
        if (w.signatureUrl != null) {
          final bytes = await CommissionService.downloadFile(
            'commission-witnesses',
            w.signatureUrl!,
          );
          if (bytes != null) signatureData[w.id] = bytes;
        }
      }
      for (final sk in _sketches) {
        if (sk.sketchImageUrl != null) {
          final bytes = await CommissionService.downloadFile(
            'commission-sketches',
            sk.sketchImageUrl!,
          );
          if (bytes != null) sketchData[sk.id] = bytes;
        }
      }

      // ── Define text styles ──
      final titleStyle = pw.TextStyle(
        fontSize: 15.sp,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 1.2,
      );
      final subtitleStyle = pw.TextStyle(
        fontSize: 10.sp,
        fontStyle: pw.FontStyle.italic,
        color: PdfColors.grey700,
      );
      final sectionHeaderStyle = pw.TextStyle(
        fontSize: 11.sp,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.5,
      );
      final labelStyle = pw.TextStyle(
        fontSize: 10.sp,
        fontWeight: pw.FontWeight.bold,
      );
      valueStyle = pw.TextStyle(fontSize: 10.sp);
      bodyStyle = pw.TextStyle(fontSize: 10.sp);
      final smallBold = pw.TextStyle(
        fontSize: 9.sp,
        fontWeight: pw.FontWeight.bold,
      );
      smallStyle = pw.TextStyle(fontSize: 9.sp);

      // ── Track section numbering ──
      const int sectionNum = 0;

      // ── Build the document ──

      // PAGE 1: TITLE & COVER
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 50.w, vertical: 40.h),
          build:
              (ctx) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(height: 20.h),
                  pw.Text(
                    'ADVOCATE COMMISSIONER\'S REPORT',
                    style: titleStyle.copyWith(fontSize: 18.sp),
                  ),
                  pw.SizedBox(height: 10.h),
                  pw.Text(
                    'REPORT OF THE COMMISSIONER APPOINTED BY THE COURT',
                    style: subtitleStyle.copyWith(fontSize: 11.sp),
                  ),
                  pw.SizedBox(height: 40.h),

                  // Court Caption
                  pw.Container(
                    padding: pw.EdgeInsets.all(16.r),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1.5.w),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'IN THE COURT OF',
                          style: pw.TextStyle(fontSize: 10.sp),
                        ),
                        pw.SizedBox(height: 4.h),
                        pw.Text(
                          (c.courtName ?? 'THE HONOURABLE COURT').toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 12.sp,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 20.h),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                'Case No: ${c.caseNumberRef ?? 'N/A'}',
                                style: labelStyle,
                              ),
                            ),
                            pw.Text(
                              'Date: ${fmt.format(DateTime.now())}',
                              style: labelStyle,
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 12.h),
                        pw.Divider(),
                        pw.SizedBox(height: 12.h),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                c.partyPetitioner ?? 'Petitioner',
                                style: pw.TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Text(
                              '... Petitioner(s)',
                              style: pw.TextStyle(fontSize: 10.sp),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8.h),
                        pw.Text(
                          'VERSUS',
                          style: pw.TextStyle(
                            fontSize: 10.sp,
                            fontWeight: pw.FontWeight.bold,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.SizedBox(height: 8.h),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                c.partyRespondent ?? 'Respondent',
                                style: pw.TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Text(
                              '... Respondent(s)',
                              style: pw.TextStyle(fontSize: 10.sp),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('SUBMITTED BY:', style: smallBold),
                      pw.SizedBox(height: 5.h),
                      pw.Text(
                        'ADVOCATE COMMISSIONER',
                        style: pw.TextStyle(
                          fontSize: 12.sp,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2.h),
                      pw.Text(
                        'CaseFlow Professional Legal Services',
                        style: pw.TextStyle(fontSize: 10.sp),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 40.h),
                ],
              ),
        ),
      );

      // PAGE 2: INDEX / CONTENTS
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 50.w, vertical: 40.h),
          build:
              (ctx) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'INDEX / TABLE OF CONTENTS',
                      style: sectionHeaderStyle,
                    ),
                  ),
                  pw.SizedBox(height: 20.h),
                  _indexRow('1.', 'Commission Details & Background', '1'),
                  _indexRow('2.', 'Memo of Inspection / Site Visits', '2'),
                  _indexRow('3.', 'Observations & Findings', '3'),
                  _indexRow('4.', 'Certification & Oath', '4'),
                  pw.SizedBox(height: 20.h),
                  pw.Text('ANNEXURES', style: smallBold),
                  pw.SizedBox(height: 10.h),
                  if (_evidence.isNotEmpty)
                    _indexRow('A', 'Photographic Evidence (Annexure-A)', '5'),
                  if (_sketches.isNotEmpty)
                    _indexRow('B', 'Drawings & Sketches (Annexure-B)', '6'),
                  if (_witnesses.isNotEmpty)
                    _indexRow('C', 'Witness Statements (Annexure-C)', '7'),
                  if (_expenses.isNotEmpty)
                    _indexRow('D', 'Memo of Expenses (Annexure-D)', '8'),
                ],
              ),
        ),
      );

      // PAGE 3+: MAIN REPORT BODY (continuous flow — all sections + annexures)
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 50.w, vertical: 40.h),
          header:
              (ctx) => pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Advocate Commissioner Report | ${c.caseNumberRef ?? ""}',
                  style: pw.TextStyle(
                    fontSize: 8.sp,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
          footer:
              (ctx) => pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Page ${ctx.pageNumber}',
                  style: pw.TextStyle(
                    fontSize: 8.sp,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
          build:
              (ctx) => [
                // ─── SECTION 1: COMMISSION DETAILS ─────────────────
                _courtSectionHeader(
                  '1. COMMISSION DETAILS & BACKGROUND',
                  sectionHeaderStyle,
                ),
                pw.Text(
                  'The undersigned was appointed as Advocate Commissioner by the Honourable Court vide order dated ${c.warrantDate != null ? fmt.format(c.warrantDate!) : "[Date]"} to carry out the commission for ${c.commissionType.label}.',
                  style: bodyStyle,
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 10.h),
                _courtLabelValue(
                  'Commission Type:',
                  c.commissionType.label,
                  labelStyle,
                  valueStyle,
                ),
                _courtLabelValue(
                  'Property Desc:',
                  c.propertyDescription ?? 'As per warrant',
                  labelStyle,
                  valueStyle,
                ),
                _courtLabelValue(
                  'Survey No:',
                  c.surveyNumber ?? 'N/A',
                  labelStyle,
                  valueStyle,
                ),
                _courtLabelValue(
                  'Location:',
                  c.locationSummary,
                  labelStyle,
                  valueStyle,
                ),
                if (c.scopeOfWork != null) ...[
                  pw.SizedBox(height: 12.h),
                  pw.Text('Scope of Work:', style: labelStyle),
                  pw.SizedBox(height: 4.h),
                  pw.Text(
                    c.scopeOfWork!,
                    style: bodyStyle,
                    textAlign: pw.TextAlign.justify,
                  ),
                ],

                pw.SizedBox(height: 20.h),

                // ─── SECTION 2: MEMO OF INSPECTION ─────────────────
                _courtSectionHeader(
                  '2. MEMO OF INSPECTION / SITE VISITS',
                  sectionHeaderStyle,
                ),
                if (_visits.isEmpty)
                  pw.Text(
                    'No site visits were recorded for this commission.',
                    style: bodyStyle,
                  ),
                ..._visits.asMap().entries.map((entry) {
                  final v = entry.value;
                  return pw.Container(
                    margin: pw.EdgeInsets.only(bottom: 12.h),
                    padding: pw.EdgeInsets.all(8.r),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        width: 0.3.w,
                        color: PdfColors.grey400,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '2.${entry.key + 1}. SITE VISIT - ${fmt.format(v.visitDate)}',
                          style: smallBold,
                        ),
                        pw.SizedBox(height: 4.h),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: _miniLabelVal(
                                'Time:',
                                v.checkinTime != null
                                    ? DateFormat(
                                      'hh:mm a',
                                    ).format(v.checkinTime!.toLocal())
                                    : 'N/A',
                              ),
                            ),
                            pw.Expanded(
                              child: _miniLabelVal(
                                'Status:',
                                v.visitStatus.label,
                              ),
                            ),
                          ],
                        ),
                        _miniLabelVal(
                          'Location:',
                          v.checkinAddress ?? 'Verified via GPS',
                        ),
                        _miniLabelVal(
                          'Coordinates:',
                          '${v.checkinLat?.toStringAsFixed(6)}, ${v.checkinLng?.toStringAsFixed(6)}',
                        ),
                        if (v.personsPresent != null)
                          _miniLabelVal('Present:', v.personsPresent!),
                        if (v.obstructionDetails != null) ...[
                          pw.SizedBox(height: 4.h),
                          pw.Text(
                            'OBSTRUCTION ENCOUNTERED:',
                            style: pw.TextStyle(
                              fontSize: 8.sp,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                            ),
                          ),
                          pw.Text(
                            v.obstructionDetails!,
                            style: pw.TextStyle(
                              fontSize: 9.sp,
                              color: PdfColors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 20.h),

                // ─── SECTION 3: OBSERVATIONS & FINDINGS ────────────
                _courtSectionHeader(
                  '3. OBSERVATIONS & FINDINGS',
                  sectionHeaderStyle,
                ),
                if (_observations.isEmpty)
                  pw.Text(
                    'No specific observations were recorded.',
                    style: bodyStyle,
                  ),
                ..._observations.asMap().entries.map((entry) {
                  final o = entry.value;
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 8.h),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('3.${entry.key + 1}. ', style: labelStyle),
                        pw.Expanded(
                          child: pw.Text(
                            '[${o.observationType.toUpperCase()}] ${o.content}',
                            style: bodyStyle,
                            textAlign: pw.TextAlign.justify,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 20.h),

                // ─── ANNEXURE A: PHOTOGRAPHIC EVIDENCE (continuous) ─
                if (_evidence.isNotEmpty) ...[
                  _courtSectionHeader(
                    'ANNEXURE - A: PHOTOGRAPHIC EVIDENCE',
                    sectionHeaderStyle,
                  ),
                  pw.SizedBox(height: 10.h),
                  pw.Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children:
                        _evidence.map((e) {
                          return pw.Container(
                            width: 230.w,
                            padding: pw.EdgeInsets.all(5.r),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                width: 0.5.w,
                                color: PdfColors.grey300,
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                if (photoData.containsKey(e.id))
                                  pw.Image(
                                    pw.MemoryImage(photoData[e.id]!),
                                    height: 160.h,
                                    width: 220.w,
                                    fit: pw.BoxFit.cover,
                                  ),
                                pw.SizedBox(height: 5.h),
                                pw.Text(
                                  'PHOTO #${e.sequenceNumber}',
                                  style: smallBold,
                                ),
                                pw.Text(
                                  e.caption ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 8.sp),
                                  maxLines: 2,
                                ),
                                pw.Text(
                                  'GPS: ${e.locationText}',
                                  style: pw.TextStyle(
                                    fontSize: 7.sp,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                  pw.SizedBox(height: 20.h),
                ],

                // ─── ANNEXURE B: DRAWINGS & SKETCHES (continuous) ───
                if (_sketches.isNotEmpty) ...[
                  _courtSectionHeader(
                    'ANNEXURE - B: DRAWINGS & SKETCHES',
                    sectionHeaderStyle,
                  ),
                  pw.SizedBox(height: 10.h),
                  ..._sketches.map(
                    (sk) => pw.Container(
                      margin: pw.EdgeInsets.only(bottom: 30.h),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${sk.title} (${sk.sketchTypeLabel})',
                            style: labelStyle,
                          ),
                          pw.SizedBox(height: 5.h),
                          if (sketchData.containsKey(sk.id))
                            pw.Center(
                              child: pw.Image(
                                pw.MemoryImage(sketchData[sk.id]!),
                                height: 350.h,
                              ),
                            ),
                          pw.SizedBox(height: 5.h),
                          pw.Text(
                            'Annotations: ${sk.annotations.length} key points identified',
                            style: pw.TextStyle(fontSize: 8.sp),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20.h),
                ],

                // ─── ANNEXURE C: WITNESS STATEMENTS (continuous) ────
                if (_witnesses.isNotEmpty) ...[
                  _courtSectionHeader(
                    'ANNEXURE - C: WITNESS STATEMENTS',
                    sectionHeaderStyle,
                  ),
                  pw.SizedBox(height: 10.h),
                  ..._witnesses.map(
                    (w) => pw.Container(
                      margin: pw.EdgeInsets.only(bottom: 20.h),
                      padding: pw.EdgeInsets.all(12.r),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 0.5.w),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'WITNESS: ${w.witnessName}',
                                style: labelStyle,
                              ),
                              pw.Text(
                                'ID: ${w.idLabel} ${w.idNumber ?? ""}',
                                style: smallStyle,
                              ),
                            ],
                          ),
                          pw.Divider(thickness: 0.5),
                          pw.SizedBox(height: 8.h),
                          pw.Text(
                            w.statementText ?? 'No statement recorded',
                            style: bodyStyle,
                            textAlign: pw.TextAlign.justify,
                          ),
                          pw.SizedBox(height: 15.h),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Column(
                                children: [
                                  if (signatureData.containsKey(w.id))
                                    pw.Image(
                                      pw.MemoryImage(signatureData[w.id]!),
                                      height: 50.h,
                                    ),
                                  pw.Container(
                                    width: 120.w,
                                    height: 0.5.h,
                                    color: PdfColors.black,
                                  ),
                                  pw.Text(
                                    'Signature of Witness',
                                    style: pw.TextStyle(fontSize: 8.sp),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20.h),
                ],

                // ─── ANNEXURE D: MEMO OF EXPENSES (continuous) ──────
                if (_expenses.isNotEmpty) ...[
                  _courtSectionHeader(
                    'ANNEXURE - D: MEMO OF EXPENSES',
                    sectionHeaderStyle,
                  ),
                  pw.SizedBox(height: 10.h),
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'Sl No',
                      'Expense Type',
                      'Description',
                      'Amount (INR)',
                    ],
                    data: [
                      ..._expenses.asMap().entries.map(
                        (entry) => [
                          (entry.key + 1).toString(),
                          entry.value.expenseType.label,
                          entry.value.description ?? '-',
                          entry.value.amount.toStringAsFixed(2),
                        ],
                      ),
                      [
                        '',
                        '',
                        'TOTAL:',
                        'INR ${_expenses.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(2)}',
                      ],
                    ],
                    cellStyle: pw.TextStyle(fontSize: 10.sp),
                    headerStyle: pw.TextStyle(
                      fontSize: 10.sp,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    border: pw.TableBorder.all(width: 0.5.w),
                  ),
                  pw.SizedBox(height: 20.h),
                ],

                // ─── SECTION 4: CERTIFICATION & OATH (at the end) ──
                _courtSectionHeader('CERTIFICATION & OATH', sectionHeaderStyle),
                pw.Text(
                  'I, Advocate Commissioner, do hereby solemnly affirm and state as follows:',
                  style: labelStyle,
                ),
                pw.SizedBox(height: 10.h),
                pw.Text(
                  '1. Accuracy: I certify that the inspection was conducted in a fair and transparent manner, providing equal opportunity to all parties present.',
                  style: bodyStyle,
                ),
                pw.SizedBox(height: 6.h),
                pw.Text(
                  '2. Neutrality: That I have no interest, direct or indirect, in the subject matter or in the parties to the litigation.',
                  style: bodyStyle,
                ),
                pw.SizedBox(height: 6.h),
                pw.Text(
                  '3. Verified Data: That the photographic evidence, sketches, and statements attached herewith as Annexures were captured/recorded by me or under my direct supervision during the execution of the commission.',
                  style: bodyStyle,
                ),
                pw.SizedBox(height: 6.h),
                pw.Text(
                  '4. Integrity: That this report is a true and faithful representation of the facts as observed at the site.',
                  style: bodyStyle,
                ),

                pw.SizedBox(height: 50.h),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.SizedBox(
                          height: 40.h,
                          width: 150.w,
                          child: pw.Divider(thickness: 1),
                        ),
                        pw.Text('DATE & PLACE', style: smallBold),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.SizedBox(
                          height: 40.h,
                          width: 200.w,
                          child: pw.Divider(thickness: 1),
                        ),
                        pw.Text('ADVOCATE COMMISSIONER', style: smallBold),
                        pw.Text(
                          '(Signature & Seal)',
                          style: pw.TextStyle(fontSize: 8.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
        ),
      );

      // ── Show PDF preview ──
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Report generated successfully'),
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
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ═══  PDF HELPER WIDGETS  ═════════════════════════════════════
  // ═══════════════════════════════════════════════════════════════

  /// Formal section header with underline
  pw.Widget _courtSectionHeader(String title, pw.TextStyle style) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 10.h),
      pw.Text(title, style: style),
      pw.SizedBox(height: 3.h),
      pw.Container(height: 0.8.h, color: PdfColors.grey800),
      pw.SizedBox(height: 8.h),
    ],
  );

  /// Horizontal divider between major sections
  pw.Widget _courtDivider() => pw.Column(
    children: [
      pw.SizedBox(height: 6.h),
      pw.Container(height: 0.5.h, color: PdfColors.grey300),
      pw.SizedBox(height: 2.h),
    ],
  );

  /// Label: Value row in the formal style
  pw.Widget _courtLabelValue(
    String label,
    String value,
    pw.TextStyle lStyle,
    pw.TextStyle vStyle,
  ) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 2.h),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 130.w, child: pw.Text(label, style: lStyle)),
        pw.SizedBox(width: 10.w),
        pw.Expanded(child: pw.Text(value, style: vStyle)),
      ],
    ),
  );

  pw.Widget _indexRow(String sl, String title, String pg) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 4.h),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 30.w,
          child: pw.Text(sl, style: pw.TextStyle(fontSize: 10.sp)),
        ),
        pw.Expanded(
          child: pw.Text(title, style: pw.TextStyle(fontSize: 10.sp)),
        ),
        pw.Text('Pg. $pg', style: pw.TextStyle(fontSize: 10.sp)),
      ],
    ),
  );

  pw.Widget _miniLabelVal(String label, String val) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 2.h),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 60.w,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8.sp, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(val, style: pw.TextStyle(fontSize: 8.sp)),
        ),
      ],
    ),
  );
}
