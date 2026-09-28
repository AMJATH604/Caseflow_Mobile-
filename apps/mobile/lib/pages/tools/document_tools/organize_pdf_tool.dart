import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';
import 'page_previews.dart';
import 'single_pdf_input.dart';

enum PageEditorMode { organize, rotate }

class _PageItem {
  final int source;
  int turns = 0; // quarter turns clockwise
  _PageItem(this.source);
}

/// Organize (reorder, delete, rotate pages) and Rotate (turn pages) share
/// this screen; [mode] decides which controls are shown.
class OrganizePdfTool extends StatefulWidget {
  final PageEditorMode mode;
  const OrganizePdfTool({super.key, this.mode = PageEditorMode.organize});

  @override
  State<OrganizePdfTool> createState() => _OrganizePdfToolState();
}

class _OrganizePdfToolState extends State<OrganizePdfTool> {
  PdfInput? _input;
  PdfPreviewLoader? _previews;
  List<_PageItem> _pages = [];
  bool _busy = false;
  List<ToolFile>? _result;

  bool get _isRotate => widget.mode == PageEditorMode.rotate;

  @override
  void dispose() {
    _previews?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final input = await pickSinglePdf(context);
    if (input == null || !mounted) return;
    _previews?.dispose();
    setState(() {
      _input = input;
      _previews = PdfPreviewLoader(input.file.bytes, input.pageCount);
      _pages = [for (var i = 0; i < input.pageCount; i++) _PageItem(i)];
    });
  }

  bool get _changed {
    final input = _input;
    if (input == null) return false;
    if (_pages.length != input.pageCount) return true;
    for (var i = 0; i < _pages.length; i++) {
      if (_pages[i].source != i || _pages[i].turns % 4 != 0) return true;
    }
    return false;
  }

  void _rotateAll(int delta) => setState(() {
    for (final p in _pages) {
      p.turns += delta;
    }
  });

  Future<void> _apply() async {
    final input = _input!;
    setState(() => _busy = true);
    try {
      final bytes = await DocumentToolsService.composePages([input.file.bytes], [
        for (final p in _pages) PageRef(0, p.source, rotation: (p.turns % 4) * 90),
      ]);
      final suffix = _isRotate ? 'rotated' : 'organized';
      setState(() => _result = [ToolFile('${baseName(input.file.name)}_$suffix.pdf', bytes)]);
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    _previews?.dispose();
    setState(() {
      _input = null;
      _previews = null;
      _pages = [];
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return ToolResultView(
        files: _result!,
        headline: _isRotate ? 'Pages rotated' : 'Pages organized',
        onStartOver: _reset,
      );
    }
    final input = _input;
    if (input == null) {
      return DocToolLayout(
        children: [
          DocToolIntro(
            _isRotate
                ? 'Turn sideways or upside-down pages the right way up. Tap a page to turn it.'
                : 'Drag pages into the right order, delete the ones you do not need, and turn any that are sideways.',
          ),
          PickTarget(
            icon: _isRotate ? Icons.rotate_right_rounded : Icons.view_list_rounded,
            title: 'Choose a PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          ),
        ],
      );
    }

    return ListenableBuilder(
      listenable: _previews!,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: PdfInputCard(input: input, onChange: _pick),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isRotate
                        ? 'Tap a page to turn it clockwise'
                        : '${_pages.length} of ${input.pageCount} pages · drag ≡ to reorder',
                    style: TextStyle(fontSize: 12.sp, color: mutedText(context)),
                  ),
                ),
                IconButton(
                  tooltip: 'Turn all left',
                  icon: const Icon(Icons.rotate_left_rounded),
                  onPressed: () => _rotateAll(-1),
                ),
                IconButton(
                  tooltip: 'Turn all right',
                  icon: const Icon(Icons.rotate_right_rounded),
                  onPressed: () => _rotateAll(1),
                ),
              ],
            ),
          ),
          Expanded(child: _isRotate ? _buildGrid() : _buildList()),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: ToolActionButton(
                label: _isRotate ? 'Save rotated PDF' : 'Save organized PDF',
                icon: Icons.check_rounded,
                busy: _busy,
                onPressed: _changed ? _apply : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(16.r),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.62,
      ),
      itemCount: _pages.length,
      itemBuilder: (context, i) {
        final page = _pages[i];
        return InkWell(
          onTap: () => setState(() => page.turns++),
          child: Column(
            children: [
              Expanded(
                child: FittedBox(
                  child: PageThumb(
                    image: _previews!.images[page.source],
                    pageNumber: page.source + 1,
                    quarterTurns: page.turns,
                    width: 90,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                page.turns % 4 == 0 ? '${i + 1}' : '${i + 1} · ${(page.turns % 4) * 90}°',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: page.turns % 4 == 0 ? null : AppTheme.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      buildDefaultDragHandles: false,
      itemCount: _pages.length,
      onReorder: (from, to) => setState(() {
        if (to > from) to--;
        _pages.insert(to, _pages.removeAt(from));
      }),
      itemBuilder: (context, i) {
        final page = _pages[i];
        return Container(
          key: ObjectKey(page),
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(8.r),
          decoration: AppTheme.cardDecoration(
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          child: Row(
            children: [
              PageThumb(
                image: _previews!.images[page.source],
                pageNumber: page.source + 1,
                quarterTurns: page.turns,
                width: 52,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page ${i + 1}',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      page.source == i ? 'Original page' : 'Was page ${page.source + 1}',
                      style: TextStyle(fontSize: 11.sp, color: mutedText(context)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Turn right',
                icon: const Icon(Icons.rotate_right_rounded),
                onPressed: () => setState(() => page.turns++),
              ),
              IconButton(
                tooltip: 'Delete page',
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                onPressed: _pages.length == 1
                    ? null
                    : () => setState(() => _pages.removeAt(i)),
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
        );
      },
    );
  }
}
