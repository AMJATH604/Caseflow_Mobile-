import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/models.dart';
import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import '../../../services/document_tools/server_tools_client.dart';
import '../../../services/providers.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';
import 'save_to_case_sheet.dart';

/// One document of the filing, in filing order.
class _Part {
  String title;
  ToolFile file;
  final int pageCount;
  String source;
  _Part(this.title, this.file, this.pageCount, this.source);
}

/// Common titles for documents in a filing, offered while naming a part.
const _titleSuggestions = [
  'Plaint',
  'Petition',
  'Vakalatnama',
  'Affidavit',
  'Memo of Appearance',
  'Interlocutory Application',
  'List of Documents',
  'Documents',
  'Annexure',
  'Court Fee Receipt',
];

/// Guided preparation of court-ready PDFs: collect the documents in order,
/// apply the court's format (A4, margins, page numbers, index, bookmarks),
/// keep files under the portal's size limit and check the result.
///
/// Opened from a case (files save straight into it) or from Tools.
class PrepareEfilingScreen extends ConsumerStatefulWidget {
  final String? caseId;

  /// Documents to start with, so tests need not drive file pickers.
  @visibleForTesting
  final List<FilingPart> initialDocuments;

  const PrepareEfilingScreen({
    super.key,
    this.caseId,
    this.initialDocuments = const [],
  });

  static Future<void> open(BuildContext context, {String? caseId}) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PrepareEfilingScreen(caseId: caseId)),
      );

  @override
  ConsumerState<PrepareEfilingScreen> createState() => _PrepareEfilingScreenState();
}

class _PrepareEfilingScreenState extends ConsumerState<PrepareEfilingScreen> {
  final List<_Part> _parts = [];
  final CourtPreset _preset = CourtPreset.tamilNaduDistrict;
  bool _fitToA4 = true;
  bool _addMargins = false;
  bool _pageNumbers = true;
  bool _indexPage = true;
  bool _bookmarks = true;
  late final _maxMb = TextEditingController(text: '${_preset.maxFileMb}');
  final _heading = TextEditingController();
  final _subheading = TextEditingController();
  bool _prefilled = false;

  bool _adding = false;
  bool _busy = false;
  FilingResult? _result;
  List<ToolFile>? _files;

