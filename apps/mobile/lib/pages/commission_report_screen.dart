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

class CommissionReportScreen extends ConsumerStatefulWidget {
  final String commissionId;
  const CommissionReportScreen({super.key, required this.commissionId});
  @override
  ConsumerState<CommissionReportScreen> createState() => _CommissionReportScreenState();
}

class _CommissionReportScreenState extends ConsumerState<CommissionReportScreen> {
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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await CommissionService.fetchCommissionById(widget.commissionId);
      final v = await CommissionService.fetchVisits(widget.commissionId);
      final o = await CommissionService.fetchObservations(widget.commissionId);
      final e = await CommissionService.fetchEvidence(widget.commissionId);
      final ex = await CommissionService.fetchExpenses(widget.commissionId);
      final w = await CommissionService.fetchWitnesses(widget.commissionId);
      final sk = await CommissionService.fetchSketches(widget.commissionId);
      setState(() { _commission = c; _visits = v; _observations = o; _evidence = e; _expenses = ex; _witnesses = w; _sketches = sk; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_commission == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Commission not found')));
    final c = _commission!;

    return Scaffold(
      appBar: AppBar(title: Text('Generate Report', style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Template selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Report Template', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(_getTemplateDescription(c.commissionType), style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(c.commissionType.label.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Data summary cards
        _summaryCard(dk, Icons.location_on, 'Site Visits', '${_visits.length} recorded', AppTheme.success),
        _summaryCard(dk, Icons.camera_alt, 'Evidence', '${_evidence.length} photos', AppTheme.info),
        _summaryCard(dk, Icons.note_alt, 'Observations', '${_observations.length} notes', AppTheme.accentViolet),
        _summaryCard(dk, Icons.person, 'Witnesses', '${_witnesses.length} recorded', AppTheme.warning),
        _summaryCard(dk, Icons.draw, 'Sketches', '${_sketches.length} drawings', const Color(0xFF8B5CF6)),
        _summaryCard(dk, Icons.receipt, 'Expenses', '₹${_expenses.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(0)}', AppTheme.error),
        const SizedBox(height: 24),

        // Generate button
        SizedBox(height: 54, child: ElevatedButton.icon(
          onPressed: _generating ? null : _generateReport,
          icon: _generating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf),
          label: Text(_generating ? 'Generating...' : 'Generate & Preview PDF', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        )),
        const SizedBox(height: 60),
      ]),
    );
  }

  Widget _summaryCard(bool dk, IconData icon, String title, String value, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: dk ? const Color(0xFF1E1E2E) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight)),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: dk ? Colors.white70 : Colors.black54)),
      const Spacer(),
      Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: dk ? Colors.white : const Color(0xFF1E293B))),
    ]),
  );

  String _getTemplateDescription(CommissionType type) {
    switch (type) {
      case CommissionType.localInvestigation: return 'Property condition, encroachments, witness statements, boundary verification';
      case CommissionType.partition: return 'Room-wise measurements, proposed division, valuation details';
      case CommissionType.survey: return 'Survey marks, boundary coordinates, GPS waypoints, demarcation';
      case CommissionType.recordingEvidence: return 'Witness depositions, documentary evidence, cross-examination notes';
      case CommissionType.sale: return 'Valuation, bidding records, property condition, market analysis';
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
        if (e.fileUrl != null) {
          final bytes = await CommissionService.downloadFile('commission-evidence', e.fileUrl!);
          if (bytes != null) photoData[e.id] = bytes;
        }
      }
      for (final w in _witnesses) {
        if (w.signatureUrl != null) {
          final bytes = await CommissionService.downloadFile('commission-witnesses', w.signatureUrl!);
          if (bytes != null) signatureData[w.id] = bytes;
        }
      }
      for (final sk in _sketches) {
        if (sk.sketchImageUrl != null) {
          final bytes = await CommissionService.downloadFile('commission-sketches', sk.sketchImageUrl!);
          if (bytes != null) sketchData[sk.id] = bytes;
        }
      }

      // ── Define text styles ──
      final titleStyle = pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2);
      final subtitleStyle = pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700);
      final sectionHeaderStyle = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5);
      final labelStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
      const valueStyle = pw.TextStyle(fontSize: 10);
      const bodyStyle = pw.TextStyle(fontSize: 10);
      final smallBold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
      const smallStyle = pw.TextStyle(fontSize: 9);

      // ── Track section numbering ──
      int sectionNum = 0;

      // ── Build the document ──
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
        header: (ctx) => pw.Column(children: [
          // ── PAGE HEADER (repeats on every page) ──
          pw.Center(child: pw.Text('ADVOCATE COMMISSIONER REPORT', style: titleStyle, textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 2),
          pw.Center(child: pw.Text('Under Order XXVI, Code of Civil Procedure, 1908', style: subtitleStyle, textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 6),
          pw.Container(height: 1.5, color: PdfColors.black),
          pw.SizedBox(height: 12),
        ]),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (ctx) => [

          // ══════════════════════════════════════════════════════
          // COURT CAPTION BLOCK
          // ══════════════════════════════════════════════════════
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1, color: PdfColors.grey400),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('IN THE COURT OF THE', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 2),
              pw.Text((c.courtName ?? 'Honourable Court').toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Case No.: ${c.caseNumberRef ?? 'N/A'}', style: labelStyle)),
                pw.Text('Commission Type: ${c.commissionType.label}', style: labelStyle),
              ]),
              pw.SizedBox(height: 8),
              pw.Container(height: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Expanded(child: pw.Text(c.partyPetitioner ?? 'Petitioner', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                pw.Text('... Petitioner(s)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ]),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Vs.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic))),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Expanded(child: pw.Text(c.partyRespondent ?? 'Respondent', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                pw.Text('... Respondent(s)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 16),

          // ══════════════════════════════════════════════════════
          // SECTION: COMMISSION DETAILS
          // ══════════════════════════════════════════════════════
          _courtSectionHeader('${++sectionNum}. COMMISSION DETAILS', sectionHeaderStyle),
          _courtLabelValue('Commission Type:', c.commissionType.label, labelStyle, valueStyle),
          _courtLabelValue('Court:', c.courtName ?? 'N/A', labelStyle, valueStyle),
          _courtLabelValue('Case No.:', c.caseNumberRef ?? 'N/A', labelStyle, valueStyle),
          _courtLabelValue('Warrant Date:', c.warrantDate != null ? fmt.format(c.warrantDate!) : 'N/A', labelStyle, valueStyle),
          if (c.executionDate != null) _courtLabelValue('Execution Date:', fmt.format(c.executionDate!), labelStyle, valueStyle),
          _courtLabelValue('Petitioner:', c.partyPetitioner ?? 'N/A', labelStyle, valueStyle),
          _courtLabelValue('Respondent:', c.partyRespondent ?? 'N/A', labelStyle, valueStyle),
          _courtLabelValue('Status:', c.status.label, labelStyle, valueStyle),
          pw.SizedBox(height: 4),
          _courtDivider(),

          // ══════════════════════════════════════════════════════
          // SECTION: PROPERTY DETAILS
          // ══════════════════════════════════════════════════════
          _courtSectionHeader('${++sectionNum}. PROPERTY DETAILS', sectionHeaderStyle),
          if (c.propertyDescription != null) pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(c.propertyDescription!, style: bodyStyle),
          ),
          if (c.surveyNumber != null) _courtLabelValue('Survey No.:', c.surveyNumber!, labelStyle, valueStyle),
          _courtLabelValue('Location:', c.locationSummary, labelStyle, valueStyle),
          pw.SizedBox(height: 4),
          _courtDivider(),

          // ══════════════════════════════════════════════════════
          // SECTION: SCOPE OF WORK
          // ══════════════════════════════════════════════════════
          if (c.scopeOfWork != null && c.scopeOfWork!.isNotEmpty) ...[
            _courtSectionHeader('${++sectionNum}. SCOPE OF WORK', sectionHeaderStyle),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
              child: pw.Text(c.scopeOfWork!, style: bodyStyle),
            ),
            _courtDivider(),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION: SITE VISITS
          // ══════════════════════════════════════════════════════
          if (_visits.isNotEmpty) ...[
            _courtSectionHeader('${++sectionNum}. SITE VISITS (${_visits.length})', sectionHeaderStyle),
            ..._visits.asMap().entries.map((entry) {
              final v = entry.value;
              final visitDate = fmt.format(v.visitDate);
              final status = v.visitStatus.label;
              final gpsLat = v.checkinLat?.toStringAsFixed(4) ?? '0.0000';
              final gpsLng = v.checkinLng?.toStringAsFixed(4) ?? '0.0000';
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Visit ${entry.key + 1}: $visitDate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(height: 3),
                  pw.Text('Status: $status', style: bodyStyle),
                  pw.Text('GPS Coordinates: $gpsLat, $gpsLng', style: bodyStyle),
                  if (v.checkinAddress != null) pw.Text('Address: ${v.checkinAddress}', style: bodyStyle),
                  if (v.checkinTime != null) pw.Text('Check-in: ${DateFormat('hh:mm a').format(v.checkinTime!.toLocal())}', style: bodyStyle),
                  if (v.checkoutTime != null) pw.Text('Check-out: ${DateFormat('hh:mm a').format(v.checkoutTime!.toLocal())}${v.durationText != null ? ' (Duration: ${v.durationText})' : ''}', style: bodyStyle),
                  if (v.personsPresent != null) pw.Text('Persons Present: ${v.personsPresent}', style: bodyStyle),
                  if (v.weatherConditions != null) pw.Text('Weather: ${v.weatherConditions}', style: bodyStyle),
                  if (v.obstructionDetails != null) pw.Text('OBSTRUCTION: ${v.obstructionDetails}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                ]),
              );
            }),
            _courtDivider(),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION: OBSERVATIONS
          // ══════════════════════════════════════════════════════
          if (_observations.isNotEmpty) ...[
            _courtSectionHeader('${++sectionNum}. OBSERVATIONS (${_observations.length})', sectionHeaderStyle),
            ..._observations.asMap().entries.map((entry) {
              final o = entry.value;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6, left: 8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('${entry.key + 1}. [${o.observationType.toUpperCase()}] ${o.content}', style: bodyStyle),
                ]),
              );
            }),
            _courtDivider(),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION: WITNESS STATEMENTS
          // ══════════════════════════════════════════════════════
          if (_witnesses.isNotEmpty) ...[
            _courtSectionHeader('${++sectionNum}. WITNESS STATEMENTS (${_witnesses.length})', sectionHeaderStyle),
            ..._witnesses.asMap().entries.map((entry) {
              final w = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Witness ${entry.key + 1}: ${w.witnessName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(height: 3),
                  pw.Text('Identification: ${w.idLabel} — ${w.idNumber ?? "Not provided"}', style: bodyStyle),
                  pw.Text('GPS Location: ${w.locationText}', style: bodyStyle),
                  pw.Text('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(w.createdAt.toLocal())}', style: bodyStyle),
                  if (w.statementText != null) ...[
                    pw.SizedBox(height: 6),
                    pw.Text('Statement:', style: labelStyle),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        border: pw.Border.all(width: 0.3, color: PdfColors.grey300),
                      ),
                      child: pw.Text(w.statementText!, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                  if (signatureData.containsKey(w.id)) ...[
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                      pw.Text('Signature:', style: smallBold),
                      pw.SizedBox(width: 10),
                      pw.Image(pw.MemoryImage(signatureData[w.id]!), height: 40, width: 100),
                    ]),
                  ],
                  if (w.audioUrl != null) pw.Text('[Audio recording available]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue700)),
                ]),
              );
            }),
            _courtDivider(),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION: PHOTOGRAPHIC EVIDENCE
          // ══════════════════════════════════════════════════════
          if (_evidence.isNotEmpty) ...[
            _courtSectionHeader('${++sectionNum}. PHOTOGRAPHIC EVIDENCE (${_evidence.length} photos)', sectionHeaderStyle),
            ..._evidence.asMap().entries.map((entry) {
              final e = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Row(children: [
                    pw.Text('Photo #${e.sequenceNumber}:', style: labelStyle),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: pw.Text(e.caption ?? 'Evidence Photo', style: bodyStyle)),
                  ]),
                  pw.SizedBox(height: 2),
                  pw.Text('GPS: ${e.locationText}', style: smallStyle),
                  if (e.sha256Hash != null) pw.Text('Hash: ${e.sha256Hash!.substring(0, e.sha256Hash!.length > 20 ? 20 : e.sha256Hash!.length)}...', style: smallStyle),
                  if (photoData.containsKey(e.id)) ...[
                    pw.SizedBox(height: 8),
                    pw.Center(child: pw.Image(pw.MemoryImage(photoData[e.id]!), height: 200, width: 380)),
                  ],
                ]),
              );
            }),
            _courtDivider(),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION: PROPERTY SKETCHES
          // ══════════════════════════════════════════════════════
          if (_sketches.isNotEmpty) ...[
            _courtSectionHeader('${++sectionNum}. PROPERTY SKETCHES / DRAWINGS (${_sketches.length})', sectionHeaderStyle),
            ..._sketches.map((sk) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('${sk.title} (${sk.sketchTypeLabel})', style: labelStyle),
                pw.Text('Created: ${fmtLong.format(sk.createdAt.toLocal())}', style: smallStyle),
                if (sketchData.containsKey(sk.id)) ...[
                  pw.SizedBox(height: 8),
                  pw.Center(child: pw.Image(pw.MemoryImage(sketchData[sk.id]!), height: 250, width: 450)),
                ],
                if (sk.annotations.isNotEmpty) pw.Text('Annotations: ${sk.annotations.length} labels', style: smallStyle),
              ]),
            )),
            _courtDivider(),
          ],

          // ══════════════════════════════════════════════════════
          // SECTION: EXPENSES
          // ══════════════════════════════════════════════════════
          if (_expenses.isNotEmpty) ...[
            _courtSectionHeader('${++sectionNum}. EXPENSES', sectionHeaderStyle),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.5),
              },
              headers: ['Type', 'Description', 'Amount'],
              data: [
                ..._expenses.map((e) => [
                  e.expenseType.label,
                  e.description ?? '-',
                  '₹${e.amount.toStringAsFixed(0)}',
                ]),
                // Total row
                [
                  '',
                  'TOTAL',
                  '₹${_expenses.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(0)}',
                ],
              ],
            ),
            _courtDivider(),
          ],

          // ══════════════════════════════════════════════════════
          // VERIFICATION & DECLARATION
          // ══════════════════════════════════════════════════════
          pw.SizedBox(height: 20),
          _courtSectionHeader('VERIFICATION', sectionHeaderStyle),
          pw.SizedBox(height: 6),
          pw.Text(
            'I, the undersigned Advocate Commissioner, do hereby verify and declare that the contents of this report are true and correct to the best of my knowledge and belief, based on my personal inspection and investigation carried out in connection with the above-mentioned case.',
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'This report is prepared in accordance with the directions of the Honourable Court and is submitted for the kind consideration of the Court.',
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Report generated on: ${DateFormat('dd-MM-yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),

          // ══════════════════════════════════════════════════════
          // SIGNATURE BLOCK
          // ══════════════════════════════════════════════════════
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.Container(width: 180, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text('Advocate Commissioner', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.Container(width: 120, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue800)),
              ]),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Text(
              'Generated via CaseFlow — Advocate Commissioner Module',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
            ),
          ),
        ],
      ));

      // ── Show PDF preview ──
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✅ Report generated successfully'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
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
      pw.SizedBox(height: 10),
      pw.Text(title, style: style),
      pw.SizedBox(height: 3),
      pw.Container(height: 0.8, color: PdfColors.grey800),
      pw.SizedBox(height: 8),
    ],
  );

  /// Horizontal divider between major sections
  pw.Widget _courtDivider() => pw.Column(children: [
    pw.SizedBox(height: 6),
    pw.Container(height: 0.5, color: PdfColors.grey300),
    pw.SizedBox(height: 2),
  ]);

  /// Label: Value row in the formal style
  pw.Widget _courtLabelValue(String label, String value, pw.TextStyle lStyle, pw.TextStyle vStyle) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 130, child: pw.Text(label, style: lStyle)),
      pw.SizedBox(width: 10),
      pw.Expanded(child: pw.Text(value, style: vStyle)),
    ]),
  );
}
