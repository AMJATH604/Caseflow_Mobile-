import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/title_search_models.dart';
import '../../services/providers.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class TitleSearchDetailScreen extends ConsumerStatefulWidget {
  final String searchId;
  const TitleSearchDetailScreen({super.key, required this.searchId});

  @override
  ConsumerState<TitleSearchDetailScreen> createState() =>
      _TitleSearchDetailScreenState();
}

class _TitleSearchDetailScreenState extends ConsumerState<TitleSearchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAnalyzing = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    setState(() => _isAnalyzing = true);
    try {
      final res = await SupabaseService.triggerTitleAnalysis(widget.searchId);
      ref.invalidate(titleSearchDetailProvider(widget.searchId));
      ref.invalidate(titleFindingsProvider(widget.searchId));
      ref.invalidate(titleChainLinksProvider(widget.searchId));

      if (mounted) {
        final score = res['health_score'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Title Analysis Complete! Health Score: $score%'),
            backgroundColor: const Color(0xFF0D9488),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _pickAndUploadDoc(String docType, String docLabel) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
      return;
    }

    final file = result.files.first;
    setState(() => _isUploading = true);

    try {
      await SupabaseService.uploadTitleDocument(
        searchId: widget.searchId,
        documentType: docType,
        documentLabel: docLabel,
        fileBytes: file.bytes!,
        fileName: file.name,
      );

      ref.invalidate(titleDocumentsProvider(widget.searchId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$docLabel uploaded! AI extraction started in background.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(titleSearchDetailProvider(widget.searchId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: searchAsync.when(
          data: (s) => Text(
            s.displayName,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Title Due-Diligence'),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(titleSearchDetailProvider(widget.searchId));
              ref.invalidate(titleDocumentsProvider(widget.searchId));
              ref.invalidate(titleFindingsProvider(widget.searchId));
              ref.invalidate(titleChainLinksProvider(widget.searchId));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D9488),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF0D9488),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Health & Checks'),
            Tab(text: 'Ownership Chain'),
            Tab(text: 'Documents (OCR)'),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _runAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            label: Text(
              _isAnalyzing ? 'Analyzing 18 Checks...' : 'Run Title Chain Analysis',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: searchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (search) => TabBarView(
          controller: _tabController,
          children: [
            _buildHealthTab(search),
            _buildChainTab(),
            _buildDocumentsTab(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 1: HEALTH SCORE & THE 18 CROSS-REFERENCE CHECKS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHealthTab(TitleSearch search) {
    final findingsAsync = ref.watch(titleFindingsProvider(widget.searchId));

    Color scoreColor = Colors.grey;
    String scoreStatus = 'Not Analyzed Yet';
    if (search.healthScore != null) {
      if (search.healthScore! >= 80) {
        scoreColor = const Color(0xFF10B981);
        scoreStatus = 'CLEAN TITLE — LOW RISK';
      } else if (search.healthScore! >= 60) {
        scoreColor = const Color(0xFFF59E0B);
        scoreStatus = 'ATTENTION REQUIRED — MODERATE RISK';
      } else {
        scoreColor = const Color(0xFFEF4444);
        scoreStatus = 'CRITICAL DEFECTS — HIGH RISK';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
        children: [
          // Health Score Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scoreColor.withOpacity(0.12), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scoreColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: (search.healthScore ?? 0) / 100.0,
                        backgroundColor: Colors.grey.shade200,
                        color: scoreColor,
                        strokeWidth: 8,
                      ),
                    ),
                    Text(
                      search.healthScore != null ? '${search.healthScore}%' : '--',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
                    children: [
                      Text(
                        scoreStatus,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: scoreColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Survey No. ${search.surveyNumber} · ${search.village}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statBadge('${search.criticalCount} Red Flags', Colors.red),
                          const SizedBox(width: 6),
                          _statBadge('${search.warningCount} Warnings', Colors.amber.shade800),
                          const SizedBox(width: 6),
                          _statBadge('${search.passedCount} Passed', Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Cross-Reference Findings',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),

          findingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading findings: $err'),
            data: (findings) {
              if (findings.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.playlist_add_check_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'No Inconsistencies Generated Yet',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload documents and tap "Run Title Chain Analysis" below.',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: findings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) => _buildFindingCard(findings[idx]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildFindingCard(TitleFinding finding) {
    Color bannerColor = Colors.green;
    IconData icon = Icons.check_circle_outline_rounded;

    if (finding.isCritical) {
      bannerColor = Colors.red;
      icon = Icons.cancel_outlined;
    } else if (finding.isWarning) {
      bannerColor = Colors.amber.shade800;
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
            children: [
              Icon(icon, color: bannerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.checkName,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: bannerColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bannerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  finding.severity.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: bannerColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            finding.description,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary),
          ),
          if (finding.recommendation != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Action: ${finding.recommendation}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (finding.legalReference != null) ...[
            const SizedBox(height: 6),
            Text(
              'Ref: ${finding.legalReference}',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 2: 30-YEAR CHRONOLOGICAL CHAIN OF TITLE TIMELINE
  // ─────────────────────────────────────────────────────────────────
  Widget _buildChainTab() {
    final linksAsync = ref.watch(titleChainLinksProvider(widget.searchId));

    return linksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (links) {
        if (links.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timeline_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'No Chain of Title Created',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upload deeds and tap "Run Title Chain Analysis" to generate the 30-year ownership timeline.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: links.length,
          itemBuilder: (ctx, idx) {
            final link = links[idx];
            final isLast = idx == links.length - 1;

            return Row(
              crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
              children: [
                // Timeline column
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D9488),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${link.linkOrder}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 110,
                        color: const Color(0xFF0D9488).withOpacity(0.3),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Card details
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                link.transactionType.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (link.transactionDate != null)
                              Text(
                                '${link.transactionDate!.day}/${link.transactionDate!.month}/${link.transactionDate!.year}',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${link.fromName}  ➔  ${link.toName}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.primary,
                          ),
                        ),
                        if (link.documentNumber != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Doc No: ${link.documentNumber} · SRO: ${link.subRegistrarOffice ?? "SRO"}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                        if (link.surveyNumber != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Survey No: ${link.surveyNumber} · Extent: ${link.extent ?? ""} ${link.extentUnit ?? ""}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.teal.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 3: DOCUMENTS & AI OCR EXTRACTIONS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildDocumentsTab() {
    final docsAsync = ref.watch(titleDocumentsProvider(widget.searchId));

    return Column(
      children: [
        // Upload Button Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                'Uploaded Documents',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (val) {
                  final labels = {
                    'sale_deed': 'Current Sale Deed',
                    'parent_deed': 'Parent Deed',
                    'encumbrance_certificate': 'Encumbrance Certificate (EC)',
                    'patta': 'Patta / Chitta',
                    'legal_heir_certificate': 'Legal Heir Certificate',
                    'partition_deed': 'Partition Deed',
                    'gift_deed': 'Gift Deed',
                    'fmb_sketch': 'FMB Sketch',
                  };
                  _pickAndUploadDoc(val, labels[val] ?? 'Document');
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'sale_deed', child: Text('📄 Current Sale Deed')),
                  const PopupMenuItem(value: 'parent_deed', child: Text('📄 Parent Deed')),
                  const PopupMenuItem(value: 'encumbrance_certificate', child: Text('📑 Encumbrance Cert (EC)')),
                  const PopupMenuItem(value: 'patta', child: Text('📜 Patta / Chitta')),
                  const PopupMenuItem(value: 'legal_heir_certificate', child: Text('👥 Legal Heir Certificate')),
                  const PopupMenuItem(value: 'partition_deed', child: Text('📜 Partition Deed')),
                  const PopupMenuItem(value: 'gift_deed', child: Text('🎁 Gift Deed')),
                  const PopupMenuItem(value: 'fmb_sketch', child: Text('📐 FMB Sketch')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Upload Document',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isUploading) const LinearProgressIndicator(color: Color(0xFF0D9488)),

        Expanded(
          child: docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (docs) {
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No Documents Uploaded',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Upload Sale Deeds, EC, Patta, or Legal Heir Certs to enable AI extraction.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) => _buildDocCard(docs[idx]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDocCard(TitleDocument doc) {
    Color statusColor = Colors.orange;
    String statusLabel = 'AI Processing';
    if (doc.extractionStatus == 'completed') {
      statusColor = Colors.green;
      statusLabel = 'Extracted (${((doc.extractionConfidence ?? 0.9) * 100).toInt()}%)';
    } else if (doc.extractionStatus == 'failed') {
      statusColor = Colors.red;
      statusLabel = 'Extraction Failed';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: Color(0xFF0D9488), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossCrossCrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.documentLabel ?? doc.humanReadableType,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        doc.fileName ?? 'document.pdf',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (doc.rawText != null && doc.rawText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  doc.rawText!,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
