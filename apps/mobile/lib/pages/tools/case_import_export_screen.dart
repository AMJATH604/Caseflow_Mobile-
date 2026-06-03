import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/case_export_service.dart';
import '../../services/case_import_service.dart';
import '../../services/providers.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class CaseImportExportScreen extends ConsumerStatefulWidget {
  const CaseImportExportScreen({super.key});

  @override
  ConsumerState<CaseImportExportScreen> createState() =>
      _CaseImportExportScreenState();
}

class _CaseImportExportScreenState extends ConsumerState<CaseImportExportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCaseId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.cardShadow,
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.primary,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "Export",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "Import",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildExportTab(), _buildImportTab()],
          ),
        ),
      ],
    );
  }

  // ─── EXPORT TAB ─────────────────────────────────────────

  Widget _buildExportTab() {
    final casesAsync = ref.watch(casesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Case selector
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.upload_file_rounded,
                        color: Color(0xFF1E293B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Export Case",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Select a case to export its complete data.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                casesAsync.when(
                  data:
                      (cases) => DropdownButtonFormField<String>(
                        initialValue: _selectedCaseId,
                        decoration: InputDecoration(
                          labelText: "Select Case",
                          prefixIcon: const Icon(Icons.work_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        items:
                            cases
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      c.caseTitle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _selectedCaseId = v),
                      ),
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text("Error: $e"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Export actions
          if (_selectedCaseId != null) ...[
            _buildExportCard(
              icon: Icons.picture_as_pdf_rounded,
              title: "Export as PDF",
              subtitle:
                  "Professional report with all case details, hearings, payments & documents",
              gradient: const [Color(0xFFe74c3c), Color(0xFFc0392b)],
              onTap: _isProcessing ? null : () => _exportAsPdf(),
            ),
            const SizedBox(height: 12),
            _buildExportCard(
              icon: Icons.data_object_rounded,
              title: "Export as JSON",
              subtitle:
                  "Full data backup — can be re-imported into CaseFlow later",
              gradient: const [Color(0xFF27ae60), Color(0xFF2ecc71)],
              onTap: _isProcessing ? null : () => _exportAsJson(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1E293B), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (_isProcessing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.7),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  // ─── IMPORT TAB ─────────────────────────────────────────

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          _buildImportCard(
            icon: Icons.account_balance_rounded,
            title: "Import from eCourts",
            subtitle: "Import case data from eCourts mycases.txt export file",
            gradient: const [Color(0xFF2980b9), Color(0xFF3498db)],
            filetype: "txt",
            onTap: _isProcessing ? null : () => _importFromECourts(),
          ),
          const SizedBox(height: 16),
          _buildImportCard(
            icon: Icons.restore_rounded,
            title: "Restore from CaseFlow Backup",
            subtitle: "Import a previously exported .caseflow.json backup file",
            gradient: const [Color(0xFF8e44ad), Color(0xFF9b59b6)],
            filetype: "json",
            onTap: _isProcessing ? null : () => _importFromCaseFlow(),
          ),
          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFFCC02).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "How to export from eCourts?",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "1. Open eCourts Services app\n"
                        "2. Go to My Cases → Saved Cases\n"
                        "3. Tap the Export button\n"
                        "4. Save the mycases.txt file\n"
                        "5. Use it here to import",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required String filetype,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF1E293B), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: gradient[0].withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ".$filetype",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: gradient[0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isProcessing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.file_upload_outlined,
                color: Colors.grey[400],
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  // ─── ACTIONS ────────────────────────────────────────────

  Future<void> _exportAsPdf() async {
    if (_selectedCaseId == null) return;
    setState(() => _isProcessing = true);

    try {
      final data = await CaseExportService.fetchFullCaseData(_selectedCaseId!);
      await CaseExportService.exportAsPdf(
        caseModel: data['case'] as CaseModel,
        hearings: data['hearings'] as List<Hearing>,
        payments: data['payments'] as List<Payment>,
        efilings: data['efilings'] as List<EFilingRecord>,
        documents: data['documents'] as List<Map<String, dynamic>>,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportAsJson() async {
    if (_selectedCaseId == null) return;
    setState(() => _isProcessing = true);

    try {
      final data = await CaseExportService.fetchFullCaseData(_selectedCaseId!);
      final jsonStr = CaseExportService.exportAsJsonString(
        caseModel: data['case'] as CaseModel,
        hearings: data['hearings'] as List<Hearing>,
        payments: data['payments'] as List<Payment>,
        efilings: data['efilings'] as List<EFilingRecord>,
      );

      final caseModel = data['case'] as CaseModel;
      final dir = await getTemporaryDirectory();
      final fileName =
          '${caseModel.caseTitle.replaceAll(RegExp(r'[^\w]'), '_')}.caseflow.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'CaseFlow Backup: ${caseModel.caseTitle}');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("JSON backup exported!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importFromECourts() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null)
      return;

    setState(() => _isProcessing = true);

    try {
      final content = await File(result.files.first.path!).readAsString();
      final cases = CaseImportService.parseECourtsTxt(content);

      if (cases.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No cases found in the file. Check the format."),
            ),
          );
        }
        return;
      }

      // Show preview dialog
      if (mounted) {
        final roles = await _showECourtsPreview(cases);
        if (roles != null && roles.isNotEmpty) {
          // Filter only the selected cases (roles only contains selected indices)
          final selectedCases = <Map<String, String>>[];
          final selectedRoles = <int, String>{};
          for (final entry in roles.entries) {
            selectedRoles[selectedCases.length] = entry.value;
            selectedCases.add(cases[entry.key]);
          }
          // Use BATCH import — fetches all data ONCE instead of per-case
          final importedIds = await CaseImportService.batchImportECourtsCases(
            selectedCases,
            selectedRoles,
          );

          // Data refresh will trigger UI update
          ref.read(dataRefreshProvider.notifier).state++;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "${importedIds.length} case(s) imported/synced! Redirecting to Dashboard...",
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              context.go('/');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Import failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importFromCaseFlow() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null)
      return;

    setState(() => _isProcessing = true);

    try {
      final content = await File(result.files.first.path!).readAsString();
      final data = CaseImportService.parseCaseFlowJson(content);

      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid CaseFlow backup file.")),
          );
        }
        return;
      }

      // Show preview
      if (mounted) {
        final confirmed = await _showJsonPreview(data);
        if (confirmed == true) {
          await CaseImportService.importCaseFlowJson(data);
          // ── FORCE GLOBAL REFRESH so dashboard shows data immediately ──
          ref.read(dataRefreshProvider.notifier).state++;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Case restored successfully! Redirecting..."),
                backgroundColor: Colors.green,
              ),
            );
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) context.go('/');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Import failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── PREVIEW DIALOGS ──────────────────────────────────

  Future<Map<int, String>?> _showECourtsPreview(
    List<Map<String, String>> cases,
  ) {
    // Get existing CNRs to identify "Sync" vs "New"
    final existingCases = ref.read(casesProvider).value ?? [];
    final existingCnrs =
        existingCases.map((c) => c.cnrNumber).whereType<String>().toSet();

    // Map to store user's role choice for each case index
    final Map<int, String> selectedRoles = {};
    // Map to store whether each case is selected for import
    final Map<int, bool> selectedCases = {};
    for (int i = 0; i < cases.length; i++) {
      selectedRoles[i] = 'petitioner';
      selectedCases[i] = true; // All selected by default
    }

    return showDialog<Map<int, String>>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final selectedCount = selectedCases.values.where((v) => v).length;
              final allSelected = selectedCount == cases.length;

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.account_balance, color: Color(0xFF2980b9)),
                    const SizedBox(width: 8),
                    const Text("eCourts Import Preview"),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select All / Deselect All row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$selectedCount of ${cases.length} selected",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.blueGrey[700],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                final newValue = !allSelected;
                                for (int i = 0; i < cases.length; i++) {
                                  selectedCases[i] = newValue;
                                }
                              });
                            },
                            icon: Icon(
                              allSelected ? Icons.deselect : Icons.select_all,
                              size: 16,
                            ),
                            label: Text(
                              allSelected ? "Deselect All" : "Select All",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF2980b9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 350),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: cases.length,
                          itemBuilder: (_, i) {
                            final c = cases[i];
                            final cnr = c['cnr_number'];
                            final isSync =
                                cnr != null && existingCnrs.contains(cnr);
                            final currentRole = selectedRoles[i];
                            final isSelected = selectedCases[i] ?? true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    !isSelected
                                        ? Colors.grey[100]
                                        : isSync
                                        ? const Color(0xFFF0FFF4)
                                        : const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      !isSelected
                                          ? Colors.grey.withValues(alpha: 0.3)
                                          : isSync
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : const Color(
                                            0xFF2980b9,
                                          ).withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Checkbox for selection
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Checkbox(
                                          value: isSelected,
                                          onChanged: (val) {
                                            setDialogState(
                                              () =>
                                                  selectedCases[i] =
                                                      val ?? true,
                                            );
                                          },
                                          activeColor: const Color(0xFF2980b9),
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c['case_title'] ?? 'Unknown Case',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color:
                                                !isSelected
                                                    ? Colors.grey
                                                    : isSync
                                                    ? Colors.green[900]
                                                    : const Color(0xFF1A237E),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isSync
                                                  ? Colors.green[100]
                                                  : Colors.blue[100],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          isSync ? "SYNC" : "NEW",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isSync
                                                    ? Colors.green[800]
                                                    : Colors.blue[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(height: 10),
                                    // Role Switcher
                                    Row(
                                      children: [
                                        const Text(
                                          "Representing:",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SegmentedButton<String>(
                                            segments: const [
                                              ButtonSegment(
                                                value: 'petitioner',
                                                label: Text(
                                                  "Petitioner",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              ButtonSegment(
                                                value: 'respondent',
                                                label: Text(
                                                  "Respondent",
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            selected: {currentRole!},
                                            onSelectionChanged: (val) {
                                              setDialogState(
                                                () =>
                                                    selectedRoles[i] =
                                                        val.first,
                                              );
                                            },
                                            style: SegmentedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20, thickness: 0.5),
                                    if (c['petitioner'] != null)
                                      _previewDetailRow(
                                        Icons.person_rounded,
                                        "Petitioner: ${c['petitioner']}",
                                        isBold: currentRole == 'petitioner',
                                      ),
                                    if (c['respondent'] != null)
                                      _previewDetailRow(
                                        Icons.person_off_rounded,
                                        "Respondent: ${c['respondent']}",
                                        isBold: currentRole == 'respondent',
                                      ),
                                    if (c['cnr_number'] != null)
                                      _previewDetailRow(
                                        Icons.fingerprint_rounded,
                                        "CNR: ${c['cnr_number']}",
                                      ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          selectedCount > 0
                              ? const Color(0xFF2980b9)
                              : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        selectedCount > 0
                            ? () {
                              // Only pass selected cases
                              final filteredRoles = <int, String>{};
                              for (final entry in selectedRoles.entries) {
                                if (selectedCases[entry.key] == true) {
                                  filteredRoles[entry.key] = entry.value;
                                }
                              }
                              Navigator.pop(ctx, filteredRoles);
                            }
                            : null,
                    child: Text("Import $selectedCount Case(s)"),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<bool?> _showJsonPreview(Map<String, dynamic> data) {
    final caseData = data['case'] as Map<String, dynamic>;
    final summary = CaseImportService.getImportSummary(data);

    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.restore, color: Color(0xFF8e44ad)),
                const SizedBox(width: 8),
                const Text("Restore Preview"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caseData['case_title'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (caseData['case_number'] != null)
                        Text(
                          "No: ${caseData['case_number']}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (caseData['court_name'] != null)
                        Text(
                          "Court: ${caseData['court_name']}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Will import:",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _importStatRow(Icons.gavel, "Hearings", summary['hearings']!),
                _importStatRow(Icons.payment, "Payments", summary['payments']!),
                _importStatRow(
                  Icons.description,
                  "E-Filing Records",
                  summary['efiling_records']!,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8e44ad),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Restore Case"),
              ),
            ],
          ),
    );
  }

  Widget _importStatRow(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:
                  count > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: count > 0 ? Colors.green[700] : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewDetailRow(IconData icon, String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isBold ? AppTheme.primary : Colors.blueGrey[400],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: isBold ? Colors.black87 : Colors.blueGrey[700],
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