  // OCR of scanned documents (runs on the document server).
  final Set<String> _ocrLanguages = {'eng', 'tam'};
  CancelToken? _ocrCancel;
  String? _ocrStatus;
  JobProgress? _ocrProgress;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocuments.isNotEmpty) {
      _add(() async => [
        for (final d in widget.initialDocuments)
          _Part(
            d.title,
            ToolFile('${d.title}.pdf', d.pdf),
            await DocumentToolsService.pageCount(d.pdf),
            'PDF',
          ),
      ]);
    }
  }

  @override
  void dispose() {
    _ocrCancel?.cancel();
    _maxMb.dispose();
    _heading.dispose();
    _subheading.dispose();
    super.dispose();
  }

  /// The case this was opened from, once loaded. [watch] only in build.
  CaseModel? _caseModel({bool watch = false}) {
    final id = widget.caseId;
    if (id == null) return null;
    final provider = caseDetailProvider(id);
    return (watch ? ref.watch(provider) : ref.read(provider)).valueOrNull;
  }

  /// Fills the index heading from the case once it has loaded.
  void _prefill(CaseModel c) {
    if (_heading.text.isEmpty && (c.courtName ?? '').isNotEmpty) {
      _heading.text = c.courtName!.toUpperCase();
    }
    if (_subheading.text.isEmpty) {
      final number = (c.caseNumber ?? '').isNotEmpty ? ' (${c.caseNumber})' : '';
      _subheading.text = '${c.caseTitle}$number';
    }
  }

  // ── Adding documents ─────────────────────────────────────────────

  Future<void> _add(Future<List<_Part>> Function() source) async {
    setState(() => _adding = true);
    try {
      final parts = await source();
      if (mounted) setState(() => _parts.addAll(parts));
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  static String _titleFromFileName(String name) =>
      baseName(name).replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<_Part> _pdfPart(ToolFile file, String source) async {
    final count = await DocumentToolsService.pageCount(file.bytes);
    return _Part(_titleFromFileName(file.name), file, count, source);
  }

  Future<_Part> _imagesPart(List<ToolFile> images, String title, {required bool grey}) async {
    final pdf = await DocumentToolsService.imagesToPdf(
      [for (final i in images) i.bytes],
      prep: ImagePrepOptions(grayscale: grey),
    );
    return _Part(title, ToolFile('$title.pdf', pdf), images.length, grey ? 'Scan · grey' : 'Photos');
  }

  Future<List<_Part>> _fromPdfs() async => [
    for (final f in await DocumentFiles.pickPdfs()) await _pdfPart(f, 'PDF'),
  ];

  Future<List<_Part>> _fromScan() async {
    final pages = await DocumentFiles.scanPages();
    if (pages.isEmpty) return const [];
    return [await _imagesPart(pages, 'Scanned document ${_parts.length + 1}', grey: true)];
  }

  Future<List<_Part>> _fromPhotos() async {
    final images = await DocumentFiles.pickImagesFromGallery();
    if (images.isEmpty) return const [];
    return [await _imagesPart(images, 'Photographs ${_parts.length + 1}', grey: false)];
  }

  Future<List<_Part>> _fromCase() async {
    final caseId = widget.caseId!;
    final docs = await ref.read(caseDocumentsProvider(caseId).future);
    final usable = [
      for (final d in docs)
        if (RegExp(r'\.(pdf|jpe?g|png)$', caseSensitive: false).hasMatch('${d['name']}'))
          '${d['name']}',
    ];
    if (!mounted) return const [];
    final chosen = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CaseFilesSheet(names: usable),
    );
    if (chosen == null || chosen.isEmpty) return const [];
    final parts = <_Part>[];
    for (final name in chosen) {
      final file = await DocumentFiles.fromCase(caseId, name);
      parts.add(
        name.toLowerCase().endsWith('.pdf')
            ? await _pdfPart(file, 'Case file')
            : await _imagesPart([file], _titleFromFileName(name), grey: false),
      );
    }
    return parts;
  }

  Future<void> _rename(_Part part) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _TitleDialog(initial: part.title),
    );
    if (title != null && title.trim().isNotEmpty) {
      setState(() => part.title = title.trim());
    }
  }

  // ── Building ─────────────────────────────────────────────────────

  Future<void> _prepare() async {
    final maxMb = int.tryParse(_maxMb.text.trim());
    if (maxMb == null || maxMb < 1) {
      showToolError(context, const DocumentToolException('Enter the size limit in MB, e.g. 20'));
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await DocumentToolsService.prepareFiling(
        [for (final p in _parts) FilingPart(p.title, p.file.bytes)],
        FilingOptions(
          preset: _preset,
          fitToA4: _fitToA4,
          addMargins: _addMargins,
          pageNumbers: _pageNumbers,
          indexPage: _indexPage,
          bookmarks: _bookmarks,
          maxFileMb: maxMb,
          heading: _heading.text,
          subheading: _subheading.text,
        ),
      );
      final c = _caseModel();
      final base = baseName(safeFileName(c?.caseNumber ?? c?.caseTitle ?? 'Filing'));
      final n = result.files.length;
      setState(() {
        _result = result;
        _files = [
          for (var i = 0; i < n; i++)
            ToolFile(
              n == 1 ? '${base}_eFiling.pdf' : '${base}_eFiling_part${i + 1}of$n.pdf',
              result.files[i].pdf,
            ),
        ];
      });
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// OCRs the documents that have scanned pages, then rebuilds the filing
  /// from the searchable versions.
  Future<void> _ocrAndRebuild(List<int> documents) async {
    final client = ServerToolsClient.shared;
    if (client == null || _ocrLanguages.isEmpty) return;
    final cancel = CancelToken();
    final parts = [for (final i in documents) _parts[i]];
    setState(() => _ocrCancel = cancel);
    try {
      for (var n = 0; n < parts.length; n++) {
        final part = parts[n];
        setState(() {
          _ocrStatus = 'OCR ${n + 1} of ${parts.length}: ${part.title}';
          _ocrProgress = null;
        });
        final output = await client.run(
          'ocr-pdf',
          [part.file],
          options: {
            'languages': [
              for (final l in const ['eng', 'tam', 'hin'])
                if (_ocrLanguages.contains(l)) l,
            ],
            'mode': 'skip',
            'clean_up': true,
          },
          cancel: cancel,
          onProgress: (p) {
            if (mounted) setState(() => _ocrProgress = p);
          },
        );
        part
          ..file = ToolFile(part.file.name, output.file.bytes)
          ..source = '${part.source} · OCR';
      }
      if (!mounted) return;
      setState(() => _ocrStatus = 'Rebuilding the filing…');
      await _prepare();
      if (mounted) showToolMessage(context, 'Scanned pages are now searchable');
    } on DocumentToolException catch (e) {
      if (mounted && !cancel.isCancelled) showToolError(context, e);
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _ocrCancel = null;
          _ocrStatus = null;
          _ocrProgress = null;
        });
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave e-Filing preparation?'),
        content: const Text('The documents you added here will be cleared. Saved files are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = _caseModel(watch: true);
    if (c != null && !_prefilled) {
      // Not during build: changing a controller rebuilds its TextField.
      _prefilled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prefill(c);
      });
    }
    final target = c == null ? null : CaseTarget(c.id, c.caseTitle);

    return PopScope(
      canPop: _parts.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prepare for e-Filing'),
          bottom: c == null
              ? null
              : PreferredSize(
                  preferredSize: Size.fromHeight(22.h),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8.h, left: 16.w, right: 16.w),
                    child: Text(
                      c.caseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.sp, color: mutedText(context)),
                    ),
                  ),
                ),
        ),
        body: SafeArea(
          top: false,
          child: _result == null
              ? _buildSetup()
              : ToolResultView(
                  files: _files!,
                  headline: 'Ready to file · ${_result!.totalPages} pages',
                  caseTarget: target,
                  startOverLabel: 'Back to documents',
                  startOverIcon: Icons.edit_note_rounded,
                  onStartOver: () => setState(() {
                    _result = null;
                    _files = null;
                  }),
                  header: [
                    _ChecksCard(checks: _result!.checks),
                    SizedBox(height: 12.h),
                    if (_result!.documentsWithoutText.isNotEmpty && ServerToolsClient.isConfigured)
                      _OcrCard(
                        documents: [for (final i in _result!.documentsWithoutText) _parts[i].title],
                        languages: _ocrLanguages,
                        onLanguagesChanged: () => setState(() {}),
                        status: _ocrStatus,
                        progress: _ocrProgress,
                        onRun: _ocrCancel == null && !_busy
                            ? () => _ocrAndRebuild(_result!.documentsWithoutText)
                            : null,
                        onCancel: _ocrCancel?.cancel,
                      ),
                    SizedBox(height: 4.h),
                  ],
                  footer: [
                    SizedBox(height: 20.h),
                    for (var i = 0; i < _files!.length; i++)
                      _PortalIndexCard(
                        fileLabel: _files!.length == 1 ? null : 'File ${i + 1} of ${_files!.length}',
                        index: _result!.files[i].index,
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSetup() {
    final totalPages = _parts.fold<int>(0, (sum, p) => sum + p.pageCount);
    return DocToolLayout(
      action: ToolActionButton(
        label: _parts.isEmpty ? 'Add documents to begin' : 'Prepare filing · $totalPages pages',
        icon: Icons.fact_check_rounded,
        busy: _busy,
        onPressed: _parts.isEmpty ? null : _prepare,
      ),
      children: [
        _PresetCard(preset: _preset),
        const SectionLabel('Documents, in filing order'),
        if (_parts.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(
              'Add each document of the filing: plaint or petition, vakalat, affidavit, '
              'documents relied on. Each one becomes an entry in the index.',
              style: TextStyle(fontSize: 12.sp, color: mutedText(context), height: 1.4),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _parts.length,
            onReorder: (from, to) => setState(() {
              if (to > from) to--;
              _parts.insert(to, _parts.removeAt(from));
            }),
            itemBuilder: (context, i) {
              final part = _parts[i];
              return KeyedSubtree(
                key: ObjectKey(part),
                child: InkWell(
                  onTap: () => _rename(part),
                  child: FileCard(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    name: part.title,
                    subtitle:
                        '${part.pageCount} page${part.pageCount == 1 ? '' : 's'} · '
                        '${part.file.sizeLabel} · ${part.source} · tap to rename',
                    actions: [
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _parts.removeAt(i)),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            OutlinedButton.icon(
              onPressed: _adding ? null : () => _add(_fromPdfs),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF'),
            ),
            if (DocumentFiles.canScan)
              OutlinedButton.icon(
                onPressed: _adding ? null : () => _add(_fromScan),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan'),
              ),
            OutlinedButton.icon(
              onPressed: _adding ? null : () => _add(_fromPhotos),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Photos'),
            ),
            if (widget.caseId != null)
              OutlinedButton.icon(
                onPressed: _adding ? null : () => _add(_fromCase),
                icon: const Icon(Icons.folder_shared_outlined),
                label: const Text('Case files'),
              ),
          ],
        ),
        if (_adding)
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: const LinearProgressIndicator(),
          ),
        const SectionLabel('Format'),
        _Toggle(
          title: 'Fit pages to A4',
          subtitle: 'Letter, legal and odd-sized pages are scaled onto A4',
          value: _fitToA4,
          onChanged: (v) => setState(() => _fitToA4 = v),
        ),
        _Toggle(
          title: 'Add court margins',
          subtitle: 'Shrinks pages so 3.5 cm left and 2.5 cm other margins are blank. '
              'Use for scans and photos; typed pleadings usually have margins already.',
          value: _addMargins,
          onChanged: (v) => setState(() {
            _addMargins = v;
            if (v) _fitToA4 = true;
          }),
        ),
        _Toggle(
          title: 'Page numbers',
          subtitle: 'Bottom centre on every page, matching the index',
          value: _pageNumbers,
          onChanged: (v) => setState(() => _pageNumbers = v),
        ),
        _Toggle(
          title: 'Index page',
          subtitle: 'A first page listing each document and its pages',
          value: _indexPage,
          onChanged: (v) => setState(() => _indexPage = v),
        ),
        if (_indexPage) ...[
          SizedBox(height: 4.h),
          TextField(
            controller: _heading,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Court (index heading)',
              hintText: 'e.g. IN THE COURT OF THE DISTRICT MUNSIF, CHENNAI',
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _subheading,
            decoration: const InputDecoration(
              labelText: 'Case (second line)',
              hintText: 'e.g. O.S. No. 12 of 2026',
            ),
          ),
          SizedBox(height: 8.h),
        ],
        _Toggle(
          title: 'Bookmarks',
          subtitle: 'One per document, so the judge can jump between them',
          value: _bookmarks,
          onChanged: (v) => setState(() => _bookmarks = v),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _maxMb,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Largest file the portal accepts (MB)',
            helperText: 'Larger filings are split into parts under this size',
            suffixText: 'MB',
          ),
        ),
      ],
    );
  }
}

/// Offers OCR for the scanned documents: runs on the document server, then
/// the filing is rebuilt so numbers, index and bookmarks stay right.
class _OcrCard extends StatelessWidget {
  final List<String> documents;
  final Set<String> languages;
  final VoidCallback onLanguagesChanged;
  final String? status;
  final JobProgress? progress;
  final VoidCallback? onRun;
  final VoidCallback? onCancel;
  const _OcrCard({
    required this.documents,
    required this.languages,
    required this.onLanguagesChanged,
    required this.status,
    required this.progress,
    required this.onRun,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final running = status != null;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make scanned pages searchable',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4.h),
          Text(
            'OCR ${documents.join(', ')} on the CaseFlow document server, then rebuild '
            'the filing. Choose the languages in these documents:',
            style: TextStyle(fontSize: 11.sp, color: mutedText(context), height: 1.35),
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            children: [
              for (final (code, name) in const [('eng', 'English'), ('tam', 'Tamil'), ('hin', 'Hindi')])
                FilterChip(
                  label: Text(name),
                  selected: languages.contains(code),
                  onSelected: running
                      ? null
                      : (on) {
                          on ? languages.add(code) : languages.remove(code);
                          onLanguagesChanged();
                        },
                ),
            ],
          ),
          SizedBox(height: 8.h),
          if (running) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress == null ? status! : '$status · ${progress!.label}',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
            LinearProgressIndicator(value: progress?.fraction),
          ] else
            FilledButton.icon(
              onPressed: languages.isEmpty ? null : onRun,
              icon: const Icon(Icons.text_fields_rounded),
              label: const Text('Make searchable & rebuild'),
            ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final CourtPreset preset;
  const _PresetCard({required this.preset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_rounded, color: AppTheme.accent),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 2.h),
                Text(
                  preset.description,
                  style: TextStyle(fontSize: 11.sp, color: mutedText(context), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: TextStyle(fontSize: 11.sp, color: mutedText(context))),
    value: value,
    activeThumbColor: AppTheme.accent,
    onChanged: onChanged,
  );
}

class _ChecksCard extends StatelessWidget {
  final List<FilingCheck> checks;
  const _ChecksCard({required this.checks});

  static (IconData, Color) _style(CheckLevel level) => switch (level) {
    CheckLevel.ok => (Icons.check_circle_rounded, AppTheme.success),
    CheckLevel.warning => (Icons.warning_amber_rounded, AppTheme.warning),
    CheckLevel.problem => (Icons.error_rounded, AppTheme.error),
    CheckLevel.info => (Icons.info_outline_rounded, AppTheme.info),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: AppTheme.cardDecoration(isDark: Theme.of(context).brightness == Brightness.dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('e-Filing check', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
          SizedBox(height: 8.h),
          for (final check in checks)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_style(check.level).$1, color: _style(check.level).$2, size: 20),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          check.title,
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          check.detail,
                          style: TextStyle(fontSize: 11.sp, color: mutedText(context), height: 1.35),
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
}

/// The rows to type into the portal's Indexing form (Index Title, From
/// Page No., To Page No.) for one uploaded file.
class _PortalIndexCard extends StatelessWidget {
  final String? fileLabel;
  final List<IndexEntry> index;
  const _PortalIndexCard({required this.fileLabel, required this.index});

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    final head = TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: muted);
    final cell = TextStyle(fontSize: 12.sp);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.r),
      decoration: AppTheme.cardDecoration(isDark: Theme.of(context).brightness == Brightness.dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fileLabel == null ? 'Portal indexing' : 'Portal indexing · $fileLabel',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: [for (final e in index) '${e.title}\t${e.from}\t${e.to}'].join('\n'),
                  ));
                  showToolMessage(context, 'Index copied');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          Text(
            'After uploading, add these under Pleadings › Indexing.',
            style: TextStyle(fontSize: 11.sp, color: muted),
          ),
          SizedBox(height: 8.h),
          Table(
            columnWidths: const {1: IntrinsicColumnWidth(), 2: IntrinsicColumnWidth()},
            children: [
              TableRow(children: [
                Text('Index title', style: head),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12.w), child: Text('From', style: head)),
                Text('To', style: head),
              ]),
              for (final e in index)
                TableRow(children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Text(e.title, style: cell),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    child: Text('${e.from}', style: cell),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Text('${e.to}', style: cell),
                  ),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

/// Names a document of the filing, with common titles one tap away.
class _TitleDialog extends StatefulWidget {
  final String initial;
  const _TitleDialog({required this.initial});

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Document title'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(helperText: 'Shown in the index and bookmarks'),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                for (final s in _titleSuggestions)
                  ActionChip(
                    label: Text(s, style: TextStyle(fontSize: 11.sp)),
                    onPressed: () => _controller.text = s,
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Picks documents already in the case to include in the filing.
class _CaseFilesSheet extends StatefulWidget {
  final List<String> names;
  const _CaseFilesSheet({required this.names});

  @override
  State<_CaseFilesSheet> createState() => _CaseFilesSheetState();
}

class _CaseFilesSheetState extends State<_CaseFilesSheet> {
  final List<String> _chosen = [];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 4.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add from case files',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton(
                  onPressed: _chosen.isEmpty ? null : () => Navigator.pop(context, _chosen),
                  child: Text(_chosen.isEmpty ? 'Add' : 'Add ${_chosen.length}'),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              'PDFs and images in this case. They are added in the order you tick them.',
              style: TextStyle(fontSize: 12.sp, color: mutedText(context)),
            ),
          ),
          Expanded(
            child: widget.names.isEmpty
                ? const Center(child: Text('This case has no PDFs or images yet.'))
                : ListView(
                    controller: controller,
                    children: [
                      for (final name in widget.names)
                        CheckboxListTile(
                          value: _chosen.contains(name),
                          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                          secondary: _chosen.contains(name)
                              ? CircleAvatar(radius: 12, child: Text('${_chosen.indexOf(name) + 1}'))
                              : null,
                          onChanged: (v) => setState(() {
                            v == true ? _chosen.add(name) : _chosen.remove(name);
                          }),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
