import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/commission_models.dart';
import '../services/commission_service.dart';
import '../services/repositories/profile_repository.dart';
import '../theme/app_theme.dart';
import '../components/commission/cm_kit.dart';
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
  List<CommissionParty> _parties = [];
  List<CommissionMeasurement> _measurements = [];
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
      final id = widget.commissionId;
      final cF = CommissionService.fetchCommissionById(id);
      final vF = _orEmpty(CommissionService.fetchVisits(id));
      final oF = _orEmpty(CommissionService.fetchObservations(id));
      final eF = _orEmpty(CommissionService.fetchEvidence(id));
      final exF = _orEmpty(CommissionService.fetchExpenses(id));
      final wF = _orEmpty(CommissionService.fetchWitnesses(id));
      final skF = _orEmpty(CommissionService.fetchSketches(id));
      final pF = _orEmpty(CommissionService.fetchParties(id));
      final mF = _orEmpty(CommissionService.fetchMeasurements(id));
      final c = await cF;
      final v = await vF;
      final o = await oF;
      final e = await eF;
      final ex = await exF;
      final w = await wF;
      final sk = await skF;
      final parties = await pF;
      final measurements = await mF;
      if (!mounted) return;
      setState(() {
        _commission = c;
        _visits = v;
        _observations = o;
        _evidence = e;
        _expenses = ex;
        _witnesses = w;
        _sketches = sk;
        _parties = parties;
        _measurements = measurements;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// One list that fails to load leaves that section empty instead of
  /// hiding the whole commission.
  static Future<List<T>> _orEmpty<T>(Future<List<T>> f) async {
    try {
      return await f;
    } catch (e) {
      debugPrint('Commission report: a list failed to load: $e');
      return <T>[];
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final site = c.commissionType.isSiteWork;
    final checks = <(String, bool, String)>[
      ('Appointment & warrant', c.warrantDate != null && c.courtName != null,
          c.warrantDate == null ? 'Add the warrant date' : (c.courtName == null ? 'Add the court' : 'Ready')),
      ('Notice to parties', _parties.isNotEmpty && c.inspectionAt != null && _parties.every((p) => p.noticeStatus.noticeGiven),
          _parties.isEmpty
              ? 'No parties yet'
              : c.inspectionAt == null
                  ? 'Date of inspection missing'
                  : '${_parties.where((p) => p.noticeStatus.noticeGiven).length} of ${_parties.length} given notice'),
      ('Memo of inspection', _visits.any((v) => v.checkoutTime != null),
          _visits.isEmpty ? 'No visits yet' : '${_visits.length} ${_visits.length == 1 ? 'visit' : 'visits'}'),
      ('Persons present', _visits.isNotEmpty && _visits.every((v) => v.personsPresent != null),
          _visits.any((v) => v.personsPresent == null) ? 'Not recorded for every visit' : 'Recorded'),
      if (site)
        ('Boundaries & extent', _measurements.isNotEmpty && _measurements.every((m) => m.isComplete),
            _measurements.isEmpty ? 'Nothing measured' : '${_measurements.where((m) => m.isComplete).length} of ${_measurements.length} complete'),
      ('Observations', _observations.isNotEmpty, '${_observations.length} notes'),
      ('Witness statements', _witnesses.every((w) => w.signatureUrl != null),
          _witnesses.isEmpty ? 'None — fine if none were examined' : '${_witnesses.where((w) => w.signatureUrl == null).length} without signature'),
      if (site) ('Sketch / plan', _sketches.isNotEmpty, _sketches.isEmpty ? 'No sketch yet' : '${_sketches.length} drawn'),
      if (site) ('Photos (Annexure A)', _evidence.isNotEmpty, '${_evidence.length} photos'),
      ('Fee & expense memo', c.feeFixed != null, c.feeFixed == null ? 'Fee not entered' : 'Ready'),
    ];
    final ready = checks.where((x) => x.$2).length;
    return CmScaffold(
      title: 'Commissioner’s report',
      bottom: CmButton(
        _generating ? 'Preparing the PDF…' : 'Preview & share PDF',
        icon: Icons.picture_as_pdf_rounded,
        busy: _generating,
        onPressed: _generateReport,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
        children: [
          CmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$ready of ${checks.length} sections ready', style: Cm.title(context, size: 16)),
                          SizedBox(height: 2.h),
                          Text(
                            ready == checks.length
                                ? 'Everything is in. Preview the report, then file it.'
                                : 'You can preview at any time; the sections marked below are incomplete.',
                            style: Cm.body(context),
                          ),
                        ],
                      ),
                    ),
                    CmPill(c.commissionType.rule, tone: CmTone.violet),
                  ],
                ),
                SizedBox(height: 12.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: checks.isEmpty ? 0 : ready / checks.length,
                    minHeight: 6.h,
                    color: Cm.violet,
                    backgroundColor: Cm.border(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          CmCard(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            child: Column(
              children: [
                for (var i = 0; i < checks.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Cm.border(context)),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                    child: Row(
                      children: [
                        Icon(checks[i].$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 20.r, color: checks[i].$2 ? AppTheme.success : AppTheme.warning),
                        SizedBox(width: 10.w),
                        Expanded(child: Text(checks[i].$1, style: Cm.title(context, size: 14))),
                        Flexible(
                          child: Text(checks[i].$3,
                              textAlign: TextAlign.right,
                              style: Cm.body(context, size: 12, color: checks[i].$2 ? Cm.sub(context) : AppTheme.warning)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 12.h),
          CmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CmLabel('Signed by'),
                SizedBox(height: 6.h),
                Text('Your name and bar enrolment number from My account are printed under the signature.',
                    style: Cm.body(context)),
                SizedBox(height: 6.h),
                Text(_getTemplateDescription(c.commissionType), style: Cm.body(context, size: 12, color: Cm.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
      case CommissionType.accounts:
        return 'Statement of accounts examined, entries objected to, findings';
      case CommissionType.scientificInvestigation:
        return 'Samples taken, method, results and expert opinion';
      case CommissionType.ministerialAct:
        return 'The act performed, how and when, persons present';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ═══  PDF GENERATION — FORMAL COURT DOCUMENT  ═════════════════
  // ═══════════════════════════════════════════════════════════════

  Future<void> _generateReport() async {
    setState(() => _generating = true);
    try {
      final c = _commission!;
      final me = await ProfileRepository.getProfile();
      final commissionerName =
          (me.fullName?.trim().isNotEmpty ?? false) ? me.fullName!.trim() : 'Advocate Commissioner';
      final enrolment = me.registrationNumber?.trim();
      final pdf = pw.Document();
      final fmt = DateFormat('dd-MM-yyyy');

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
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 1.2,
      );
      final subtitleStyle = pw.TextStyle(
        fontSize: 10,
        fontStyle: pw.FontStyle.italic,
        color: PdfColors.grey700,
      );
      final sectionHeaderStyle = pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.5,
      );
      final labelStyle = pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      );
      final valueStyle = pw.TextStyle(fontSize: 10);
      final bodyStyle = pw.TextStyle(fontSize: 10);
      final smallBold = pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      );
      final smallStyle = pw.TextStyle(fontSize: 9);


      // ── Build the document ──

      // PAGE 1: TITLE & COVER
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
          build:
              (ctx) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'ADVOCATE COMMISSIONER\'S REPORT',
                    style: titleStyle.copyWith(fontSize: 18),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'REPORT OF THE COMMISSIONER APPOINTED BY THE COURT',
                    style: subtitleStyle.copyWith(fontSize: 11),
                  ),
                  pw.SizedBox(height: 40),

                  // Court Caption
                  pw.Container(
                    padding: pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 1.5),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'IN THE COURT OF',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          (c.courtName ?? 'THE HONOURABLE COURT').toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 20),
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
                        pw.SizedBox(height: 12),
                        pw.Divider(),
                        pw.SizedBox(height: 12),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                c.partyPetitioner ?? 'Petitioner',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Text(
                              '... Petitioner(s)',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'VERSUS',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                c.partyRespondent ?? 'Respondent',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Text(
                              '... Respondent(s)',
                              style: pw.TextStyle(fontSize: 10),
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
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'ADVOCATE COMMISSIONER',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        enrolment != null && enrolment.isNotEmpty
                            ? '$commissionerName · Enrolment No. $enrolment'
                            : commissionerName,
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                ],
              ),
        ),
      );

      // PAGE 2: INDEX / CONTENTS
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
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
                  pw.SizedBox(height: 20),
                  _indexRow('1.', 'Commission Details & Background'),
                  _indexRow('2.', 'Notice to Parties'),
                  _indexRow('3.', 'Memo of Inspection / Site Visits'),
                  _indexRow('4.', 'Observations & Findings'),
                  if (_measurements.isNotEmpty) _indexRow('5.', 'Boundaries & Extent'),
                  _indexRow('', 'Certification & Oath'),
                  pw.SizedBox(height: 20),
                  pw.Text('ANNEXURES', style: smallBold),
                  pw.SizedBox(height: 10),
                  if (_evidence.isNotEmpty)
                    _indexRow('A', 'Photographic Evidence (Annexure-A)'),
                  if (_sketches.isNotEmpty)
                    _indexRow('B', 'Drawings & Sketches (Annexure-B)'),
                  if (_witnesses.isNotEmpty)
                    _indexRow('C', 'Witness Statements (Annexure-C)'),
                  if (_expenses.isNotEmpty || c.feeFixed != null)
                    _indexRow('D', 'Memo of Fee & Expenses (Annexure-D)'),
                ],
              ),
        ),
      );

      // PAGE 3+: MAIN REPORT BODY (continuous flow — all sections + annexures)
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
          header:
              (ctx) => pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Advocate Commissioner Report | ${c.caseNumberRef ?? ""}',
                  style: pw.TextStyle(
                    fontSize: 8,
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
                    fontSize: 8,
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
                pw.SizedBox(height: 10),
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
                  pw.SizedBox(height: 12),
                  pw.Text('Scope of Work:', style: labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    c.scopeOfWork!,
                    style: bodyStyle,
                    textAlign: pw.TextAlign.justify,
                  ),
                ],

                pw.SizedBox(height: 20),

                // ─── SECTION 2: NOTICE TO PARTIES ──────────────────
                _courtSectionHeader('2. NOTICE TO PARTIES', sectionHeaderStyle),
                pw.Text(
                  c.inspectionAt != null
                      ? 'Notice was given to the parties that the commission would be executed on '
                          '${DateFormat('dd MMMM yyyy').format(c.inspectionAt!.toLocal())} at '
                          '${DateFormat('hh:mm a').format(c.inspectionAt!.toLocal())}'
                          '${c.inspectionPlace != null ? ' at ${c.inspectionPlace}' : ''}.'
                      : 'The date of inspection was not recorded.',
                  style: bodyStyle,
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 8),
                if (_parties.isEmpty)
                  pw.Text('No parties were recorded.', style: bodyStyle)
                else
                  pw.TableHelper.fromTextArray(
                    headers: ['Sl', 'Party', 'Notice', 'On / how', 'Attended'],
                    data: [
                      for (var i = 0; i < _parties.length; i++)
                        [
                          '${i + 1}',
                          '${_parties[i].name}\n${_parties[i].roleText}${_parties[i].advocate != null ? ' · ${_parties[i].advocate}' : ''}',
                          _parties[i].noticeStatus.label,
                          [
                            if (_parties[i].servedOn != null) fmt.format(_parties[i].servedOn!),
                            if (_parties[i].servedHow != null) _parties[i].servedHow!,
                          ].join(' — '),
                          _parties[i].attended == null ? '—' : (_parties[i].attended! ? 'Yes' : 'No'),
                        ],
                    ],
                    cellStyle: pw.TextStyle(fontSize: 9),
                    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(22),
                      2: const pw.FixedColumnWidth(60),
                      4: const pw.FixedColumnWidth(50),
                    },
                    border: pw.TableBorder.all(width: 0.5),
                  ),
                if (_parties.any((x) => x.attended == false && x.noticeStatus.noticeGiven)) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Parties who were given notice but did not attend were proceeded against in their absence.',
                    style: bodyStyle,
                  ),
                ],

                pw.SizedBox(height: 20),

                // ─── SECTION 3: MEMO OF INSPECTION ─────────────────
                _courtSectionHeader(
                  '3. MEMO OF INSPECTION / SITE VISITS',
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
                    margin: pw.EdgeInsets.only(bottom: 12),
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        width: 0.3,
                        color: PdfColors.grey400,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '3.${entry.key + 1}. SITE VISIT - ${fmt.format(v.visitDate)}',
                          style: smallBold,
                        ),
                        pw.SizedBox(height: 4),
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
                          v.checkinAddress ?? 'Not recorded',
                        ),
                        // Only a real fix is printed — never "null, null",
                        // and never 0,0 saved by older versions of the app.
                        if (v.checkinLat != null &&
                            v.checkinLng != null &&
                            !(v.checkinLat == 0 && v.checkinLng == 0))
                          _miniLabelVal(
                            'Coordinates:',
                            '${v.checkinLat!.toStringAsFixed(6)}, ${v.checkinLng!.toStringAsFixed(6)}',
                          ),
                        if (v.personsPresent != null)
                          _miniLabelVal('Present:', v.personsPresent!),
                        if (v.obstructionDetails != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'OBSTRUCTION ENCOUNTERED:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                            ),
                          ),
                          pw.Text(
                            v.obstructionDetails!,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 20),

                // ─── SECTION 4: OBSERVATIONS & FINDINGS ────────────
                _courtSectionHeader(
                  '4. OBSERVATIONS & FINDINGS',
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
                    padding: pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('4.${entry.key + 1}. ', style: labelStyle),
                        pw.Expanded(
                          child: pw.Text(
                            o.observationType == 'general'
                                ? o.content
                                : '[${o.observationType.toUpperCase()}] ${o.content}',
                            style: bodyStyle,
                            textAlign: pw.TextAlign.justify,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 20),

                // ─── SECTION 5: BOUNDARIES & EXTENT ────────────────
                if (_measurements.isNotEmpty) ...[
                  _courtSectionHeader('5. BOUNDARIES & EXTENT', sectionHeaderStyle),
                  for (final m in _measurements) ...[
                    pw.Text(m.label, style: labelStyle),
                    pw.SizedBox(height: 4),
                    pw.TableHelper.fromTextArray(
                      headers: ['Side', 'Bounded by (as found at site)', 'Length'],
                      data: [
                        ['North', m.northBy ?? '—', m.northLen ?? '—'],
                        ['South', m.southBy ?? '—', m.southLen ?? '—'],
                        ['East', m.eastBy ?? '—', m.eastLen ?? '—'],
                        ['West', m.westBy ?? '—', m.westLen ?? '—'],
                      ],
                      cellStyle: pw.TextStyle(fontSize: 9.5),
                      headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                      columnWidths: {0: const pw.FixedColumnWidth(46), 2: const pw.FixedColumnWidth(70)},
                      border: pw.TableBorder.all(width: 0.5),
                    ),
                    pw.SizedBox(height: 4),
                    if (m.extent != null)
                      pw.Text(
                        'Extent found at site: ${_area(m.extent!)} ${m.unit.short}'
                        '${m.unit != AreaUnit.cents ? ' (${_area(m.unit.convert(m.extent!, AreaUnit.cents))} cents)' : ''}'
                        '${m.scheduleExtent != null ? '. As per schedule: ${_area(m.scheduleExtent!)} ${m.unit.short}'
                            '${m.difference != 0 ? ' — ${_area(m.difference!.abs())} ${m.unit.short} ${m.difference! > 0 ? 'more' : 'less'} at site' : ', which tallies'}' : ''}.',
                        style: bodyStyle,
                      ),
                    if (m.notes != null) pw.Text(m.notes!, style: bodyStyle),
                    pw.SizedBox(height: 10),
                  ],
                  pw.SizedBox(height: 10),
                ],

                // ─── ANNEXURE A: PHOTOGRAPHIC EVIDENCE (continuous) ─
                if (_evidence.isNotEmpty) ...[
                  _courtSectionHeader(
                    'ANNEXURE - A: PHOTOGRAPHIC EVIDENCE',
                    sectionHeaderStyle,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children:
                        _evidence.map((e) {
                          return pw.Container(
                            width: 230,
                            padding: pw.EdgeInsets.all(5),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                width: 0.5,
                                color: PdfColors.grey300,
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                if (photoData.containsKey(e.id))
                                  pw.Image(
                                    pw.MemoryImage(photoData[e.id]!),
                                    height: 160,
                                    width: 220,
                                    fit: pw.BoxFit.cover,
                                  ),
                                pw.SizedBox(height: 5),
                                pw.Text(
                                  'PHOTO #${e.sequenceNumber}',
                                  style: smallBold,
                                ),
                                pw.Text(
                                  e.caption ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 8),
                                  maxLines: 2,
                                ),
                                pw.Text(
                                  'GPS: ${e.locationText}',
                                  style: pw.TextStyle(
                                    fontSize: 7,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // ─── ANNEXURE B: DRAWINGS & SKETCHES (continuous) ───
                if (_sketches.isNotEmpty) ...[
                  _courtSectionHeader(
                    'ANNEXURE - B: DRAWINGS & SKETCHES',
                    sectionHeaderStyle,
                  ),
                  pw.SizedBox(height: 10),
                  ..._sketches.map(
                    (sk) => pw.Container(
                      margin: pw.EdgeInsets.only(bottom: 30),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${sk.title} (${sk.sketchTypeLabel})',
                            style: labelStyle,
                          ),
                          pw.SizedBox(height: 5),
                          if (sketchData.containsKey(sk.id))
                            pw.Center(
                              child: pw.Image(
                                pw.MemoryImage(sketchData[sk.id]!),
                                height: 350,
                              ),
                            ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'Annotations: ${sk.annotations.length} key points identified',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // ─── ANNEXURE C: WITNESS STATEMENTS (continuous) ────
                if (_witnesses.isNotEmpty) ...[
                  _courtSectionHeader(
                    'ANNEXURE - C: WITNESS STATEMENTS',
                    sectionHeaderStyle,
                  ),
                  pw.SizedBox(height: 10),
                  ..._witnesses.map(
                    (w) => pw.Container(
                      margin: pw.EdgeInsets.only(bottom: 20),
                      padding: pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 0.5),
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
                                'ID: ${w.idLabel} ${w.displayIdNumber ?? ""}',
                                style: smallStyle,
                              ),
                            ],
                          ),
                          pw.Divider(thickness: 0.5),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            w.statementText ?? 'No statement recorded',
                            style: bodyStyle,
                            textAlign: pw.TextAlign.justify,
                          ),
                          pw.SizedBox(height: 15),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Column(
                                children: [
                                  if (signatureData.containsKey(w.id))
                                    pw.Image(
                                      pw.MemoryImage(signatureData[w.id]!),
                                      height: 50,
                                    ),
                                  pw.Container(
                                    width: 120,
                                    height: 0.5,
                                    color: PdfColors.black,
                                  ),
                                  pw.Text(
                                    'Signature of Witness',
                                    style: pw.TextStyle(fontSize: 8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // ─── ANNEXURE D: MEMO OF FEE & EXPENSES ────────────
                if (_expenses.isNotEmpty || c.feeFixed != null) ...[
                  _courtSectionHeader(
                    'ANNEXURE - D: MEMO OF FEE & EXPENSES',
                    sectionHeaderStyle,
                  ),
                  pw.SizedBox(height: 10),
                  if (c.feeFixed != null) ...[
                    _courtLabelValue('Fee fixed by Court:', 'INR ${c.feeFixed!.toStringAsFixed(2)}', labelStyle, valueStyle),
                    if (c.feeDepositedBy != null)
                      _courtLabelValue('Deposited by:', c.feeDepositedBy!, labelStyle, valueStyle),
                    _courtLabelValue(
                      'Received:',
                      'INR ${(c.feeReceived ?? 0).toStringAsFixed(2)}${c.feeReceivedOn != null ? ' on ${fmt.format(c.feeReceivedOn!)}' : ''}',
                      labelStyle,
                      valueStyle,
                    ),
                    if ((c.feeBalance ?? 0) > 0)
                      _courtLabelValue('Balance due:', 'INR ${c.feeBalance!.toStringAsFixed(2)}', labelStyle, valueStyle),
                    pw.SizedBox(height: 10),
                  ],
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'Sl No',
                      'Expense Type',
                      'Description',
                      'Amount (INR)',
                    ],
                    data: [
                      if (_expenses.isEmpty) ['', 'No expenses', '', '0.00'],
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
                    cellStyle: pw.TextStyle(fontSize: 10),
                    headerStyle: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    border: pw.TableBorder.all(width: 0.5),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // ─── SECTION 4: CERTIFICATION & OATH (at the end) ──
                _courtSectionHeader('CERTIFICATION & OATH', sectionHeaderStyle),
                pw.Text(
                  'I, $commissionerName, Advocate Commissioner, do hereby solemnly affirm and state as follows:',
                  style: labelStyle,
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '1. Accuracy: I certify that the inspection was conducted in a fair and transparent manner, providing equal opportunity to all parties present.',
                  style: bodyStyle,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '2. Neutrality: That I have no interest, direct or indirect, in the subject matter or in the parties to the litigation.',
                  style: bodyStyle,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '3. Verified Data: That the photographic evidence, sketches, and statements attached herewith as Annexures were captured/recorded by me or under my direct supervision during the execution of the commission.',
                  style: bodyStyle,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '4. Integrity: That this report is a true and faithful representation of the facts as observed at the site.',
                  style: bodyStyle,
                ),

                pw.SizedBox(height: 50),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.SizedBox(
                          height: 40,
                          width: 150,
                          child: pw.Divider(thickness: 1),
                        ),
                        pw.Text('DATE & PLACE', style: smallBold),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.SizedBox(
                          height: 40,
                          width: 200,
                          child: pw.Divider(thickness: 1),
                        ),
                        pw.Text(commissionerName.toUpperCase(), style: smallBold),
                        pw.Text('ADVOCATE COMMISSIONER', style: smallStyle),
                        if (enrolment != null && enrolment.isNotEmpty)
                          pw.Text('Enrolment No. $enrolment', style: smallStyle),
                        pw.Text(
                          '(Signature & Seal)',
                          style: pw.TextStyle(fontSize: 8),
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
      pw.SizedBox(height: 10),
      pw.Text(title, style: style),
      pw.SizedBox(height: 3),
      pw.Container(height: 0.8, color: PdfColors.grey800),
      pw.SizedBox(height: 8),
    ],
  );

  /// Label: Value row in the formal style
  pw.Widget _courtLabelValue(
    String label,
    String value,
    pw.TextStyle lStyle,
    pw.TextStyle vStyle,
  ) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 130, child: pw.Text(label, style: lStyle)),
        pw.SizedBox(width: 10),
        pw.Expanded(child: pw.Text(value, style: vStyle)),
      ],
    ),
  );

  // No page numbers: they were fixed text that never matched the real pages.
  static String _area(double v) {
    final t = v.toStringAsFixed(v.abs() >= 100 ? 0 : 2);
    return t.contains('.') ? t.replaceFirst(RegExp(r'\.?0+$'), '') : t;
  }

  pw.Widget _indexRow(String sl, String title) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 30,
          child: pw.Text(sl, style: pw.TextStyle(fontSize: 10)),
        ),
        pw.Expanded(
          child: pw.Text(title, style: pw.TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );

  pw.Widget _miniLabelVal(String label, String val) => pw.Padding(
    padding: pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 60,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(val, style: pw.TextStyle(fontSize: 8)),
        ),
      ],
    ),
  );
}
