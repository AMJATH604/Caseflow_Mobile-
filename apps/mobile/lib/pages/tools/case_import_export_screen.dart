import 'dart:io';
import 'package:flutter/material.dart';
import '../../components/case_picker_field.dart';
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
import '../../utils/party_labels.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CaseImportExportScreen extends ConsumerStatefulWidget {
  const CaseImportExportScreen({super.key});

  @override
  ConsumerState<CaseImportExportScreen> createState() =>
      _CaseImportExportScreenState();
}

class _CaseImportExportScreenState
    extends ConsumerState<CaseImportExportScreen> {
  // Export and Import are each a short sequence — pick a thing, pick a
  // format, run it — so the screen is laid out as numbered steps rather than
  // two tabs of stacked cards. Step 2 stays dimmed until step 1 is answered,
  // which is what tells the user there is a next step at all.
  bool _isImportMode = false;

  String? _selectedCaseId;
  CaseModel? _selectedCase;
  String _exportFormat = 'pdf';
  String _importSource = 'ecourts';
  bool _showECourtsHelp = false;

  bool _isProcessing = false;

  // ─── PALETTE ────────────────────────────────────────────
  // Near-monochrome with a single accent. The previous design gave every
  // action its own saturated gradient, which both flattened the hierarchy
  // (nothing could stand out when everything shouted) and produced unreadable
  // dark-on-bright text where a light-card colour had been pasted onto one.

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface => _isDark ? const Color(0xFF111827) : Colors.white;
  Color get _sunken =>
      _isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
  Color get _border => _isDark ? Colors.white12 : const Color(0xFFE2E8F0);
  Color get _ink => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _muted => _isDark ? Colors.white60 : const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: _buildModeSwitch(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
            child: _isImportMode ? _buildImportFlow() : _buildExportFlow(),
          ),
        ),
        _buildActionBar(),
      ],
    );
  }

  // ─── MODE SWITCH ────────────────────────────────────────

  Widget _buildModeSwitch() {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: _sunken,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _buildModeTab('Export', Icons.ios_share_rounded, false),
          _buildModeTab('Import', Icons.download_rounded, true),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, IconData icon, bool importMode) {
    final selected = _isImportMode == importMode;
    return Expanded(
      child: GestureDetector(
        onTap:
            _isProcessing
                ? null
                : () => setState(() => _isImportMode = importMode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: 9.h),
          decoration: BoxDecoration(
            color: selected ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(7.r),
            border: Border.all(color: selected ? _border : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15.sp,
                color: selected ? AppTheme.accent : _muted,
              ),
              SizedBox(width: 7.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _ink : _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── STEP SCAFFOLDING ───────────────────────────────────

  /// A numbered step with a rail down its left edge. [enabled] false dims the
  /// whole step without removing it, so the shape of the flow stays visible
  /// before the earlier steps are answered.
  Widget _buildStep({
    required int number,
    required String title,
    String? caption,
    required Widget child,
    bool enabled = true,
    bool isLast = false,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24.w,
                  height: 24.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        enabled
                            ? AppTheme.accent.withValues(alpha: 0.12)
                            : _sunken,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          enabled
                              ? AppTheme.accent.withValues(alpha: 0.35)
                              : _border,
                    ),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: enabled ? AppTheme.accent : _muted,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: _border,
                    ),
                  ),
              ],
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: _muted,
                      ),
                    ),
                    if (caption != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        caption,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                    SizedBox(height: 12.h),
                    IgnorePointer(ignoring: !enabled, child: child),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A selectable option row. Selection is shown by the accent border and the
  /// radio dot, not by filling the row with colour.
  Widget _buildChoiceRow({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withValues(alpha: 0.05) : _surface,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: selected ? AppTheme.accent : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20.sp, color: selected ? AppTheme.accent : _muted),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: _sunken,
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(color: _border),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: _muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Container(
              width: 18.w,
              height: 18.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.accent : _border,
                  width: 1.5,
                ),
              ),
              child:
                  selected
                      ? Center(
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── EXPORT FLOW ────────────────────────────────────────

  Widget _buildExportFlow() {
    final casesAsync = ref.watch(casesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(
          number: 1,
          title: 'Choose a case',
          child: casesAsync.when(
            data:
                (cases) =>
                    _selectedCase == null
                        ? CasePickerField(
                          cases: cases,
                          value: _selectedCaseId,
                          sheetTitle: 'Select case to export',
                          decoration: InputDecoration(
                            hintText: 'Search by case number or party',
                            hintStyle: TextStyle(
                              fontSize: 13.sp,
                              color: _muted,
                            ),
                            prefixIcon: Icon(Icons.search_rounded, size: 18.sp),
                            filled: true,
                            fillColor: _surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                              borderSide: BorderSide(color: _border),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 13.h,
                            ),
                          ),
                          onSelected:
                              (c) => setState(() {
                                _selectedCaseId = c.id;
                                _selectedCase = c;
                              }),
                        )
                        : _buildSelectedCaseRow(),
            loading: () => _buildInlineLoader(),
            error: (e, _) => _buildInlineError('Could not load your cases.'),
          ),
        ),
        _buildStep(
          number: 2,
          title: 'Choose a format',
          enabled: _selectedCase != null,
          isLast: true,
          child: Column(
            children: [
              _buildChoiceRow(
                selected: _exportFormat == 'pdf',
                icon: Icons.picture_as_pdf_outlined,
                title: 'PDF report',
                subtitle:
                    'Readable summary of the case, hearings, payments and documents. For sharing or filing.',
                badge: '.pdf',
                onTap: () => setState(() => _exportFormat = 'pdf'),
              ),
              _buildChoiceRow(
                selected: _exportFormat == 'json',
                icon: Icons.data_object_rounded,
                title: 'CaseFlow backup',
                subtitle:
                    'Complete data backup that can be restored into CaseFlow later.',
                badge: '.json',
                onTap: () => setState(() => _exportFormat = 'json'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCaseRow() {
    final c = _selectedCase!;
    final number = CaseLabels.number(c);

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18.sp, color: AppTheme.accent),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (number != null) ...[
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: AppTheme.accent,
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],
                Text(
                  CaseLabels.title(c),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          TextButton(
            onPressed:
                _isProcessing
                    ? null
                    : () => setState(() {
                      _selectedCase = null;
                      _selectedCaseId = null;
                    }),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Change', style: TextStyle(fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }

  // ─── IMPORT FLOW ────────────────────────────────────────

  Widget _buildImportFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(
          number: 1,
          title: 'Where is the data from?',
          child: Column(
            children: [
              _buildChoiceRow(
                selected: _importSource == 'ecourts',
                icon: Icons.account_balance_outlined,
                title: 'eCourts export',
                subtitle:
                    'The mycases.txt file saved from the eCourts Services app.',
                badge: '.txt',
                onTap: () => setState(() => _importSource = 'ecourts'),
              ),
              if (_importSource == 'ecourts') _buildECourtsHelp(),
              _buildChoiceRow(
                selected: _importSource == 'caseflow',
                icon: Icons.restore_rounded,
                title: 'CaseFlow backup',
                subtitle:
                    'A .caseflow.json file exported from CaseFlow earlier.',
                badge: '.json',
                onTap: () => setState(() => _importSource = 'caseflow'),
              ),
            ],
          ),
        ),
        _buildStep(
          number: 2,
          title: 'Choose the file',
          caption:
              'Nothing is saved until you have reviewed what the file contains.',
          isLast: true,
          child: _buildFileDropTarget(),
        ),
      ],
    );
  }

  /// Collapsed by default and shown only under the eCourts option — the
  /// instructions used to sit permanently at the bottom of the tab, where they
  /// were equally present whether or not they applied.
  Widget _buildECourtsHelp() {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: _sunken,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showECourtsHelp = !_showECourtsHelp),
            borderRadius: BorderRadius.circular(10.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 15.sp, color: _muted),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Text(
                      'How do I get this file?',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                  Icon(
                    _showECourtsHelp
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18.sp,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (_showECourtsHelp)
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final step in const [
                    'Open the eCourts Services app',
                    'Go to My Cases → Saved Cases',
                    'Tap Export',
                    'Save the mycases.txt file',
                    'Come back here and choose it',
                  ])
                    Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '·  ',
                            style: TextStyle(fontSize: 12.sp, color: _muted),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: _muted,
                                height: 1.4,
                              ),
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

  Widget _buildFileDropTarget() {
    final isECourts = _importSource == 'ecourts';
    final ext = isECourts ? '.txt' : '.json';

    return GestureDetector(
      onTap: _isProcessing ? null : _runAction,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: _sunken,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 28.sp,
              color: AppTheme.accent,
            ),
            SizedBox(height: 10.h),
            Text(
              'Choose a $ext file',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              isECourts ? 'mycases.txt' : 'backup.caseflow.json',
              style: TextStyle(
                fontSize: 11.sp,
                fontFamily: 'monospace',
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACTION BAR ─────────────────────────────────────────

  bool get _canRun =>
      !_isProcessing && (_isImportMode || _selectedCase != null);

  String get _actionLabel {
    if (_isImportMode) {
      return _importSource == 'ecourts'
          ? 'Choose eCourts file'
          : 'Choose backup file';
    }
    return _exportFormat == 'pdf' ? 'Export PDF report' : 'Export backup';
  }

  void _runAction() {
    if (!_canRun) return;
    if (_isImportMode) {
      if (_importSource == 'ecourts') {
        _importFromECourts();
      } else {
        _importFromCaseFlow();
      }
      return;
    }
    if (_exportFormat == 'pdf') {
      _exportAsPdf();
    } else {
      _exportAsJson();
    }
  }

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 46.h,
        child: ElevatedButton(
          onPressed: _canRun ? _runAction : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _sunken,
            disabledForegroundColor: _muted,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          child:
              _isProcessing
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'Working…',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                  : Text(
                    _actionLabel,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
        ),
      ),
    );
  }

  // ─── SMALL STATES ───────────────────────────────────────

  Widget _buildInlineLoader() => Padding(
    padding: EdgeInsets.symmetric(vertical: 18.h),
    child: const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.accent,
        ),
      ),
    ),
  );

  Widget _buildInlineError(String message) => Container(
    padding: EdgeInsets.all(14.r),
    decoration: BoxDecoration(
      color: AppTheme.error.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 17.sp, color: AppTheme.error),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(message, style: TextStyle(fontSize: 12.sp, color: _ink)),
        ),
      ],
    ),
  );

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
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
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
        ).showSnackBar(const SnackBar(content: Text('JSON backup exported!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
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
        result.files.first.path == null) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final content = await File(result.files.first.path!).readAsString();
      final cases = CaseImportService.parseECourtsTxt(content);

      if (cases.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cases found in the file. Check the format.'),
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
          final result = await CaseImportService.batchImportECourtsCases(
            selectedCases,
            selectedRoles,
          );

          // Bumping this rebuilds every provider that watches it — the
          // dashboard stats, the court diary, and (since they now watch it
          // too) the paginated hearings/cases/payments/clients lists.
          ref.read(dataRefreshProvider.notifier).state++;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${result.summary} — opening Dashboard...'),
                backgroundColor:
                    result.hearingsSkipped > 0 ? Colors.orange : Colors.green,
                duration: Duration(seconds: result.hearingsSkipped > 0 ? 4 : 2),
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
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
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
        result.files.first.path == null) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final content = await File(result.files.first.path!).readAsString();
      final data = CaseImportService.parseCaseFlowJson(content);

      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid CaseFlow backup file.')),
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
                content: Text('Case restored successfully! Redirecting...'),
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
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
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
    // Deliberately no default role. Every case used to start as
    // 'petitioner', and since nobody flips ninety radio buttons the client
    // silently became the first name in "X vs Y" — wrong for every case where
    // the advocate acts for the other side. Import stays disabled until each
    // selected case has an answer.
    //
    // The one exception is a case already in the app whose side was an actual
    // answer. The eCourts export carries no advocate names, so the file itself
    // can never say which side the advocate is on — but re-syncing a case the
    // advocate already answered for should not make them answer again.
    //
    // Only cases saved on or after the day that answer became mandatory are
    // trusted. Before it, every import stored 'petitioner' whether or not
    // anyone chose it, and pre-filling from those would quietly bring back the
    // very default that was removed.
    final answeredSince = DateTime(2026, 9, 17);
    final savedRoles = <String, String>{
      for (final c in existingCases)
        if (c.cnrNumber != null && !c.createdAt.isBefore(answeredSince))
          c.cnrNumber!: c.representationType.name,
    };
    final prefilled = <int>{};
    for (int i = 0; i < cases.length; i++) {
      selectedCases[i] = true; // All selected by default
      final saved = savedRoles[cases[i]['cnr_number']];
      if (saved == 'petitioner' || saved == 'respondent') {
        selectedRoles[i] = saved!;
        prefilled.add(i);
      }
    }

    // A full screen, not a dialog: an eCourts export can hold dozens of
    // cases, each needing a tick and a side, and a dialog showed only a few
    // at a time.
    return Navigator.of(context).push<Map<int, String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final selectedCount = selectedCases.values.where((v) => v).length;
              final allSelected = selectedCount == cases.length;
              // Selected cases still missing a side.
              final unanswered = <int>[
                for (int i = 0; i < cases.length; i++)
                  if (selectedCases[i] == true && selectedRoles[i] == null) i,
              ];
              final canImport = selectedCount > 0 && unanswered.isEmpty;

              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  title: const Text('eCourts Import Preview'),
                ),
                body: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select All / Deselect All row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$selectedCount of ${cases.length} selected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
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
                              allSelected ? 'Deselect All' : 'Select All',
                              style: TextStyle(
                                fontSize: 11.sp,
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
                      if (unanswered.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: Colors.orange[700],
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                '${unanswered.length} case(s) still need a side',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 10.h),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.only(bottom: 16.h),
                          itemCount: cases.length,
                          itemBuilder: (_, i) {
                            final c = cases[i];
                            final cnr = c['cnr_number'];
                            final isSync =
                                cnr != null && existingCnrs.contains(cnr);
                            final currentRole = selectedRoles[i];
                            final isSelected = selectedCases[i] ?? true;
                            final labels = PartyLabels.forCase(
                              caseNumber: c['case_number'],
                              caseType: c['case_type'],
                            );

                            return Container(
                              margin: EdgeInsets.only(bottom: 12.h),
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(
                                color:
                                    !isSelected
                                        ? Colors.grey[100]
                                        : isSync
                                        ? const Color(0xFFF0FFF4)
                                        : const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(12.r),
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
                                        width: 28.w,
                                        height: 28.h,
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
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          c['case_title'] ?? 'Unknown Case',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.sp,
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
                                          isSync ? 'SYNC' : 'NEW',
                                          style: TextStyle(
                                            fontSize: 9.sp,
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
                                  // Number and court, always visible: they are
                                  // what decides whether to tick the case at
                                  // all. Two cases can share parties, and a
                                  // transferred case appears once per court
                                  // with the same number, so neither alone is
                                  // enough to tell rows apart.
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 36.w,
                                      top: 3.h,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['case_number'] ?? 'No case number',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                c['case_number'] == null
                                                    ? Colors.orange[800]
                                                    : isSelected
                                                    ? Colors.blueGrey[800]
                                                    : Colors.grey,
                                          ),
                                        ),
                                        if (c['court_name'] != null)
                                          Text(
                                            c['court_name']!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10.5.sp,
                                              color: Colors.blueGrey[500],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    SizedBox(height: 10.h),
                                    // Role switcher, worded for this case's
                                    // type: a civil suit has a plaintiff, a
                                    // cheque complaint a complainant. The
                                    // names are shown on the buttons because
                                    // "I appear for Amjath" needs no
                                    // translation, and translating in the head
                                    // is where the wrong side gets chosen.
                                    Text(
                                      'I appear for:',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            currentRole == null
                                                ? Colors.orange[800]
                                                : Colors.blueGrey[700],
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    SegmentedButton<String>(
                                      emptySelectionAllowed: true,
                                      segments: [
                                        ButtonSegment(
                                          value: 'petitioner',
                                          label: Text(
                                            c['petitioner'] ?? labels.first,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 10.sp),
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: 'respondent',
                                          label: Text(
                                            c['respondent'] ?? labels.second,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 10.sp),
                                          ),
                                        ),
                                      ],
                                      selected:
                                          currentRole == null
                                              ? <String>{}
                                              : {currentRole},
                                      onSelectionChanged: (val) {
                                        setDialogState(() {
                                          selectedRoles[i] = val.first;
                                          // Once changed by hand it is the
                                          // advocate's answer, not the saved
                                          // one, and the hint must not claim
                                          // otherwise.
                                          prefilled.remove(i);
                                        });
                                      },
                                      style: SegmentedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    if (prefilled.contains(i))
                                      Padding(
                                        padding: EdgeInsets.only(top: 5.h),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 13,
                                              color: Colors.green[700],
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              'As you saved it earlier',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                color: Colors.green[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Divider(height: 20.h, thickness: 0.5),
                                    if (c['petitioner'] != null)
                                      _previewDetailRow(
                                        Icons.person_rounded,
                                        "${labels.first}: ${c['petitioner']}",
                                        isBold: currentRole == 'petitioner',
                                      ),
                                    if (c['respondent'] != null)
                                      _previewDetailRow(
                                        Icons.person_off_rounded,
                                        "${labels.second}: ${c['respondent']}",
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
                bottomNavigationBar: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  canImport
                                      ? const Color(0xFF2980b9)
                                      : Colors.grey,
                              foregroundColor: Colors.white,
                              minimumSize: Size(0, 48.h),
                            ),
                            onPressed:
                                canImport
                                    ? () {
                                      // Only pass selected cases
                                      final filteredRoles = <int, String>{};
                                      for (final entry
                                          in selectedRoles.entries) {
                                        if (selectedCases[entry.key] == true) {
                                          filteredRoles[entry.key] =
                                              entry.value;
                                        }
                                      }
                                      Navigator.pop(ctx, filteredRoles);
                                    }
                                    : null,
                            child: Text('Import $selectedCount Case(s)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ),
    );
  }

  Future<bool?> _showJsonPreview(Map<String, dynamic> data) {
    final caseData = data['case'] as Map<String, dynamic>;
    final summary = CaseImportService.getImportSummary(data);

    // Full screen, like the eCourts preview, so both imports look alike.
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (ctx) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            title: const Text('Restore Preview'),
          ),
          body: ListView(
              padding: EdgeInsets.all(16.r),
              children: [
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caseData['case_title'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      if (caseData['case_number'] != null)
                        Text(
                          "No: ${caseData['case_number']}",
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (caseData['court_name'] != null)
                        Text(
                          "Court: ${caseData['court_name']}",
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Will import:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                _importStatRow(Icons.gavel, 'Hearings', summary['hearings']!),
                _importStatRow(Icons.payment, 'Payments', summary['payments']!),
                _importStatRow(
                  Icons.description,
                  'E-Filing Records',
                  summary['efiling_records']!,
                ),
              ],
            ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8e44ad),
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, 48.h),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Restore Case'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _importStatRow(IconData icon, String label, int count) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          SizedBox(width: 8.w),
          Text(label, style: TextStyle(fontSize: 12.sp)),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color:
                  count > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
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
      padding: EdgeInsets.only(top: 4.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isBold ? AppTheme.primary : Colors.blueGrey[400],
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.sp,
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
