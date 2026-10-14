import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/title_search_models.dart';

class TitleReportPdfService {
  static Future<void> generateAndExport({
    required TitleSearch search,
    required List<TitleFinding> findings,
    required List<TitleChainLink> chainLinks,
    required List<TitleDocument> documents,
    String? advocateName,
    String? advocateOpinion,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd-MMM-yyyy');
    final nowFormatted = dateFormat.format(DateTime.now());

    final criticalFindings = findings.where((f) => f.isCritical).toList();
    final warningFindings = findings.where((f) => f.isWarning).toList();
    final passedFindings = findings.where((f) => f.isPassed).toList();

    final score = search.healthScore ?? 0;
    PdfColor scoreColor = PdfColors.teal800;
    String scoreStatus = 'CLEAR TITLE — HIGH CONFIDENCE';
    if (score < 50) {
      scoreColor = PdfColors.red800;
      scoreStatus = 'DEFECTIVE TITLE — HIGH RISK';
    } else if (score < 80) {
      scoreColor = PdfColors.amber800;
      scoreStatus = 'TITLE REQUIRES ATTENTION & RECTIFICATION';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(search, nowFormatted, advocateName),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),

          // 1. Property Summary Box
          _buildPropertySummary(search),
          pw.SizedBox(height: 16),

          // 2. Title Health Score Banner
          _buildHealthBanner(score, scoreStatus, scoreColor, criticalFindings.length, warningFindings.length, passedFindings.length),
          pw.SizedBox(height: 20),

          // 3. 30-Year Ownership Chain (Chronological Timeline)
          _buildSectionHeading('1. 30-Year Ownership Chain (Chain of Title)'),
          pw.SizedBox(height: 8),
          if (chainLinks.isEmpty)
            pw.Text(
              'No chronological chain links recorded yet. Ensure registered deeds are uploaded.',
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
            )
          else
            _buildChainTable(chainLinks, dateFormat),
          pw.SizedBox(height: 20),

          // 4. Critical Red Flags & Inconsistencies
          if (criticalFindings.isNotEmpty) ...[
            _buildSectionHeading('2. Critical Red Flags & Title Inconsistencies', color: PdfColors.red800),
            pw.SizedBox(height: 8),
            _buildFindingsTable(criticalFindings, PdfColors.red800),
            pw.SizedBox(height: 20),
          ],

          // 5. Warnings & Due Diligence Cautions
          if (warningFindings.isNotEmpty) ...[
            _buildSectionHeading('3. Discrepancies & Verification Warnings', color: PdfColors.amber800),
            pw.SizedBox(height: 8),
            _buildFindingsTable(warningFindings, PdfColors.amber800),
            pw.SizedBox(height: 20),
          ],

          // 6. Passed Statutory Checks
          _buildSectionHeading('4. Verified Due Diligence Checks (${passedFindings.length} Passed)', color: PdfColors.teal800),
          pw.SizedBox(height: 8),
          _buildPassedChecksSummary(passedFindings),
          pw.SizedBox(height: 20),

          // 7. Verified Document Inventory
          _buildSectionHeading('5. Verified Document Inventory (${documents.length} Documents)'),
          pw.SizedBox(height: 8),
          _buildDocumentInventory(documents),
          pw.SizedBox(height: 24),

          // 8. Advocate's Final Legal Opinion
          _buildSectionHeading("6. Advocate's Final Title Opinion & Advice"),
          pw.SizedBox(height: 8),
          _buildOpinionBox(advocateOpinion ?? search.advocateOpinion),
          pw.SizedBox(height: 32),

          // 9. Advocate Signature & Professional Disclaimer
          _buildSignatureBlock(advocateName, nowFormatted),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Title_Health_Report_${search.surveyNumber.replaceAll('/', '_')}.pdf',
    );
  }

