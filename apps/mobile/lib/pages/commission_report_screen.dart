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

  Future<void> _generateReport() async {
    setState(() => _generating = true);
    try {
      final c = _commission!;
      final pdf = pw.Document();
      final fmt = DateFormat('dd MMM yyyy');

      // Pre-download all images for embedding (NEW)
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

      // Build PDF based on commission type
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          // Header
          _pdfHeader(c, fmt),
          pw.SizedBox(height: 20),

          // Commission Info
          _pdfSection('COMMISSION DETAILS', [
            _pdfRow('Commission Type', c.commissionType.label),
            _pdfRow('Court', c.courtName ?? 'N/A'),
            _pdfRow('Case Number', c.caseNumberRef ?? 'N/A'),
            _pdfRow('Petitioner', c.partyPetitioner ?? 'N/A'),
            _pdfRow('Respondent', c.partyRespondent ?? 'N/A'),
            _pdfRow('Warrant Date', c.warrantDate != null ? fmt.format(c.warrantDate!) : 'N/A'),
            _pdfRow('Execution Date', c.executionDate != null ? fmt.format(c.executionDate!) : 'N/A'),
            _pdfRow('Status', c.status.label),
          ]),

          // Property Description (type-specific)
          ..._pdfTypeSpecificPropertySection(c, fmt),

          // Site Visits with GPS
          if (_visits.isNotEmpty) ...[
            _pdfSection('SITE VISIT RECORDS', _visits.asMap().entries.map((entry) {
              final v = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Visit #${entry.key + 1} — ${fmt.format(v.visitDate)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  pw.Text('Check-in: ${v.checkinTime != null ? DateFormat('hh:mm a').format(v.checkinTime!.toLocal()) : "N/A"}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('GPS: ${v.checkinLat?.toStringAsFixed(6) ?? "N/A"}, ${v.checkinLng?.toStringAsFixed(6) ?? "N/A"}', style: const pw.TextStyle(fontSize: 10)),
                  if (v.checkinAddress != null) pw.Text('Address: ${v.checkinAddress}', style: const pw.TextStyle(fontSize: 10)),
                  if (v.checkoutTime != null) pw.Text('Check-out: ${DateFormat('hh:mm a').format(v.checkoutTime!.toLocal())}${v.durationText != null ? ' (Duration: ${v.durationText})' : ''}', style: const pw.TextStyle(fontSize: 10)),
                  if (v.checkoutLat != null) pw.Text('Checkout GPS: ${v.checkoutLat?.toStringAsFixed(6)}, ${v.checkoutLng?.toStringAsFixed(6)}', style: const pw.TextStyle(fontSize: 10)),
                  if (v.personsPresent != null) pw.Text('Persons Present: ${v.personsPresent}', style: const pw.TextStyle(fontSize: 10)),
                  if (v.obstructionDetails != null) pw.Text('⚠️ OBSTRUCTION: ${v.obstructionDetails}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                ]),
              );
            }).toList()),
          ],

          // Type-specific observations section
          ..._pdfTypeSpecificObservationsSection(c),

          // Witness Statements (Phase 2)
          if (_witnesses.isNotEmpty) ...[
            _pdfSection('WITNESS STATEMENTS', _witnesses.asMap().entries.map((entry) {
              final w = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Witness #${entry.key + 1}: ${w.witnessName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('ID: ${w.idLabel} — ${w.idNumber ?? "Not provided"}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('GPS Location: ${w.locationText}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(w.createdAt.toLocal())}', style: const pw.TextStyle(fontSize: 10)),
                  if (w.statementText != null) ...[
                    pw.SizedBox(height: 6),
                    pw.Text('Statement:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text(w.statementText!, style: const pw.TextStyle(fontSize: 10)),
                  ],
                  if (signatureData.containsKey(w.id)) ...[
                    pw.SizedBox(height: 8),
                    pw.Row(children: [
                       pw.Text('Signature:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                       pw.SizedBox(width: 10),
                       pw.Image(pw.MemoryImage(signatureData[w.id]!), height: 40, width: 100),
                    ]),
                  ],
                  if (w.audioUrl != null) pw.Text('[Audio recording available]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue)),
                ]),
              );
            }).toList()),
          ],

          // Evidence
          if (_evidence.isNotEmpty) ...[
            _pdfSection('PHOTOGRAPHIC EVIDENCE', _evidence.map((e) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  pw.Text('Photo #${e.sequenceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Text(e.caption ?? 'Evidence', style: const pw.TextStyle(fontSize: 10))),
                  pw.Text('GPS: ${e.locationText}', style: const pw.TextStyle(fontSize: 9)),
                ]),
                if (photoData.containsKey(e.id)) ...[
                  pw.SizedBox(height: 6),
                  pw.Center(child: pw.Image(pw.MemoryImage(photoData[e.id]!), height: 200, width: 400)),
                ],
              ]),
            )).toList()),
          ],

          // Sketches (Phase 2)
          if (_sketches.isNotEmpty) ...[
            _pdfSection('PROPERTY SKETCHES / DRAWINGS', _sketches.map((sk) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('${sk.title} (${sk.sketchTypeLabel})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Created: ${DateFormat('dd MMM yyyy').format(sk.createdAt.toLocal())}', style: const pw.TextStyle(fontSize: 9)),
                if (sketchData.containsKey(sk.id)) ...[
                   pw.SizedBox(height: 6),
                   pw.Center(child: pw.Image(pw.MemoryImage(sketchData[sk.id]!), height: 250, width: 500)),
                ],
                if (sk.annotations.isNotEmpty) pw.Text('Annotations: ${sk.annotations.length} labels', style: const pw.TextStyle(fontSize: 9)),
              ]),
            )).toList()),
          ],

          // Expenses
          if (_expenses.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _pdfSection('EXPENSE SUMMARY', [
              ..._expenses.map((e) => pw.Row(children: [
                pw.Expanded(child: pw.Text(e.expenseType.label, style: const pw.TextStyle(fontSize: 10))),
                pw.Text(e.description ?? '', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(width: 10),
                pw.Text('₹${e.amount.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ])),
              pw.Divider(),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                pw.Text('₹${_expenses.fold<double>(0, (s, e) => s + e.amount).toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ]),
            ]),
          ],

          // Commissioner signature block
          pw.SizedBox(height: 40),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Container(width: 180, height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),
              pw.Text('Advocate Commissioner', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('Date: ${fmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ]),
        ],
      ));

      // Show PDF preview
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

  // ─── PDF Helpers ──────────────────────────────────────

  pw.Widget _pdfHeader(Commission c, DateFormat fmt) => pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
    child: pw.Column(children: [
      pw.Text('ADVOCATE COMMISSIONER REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('${c.commissionType.label} — ${c.courtName ?? ""}', style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(height: 4),
      pw.Text('Case: ${c.caseNumberRef ?? "N/A"} | ${c.partyPetitioner ?? ""} vs. ${c.partyRespondent ?? ""}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('Generated: ${fmt.format(DateTime.now())} via CaseFlow', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ]),
  );

  pw.Widget _pdfSection(String title, List<pw.Widget> children) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.SizedBox(height: 16),
    pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: PdfColors.grey200, child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
    pw.SizedBox(height: 8),
    ...children,
  ]);

  pw.Widget _pdfRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(children: [
      pw.SizedBox(width: 140, child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
      pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
    ]),
  );

  // ─── Type-Specific Sections ───────────────────────────

  List<pw.Widget> _pdfTypeSpecificPropertySection(Commission c, DateFormat fmt) {
    switch (c.commissionType) {
      case CommissionType.localInvestigation:
        return [
          _pdfSection('PROPERTY DESCRIPTION & CONDITION', [
            if (c.propertyDescription != null) pw.Text(c.propertyDescription!, style: const pw.TextStyle(fontSize: 10)),
            if (c.surveyNumber != null) _pdfRow('Survey Number', c.surveyNumber!),
            _pdfRow('Location', c.locationSummary),
            if (c.scopeOfWork != null) ...[pw.SizedBox(height: 6), pw.Text('Scope of Work:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text(c.scopeOfWork!, style: const pw.TextStyle(fontSize: 10))],
          ]),
        ];
      case CommissionType.partition:
        return [
          _pdfSection('PROPERTY FOR PARTITION', [
            if (c.propertyDescription != null) pw.Text(c.propertyDescription!, style: const pw.TextStyle(fontSize: 10)),
            if (c.surveyNumber != null) _pdfRow('Survey Number', c.surveyNumber!),
            _pdfRow('Location', c.locationSummary),
          ]),
          _pdfSection('PROPOSED DIVISION', [
            pw.Text('(To be detailed based on room-wise measurements and proposed partition)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ]),
        ];
      case CommissionType.survey:
        return [
          _pdfSection('SURVEY & DEMARCATION DETAILS', [
            if (c.surveyNumber != null) _pdfRow('Survey Number', c.surveyNumber!),
            _pdfRow('Location', c.locationSummary),
            if (c.propertyDescription != null) ...[pw.SizedBox(height: 6), pw.Text('Property Description:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text(c.propertyDescription!, style: const pw.TextStyle(fontSize: 10))],
          ]),
          _pdfSection('GPS BOUNDARY COORDINATES', _visits.where((v) => v.checkinLat != null && v.checkinLat != 0).map((v) => pw.Text('Visit ${fmt.format(v.visitDate)}: ${v.checkinLat?.toStringAsFixed(6)}, ${v.checkinLng?.toStringAsFixed(6)}', style: const pw.TextStyle(fontSize: 10))).toList()),
        ];
      case CommissionType.recordingEvidence:
        return [
          _pdfSection('EVIDENCE RECORDING DETAILS', [
            _pdfRow('Location', c.locationSummary),
            if (c.scopeOfWork != null) ...[pw.SizedBox(height: 6), pw.Text('Recording Scope:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text(c.scopeOfWork!, style: const pw.TextStyle(fontSize: 10))],
          ]),
        ];
      case CommissionType.sale:
        return [
          _pdfSection('SALE / VALUATION DETAILS', [
            if (c.propertyDescription != null) pw.Text(c.propertyDescription!, style: const pw.TextStyle(fontSize: 10)),
            if (c.surveyNumber != null) _pdfRow('Survey Number', c.surveyNumber!),
            _pdfRow('Location', c.locationSummary),
          ]),
        ];
    }
  }

  List<pw.Widget> _pdfTypeSpecificObservationsSection(Commission c) {
    if (_observations.isEmpty) return [];
    switch (c.commissionType) {
      case CommissionType.localInvestigation:
        // Group by observation type
        final groups = <String, List<CommissionObservation>>{};
        for (final o in _observations) {
          final key = o.observationType.toUpperCase();
          groups.putIfAbsent(key, () => []).add(o);
        }
        return groups.entries.map((entry) => _pdfSection('OBSERVATIONS — ${entry.key}', entry.value.map((o) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('${DateFormat('dd MMM, hh:mm a').format(o.createdAt.toLocal())}:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(o.content, style: const pw.TextStyle(fontSize: 10)),
          ]),
        )).toList())).toList();
      case CommissionType.partition:
        return [_pdfSection('OBSERVATIONS & MEASUREMENTS', _observations.map((o) => pw.Text('• [${o.observationType}] ${o.content}', style: const pw.TextStyle(fontSize: 10))).toList())];
      case CommissionType.survey:
        return [_pdfSection('SURVEY OBSERVATIONS', _observations.map((o) => pw.Text('• [${o.observationType}] ${o.content}', style: const pw.TextStyle(fontSize: 10))).toList())];
      case CommissionType.recordingEvidence:
        return [_pdfSection('RECORDED OBSERVATIONS', _observations.map((o) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('${DateFormat('dd MMM yyyy, hh:mm a').format(o.createdAt.toLocal())}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(o.content, style: const pw.TextStyle(fontSize: 10)),
          ]),
        )).toList())];
      case CommissionType.sale:
        return [_pdfSection('OBSERVATIONS', _observations.map((o) => pw.Text('• ${o.content}', style: const pw.TextStyle(fontSize: 10))).toList())];
    }
  }
}