  static pw.Widget _buildHeader(TitleSearch search, String dateStr, String? advocateName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CASEFLOW LEGAL DUE DILIGENCE REPORT',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
              pw.Text(
                'Property Title Chain Inconsistency Detector',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Date: $dateStr',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
              ),
              if (advocateName != null && advocateName.isNotEmpty)
                pw.Text(
                  'Advocate: $advocateName',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'CaseFlow Legal Suite · Confidential Title Search Opinion',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPropertySummary(TitleSearch s) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PROPERTY IDENTIFICATION',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('Survey No: ${s.surveyNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
              pw.Expanded(
                child: pw.Text('Extent: ${s.extentFormatted}', style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.Expanded(
                child: pw.Text('Village: ${s.village}', style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('Taluk: ${s.taluk}', style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.Expanded(
                child: pw.Text('District: ${s.district}', style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.Expanded(
                child: pw.Text('Status: ${s.status.toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHealthBanner(
    int score,
    String status,
    PdfColor color,
    int criticalCount,
    int warningCount,
    int passedCount,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '$score%',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.Text('HEALTH', style: const pw.TextStyle(fontSize: 7, color: PdfColors.white)),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  status,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '18 Cross-Reference Checks Performed Across Title Chain & Revenue Registers',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    _buildPill('$criticalCount Red Flags', PdfColors.red800),
                    pw.SizedBox(width: 6),
                    _buildPill('$warningCount Discrepancies', PdfColors.amber800),
                    pw.SizedBox(width: 6),
                    _buildPill('$passedCount Checks Passed', PdfColors.teal800),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPill(String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildSectionHeading(String title, {PdfColor color = PdfColors.indigo900}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: color, width: 1)),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color),
      ),
    );
  }

  static pw.Widget _buildChainTable(List<TitleChainLink> links, DateFormat dateFormat) {
    return pw.TableHelper.fromTextArray(
      headers: ['#', 'Year', 'Doc No / SRO', 'Transaction', 'Seller / Transferor', 'Buyer / Transferee', 'Survey / Extent'],
      data: links.map((l) {
        final year = l.transactionDate != null ? dateFormat.format(l.transactionDate!) : 'N/A';
        final docRef = '${l.documentNumber ?? "—"}\n(${l.sro ?? "SRO"})';
        final fromName = l.fromParty != null ? (l.fromParty!['name'] ?? '—') : '—';
        final toName = l.toParty != null ? (l.toParty!['name'] ?? '—') : '—';
        final extent = '${l.surveyNumber ?? "—"}\n${l.extent ?? "—"} ${l.extentUnit ?? ""}';
        return [
          l.linkOrder.toString(),
          year,
          docRef,
          l.transactionType.toUpperCase(),
          fromName,
          toName,
          extent,
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.all(5),
    );
  }

  static pw.Widget _buildFindingsTable(List<TitleFinding> items, PdfColor highlightColor) {
    return pw.Column(
      children: items.map((f) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: highlightColor, width: 0.8),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    f.checkName,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: highlightColor),
                  ),
                  pw.Text(
                    f.severity.toUpperCase(),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: highlightColor),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(f.description, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900)),
              if (f.recommendation != null) ...[
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  child: pw.Text(
                    'Recommended Action: ${f.recommendation}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildPassedChecksSummary(List<TitleFinding> passed) {
    if (passed.isEmpty) {
      return pw.Text('No automated checks have passed yet.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700));
    }
    return pw.Wrap(
      spacing: 6,
      runSpacing: 4,
      children: passed.map((p) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.teal700, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text('✓ ${p.checkName}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.teal900)),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildDocumentInventory(List<TitleDocument> docs) {
    if (docs.isEmpty) {
      return pw.Text('No documents uploaded.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700));
    }
    return pw.TableHelper.fromTextArray(
      headers: ['Type', 'File Name', 'OCR Status', 'Confidence'],
      data: docs.map((d) {
        final conf = d.extractionConfidence != null ? '${(d.extractionConfidence! * 100).toInt()}%' : 'N/A';
        return [
          d.documentLabel ?? d.humanReadableType,
          d.fileName ?? '—',
          d.extractionStatus.toUpperCase(),
          conf,
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.all(4),
    );
  }

  static pw.Widget _buildOpinionBox(String? opinion) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.indigo900, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            opinion != null && opinion.trim().isNotEmpty
                ? opinion.trim()
                : 'Advocate has reviewed the title chain, parent deeds, encumbrance records, and patta extracts. Subject to the rectifications noted in Section 2, the title is advised accordingly.',
            style: const pw.TextStyle(fontSize: 9.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureBlock(String? advocateName, String dateStr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(height: 40),
              pw.Container(height: 1, color: PdfColors.grey800),
              pw.SizedBox(height: 4),
              pw.Text(
                advocateName != null && advocateName.isNotEmpty ? advocateName : 'Advocate & Legal Consultant',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.Text('Bar Council of India / High Court of Madras', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'DISCLAIMER: This title search analysis is an AI-assisted due diligence report generated via CaseFlow for the examining Advocate. Legal validity is contingent on the original documents verified at the respective Sub-Registrar Office, Taluk Revenue Office, and jurisdictional courts under the Transfer of Property Act 1882 and Registration Act 1908.',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
        ),
      ],
    );
  }
}
