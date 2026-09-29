import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';
import 'page_rendering.dart';
import 'signature_sheet.dart';
import 'single_pdf_input.dart';

enum MarkupMode { sign, edit }

/// Something placed on a page while editing. [box] is in fractions of the
/// visual page, like [PageOverlay].
class _Mark {
  final int id;
  int page;
  Rect box;
  final OverlayKind kind;
  final Uint8List? image;
  String text;
  double fontSize;
  int color;

  _Mark({
    required this.id,
    required this.page,
    required this.box,
    required this.kind,
    this.image,
    this.text = '',
    this.fontSize = 12,
    this.color = 0xFF000000,
  });

  _Mark copy({int? id, int? page}) => _Mark(
    id: id ?? this.id,
    page: page ?? this.page,
    box: box,
    kind: kind,
    image: image,
    text: text,
    fontSize: fontSize,
    color: color,
  );
}

const _textColors = {'Black': 0xFF000000, 'Blue': 0xFF1E3A8A, 'Red': 0xFFDC2626};

/// Sign: place a signature (drawn, typed, photographed or saved), the date
/// or a seal, on one page or every page.
/// Edit: add text, white out (and truly remove) text, highlight, box, or
/// add images. Both share this page editor.
class PageEditorTool extends StatefulWidget {
  final MarkupMode mode;

  /// A PDF to start with, so tests need not drive the file picker.
  @visibleForTesting
  final PdfInput? initialInput;

  /// Renders a page for display; tests replace the platform renderer.
  @visibleForTesting
  final Future<ImageProvider> Function(Uint8List pdf, int page)? renderPage;
  const PageEditorTool({super.key, required this.mode, this.initialInput, this.renderPage});

  @override
  State<PageEditorTool> createState() => _PageEditorToolState();
}

class _PageEditorToolState extends State<PageEditorTool> {
  PdfInput? _input;
  List<Size> _sizes = const [];
  final Map<int, ImageProvider> _pageImages = {};
  final Set<int> _unrenderable = {};
  int _page = 0;
  final List<_Mark> _marks = [];
  final List<List<_Mark>> _undo = [];
  int? _selected;
  int _nextId = 1;
  bool _redact = true;
  bool _busy = false;
  List<ToolFile>? _result;

  bool get _isSign => widget.mode == MarkupMode.sign;

  @override
  void initState() {
    super.initState();
    if (widget.initialInput != null) _open(widget.initialInput!);
  }

  Future<void> _pick() async {
    final input = await pickSinglePdf(context);
    if (input == null || !mounted) return;
    await _open(input);
  }

  Future<void> _open(PdfInput input) async {
    try {
      final sizes = await DocumentToolsService.visualPageSizes(input.file.bytes);
      setState(() {
        _input = input;
        _sizes = sizes;
        _pageImages.clear();
        _unrenderable.clear();
        _marks.clear();
        _undo.clear();
        _selected = null;
        _page = 0;
      });
      _loadPage(0);
    } catch (e) {
      if (mounted) showToolError(context, e);
    }
  }

  Future<void> _loadPage(int index) async {
    if (_pageImages.containsKey(index)) return;
    try {
      final render = widget.renderPage ?? PageRendering.page;
      final image = await render(_input!.file.bytes, index);
      if (mounted) setState(() => _pageImages[index] = image);
    } catch (_) {
      // Shown as a blank page; marks can still be placed.
      if (mounted) setState(() => _unrenderable.add(index));
    }
  }

  void _goTo(int index) {
    setState(() {
      _page = index;
      _selected = null;
    });
    _loadPage(index);
  }

  // ── Editing ──────────────────────────────────────────────────────

  void _snapshot() {
    _undo.add([for (final m in _marks) m.copy()]);
    if (_undo.length > 50) _undo.removeAt(0);
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _marks
        ..clear()
        ..addAll(_undo.removeLast());
      _selected = null;
    });
  }

  Size get _pageSize => _sizes[_page];

  /// Adds [mark] centred on the current page and selects it.
  void _add(OverlayKind kind, {Uint8List? image, String text = '', double width = 0.3, double height = 0.06}) {
    _snapshot();
    final box = Rect.fromLTWH((1 - width) / 2, (1 - height) / 2, width, height);
    final mark = _Mark(id: _nextId++, page: _page, box: box, kind: kind, image: image, text: text);
    if (kind == OverlayKind.highlight) mark.color = 0xFFFDE047;
    if (kind == OverlayKind.box) mark.color = 0xFFDC2626;
    if (kind == OverlayKind.text) _fitTextHeight(mark);
    setState(() {
      _marks.add(mark);
      _selected = mark.id;
    });
  }

  Future<void> _addSignature() async {
    final png = await SignatureSheet.show(context);
    if (png == null || !mounted) return;
    _addImage(png, width: 0.28);
  }

  Future<void> _addImageFile() async {
    try {
      final files = await DocumentFiles.pickImagesFromGallery();
      if (files.isEmpty || !mounted) return;
      _addImage(files.first.bytes, width: 0.35);
    } catch (e) {
      if (mounted) showToolError(context, e);
    }
  }

  Future<void> _addImage(Uint8List bytes, {required double width}) async {
    final decoded = await decodeImageFromList(bytes);
    final aspect = decoded.height / decoded.width;
    decoded.dispose();
    final height = (width * aspect * _pageSize.width / _pageSize.height).clamp(0.02, 0.9);
    _add(OverlayKind.image, image: bytes, width: width, height: height);
  }

  Future<void> _addText({String? initial}) async {
    final text = initial ?? await _askText('');
    if (text == null || text.trim().isEmpty) return;
    _add(OverlayKind.text, text: text.trim(), width: 0.5);
  }

  Future<String?> _askText(String initial) => showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(initial: initial),
  );

  /// Sets a text mark's height to what its text needs at its width.
  void _fitTextHeight(_Mark mark) {
    final page = _sizes[mark.page];
    final size = measureText(
      mark.text,
      TextStyle(fontSize: mark.fontSize, height: 1.2),
      maxWidth: mark.box.width * page.width,
    );
    mark.box = Rect.fromLTWH(
      mark.box.left,
      mark.box.top,
      mark.box.width,
      ((size.height + 2) / page.height).clamp(0.01, 1.0),
    );
  }

  _Mark? get _selectedMark {
    for (final m in _marks) {
      if (m.id == _selected) return m;
    }
    return null;
  }

  void _deleteSelected() {
    _snapshot();
    setState(() {
      _marks.removeWhere((m) => m.id == _selected);
      _selected = null;
    });
  }

  /// Copies the selected mark to the same place on every other page, e.g.
  /// to sign each page of a vakalat or affidavit.
  void _copyToAllPages() {
    final mark = _selectedMark;
    if (mark == null) return;
    _snapshot();
    setState(() {
      for (var p = 0; p < _sizes.length; p++) {
        if (p == mark.page) continue;
        _marks.add(mark.copy(id: _nextId++, page: p));
      }
    });
    showToolMessage(context, 'Added to all ${_sizes.length} pages');
  }

  Future<void> _editSelectedText() async {
    final mark = _selectedMark;
    if (mark == null) return;
    final text = await _askText(mark.text);
    if (text == null || text.trim().isEmpty) return;
    _snapshot();
    setState(() {
      mark.text = text.trim();
      _fitTextHeight(mark);
    });
  }

  // ── Saving ───────────────────────────────────────────────────────

  bool get _hasWhiteout => _marks.any((m) => m.kind == OverlayKind.whiteout);

  Future<void> _save() async {
    final input = _input!;
    setState(() {
      _busy = true;
      _selected = null;
    });
    try {
      final overlays = <PageOverlay>[];
      for (final m in _marks) {
        if (m.kind == OverlayKind.text && !isStandardFontText(m.text)) {
          // Tamil, Hindi...: drawn by the phone's fonts, placed as an image.
          final page = _sizes[m.page];
          final png = await renderTextPng(
            m.text,
            TextStyle(fontSize: m.fontSize, height: 1.2, color: Color(m.color)),
            maxWidth: m.box.width * page.width,
          );
          overlays.add(PageOverlay(page: m.page, box: m.box, kind: OverlayKind.image, image: png));
        } else {
          overlays.add(
            PageOverlay(
              page: m.page,
              box: m.box,
              kind: m.kind,
              image: m.image,
              text: m.text,
              fontSize: m.fontSize,
              color: m.color,
            ),
          );
        }
      }
      var bytes = await DocumentToolsService.applyOverlays(input.file.bytes, overlays);

      if (_hasWhiteout && _redact) {
        // Burn the whiteout in: those pages become images, so the covered
        // text is gone rather than just hidden.
        final pages = {for (final m in _marks) if (m.kind == OverlayKind.whiteout) m.page}.toList()..sort();
        final images = <int, Uint8List>{};
        var i = 0;
        await for (final jpeg in PageRendering.jpegs(bytes, pages, dpi: 200)) {
          images[pages[i++]] = jpeg;
        }
        bytes = await DocumentToolsService.flattenPages(bytes, images);
      }
      final suffix = _isSign ? 'signed' : 'edited';
      if (mounted) setState(() => _result = [ToolFile('${baseName(input.file.name)}_$suffix.pdf', bytes)]);
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return ToolResultView(
        files: _result!,
        headline: _isSign ? 'Signed' : 'Changes saved',
        onStartOver: () => setState(() {
          _input = null;
          _result = null;
          _marks.clear();
          _undo.clear();
        }),
      );
    }
    final input = _input;
    if (input == null || _sizes.isEmpty) {
      return DocToolLayout(
        children: [
          DocToolIntro(
            _isSign
                ? 'Place your signature, the date or your seal on a PDF, on one page or every page.'
                : 'Add text, white out or highlight text, draw boxes and add images on a PDF.',
          ),
          if (_isSign) const _SignNotice(),
          PickTarget(
            icon: _isSign ? Icons.draw_rounded : Icons.edit_note_rounded,
            title: 'Choose a PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          ),
        ],
      );
    }

    final selected = _selectedMark;
    return Column(
      children: [
        _buildToolbar(),
        if (selected != null) _buildSelectionBar(selected),
        Expanded(child: _buildPage()),
        _buildPageBar(),
        if (_hasWhiteout)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _redact,
              onChanged: (v) => setState(() => _redact = v),
              title: const Text('Remove covered text permanently'),
              subtitle: const Text(
                'Pages with whiteout become images, so hidden text (e.g. Aadhaar numbers) '
                'cannot be copied out. Recommended.',
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
            child: ToolActionButton(
              label: _isSign ? 'Save signed PDF' : 'Save PDF',
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: _marks.isEmpty ? null : _save,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    Widget tool(IconData icon, String label, VoidCallback onTap) => Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap),
    );
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    return SizedBox(
      height: 48.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          if (_isSign) ...[
            tool(Icons.draw_rounded, 'Signature', _addSignature),
            tool(Icons.event_rounded, 'Date', () => _addText(initial: today)),
            tool(Icons.title_rounded, 'Text', _addText),
            tool(Icons.approval_rounded, 'Seal / image', _addImageFile),
          ] else ...[
            tool(Icons.title_rounded, 'Text', _addText),
            tool(Icons.format_color_reset_rounded, 'Whiteout', () => _add(OverlayKind.whiteout, width: 0.3, height: 0.04)),
            tool(Icons.highlight_rounded, 'Highlight', () => _add(OverlayKind.highlight, width: 0.4, height: 0.025)),
            tool(Icons.crop_square_rounded, 'Box', () => _add(OverlayKind.box, width: 0.3, height: 0.08)),
            tool(Icons.image_outlined, 'Image', _addImageFile),
            tool(Icons.draw_rounded, 'Signature', _addSignature),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionBar(_Mark mark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4.w,
        children: [
          if (mark.kind == OverlayKind.text) ...[
            TextButton.icon(
              onPressed: _editSelectedText,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit'),
            ),
            IconButton(
              tooltip: 'Smaller text',
              icon: const Icon(Icons.text_decrease_rounded),
              onPressed: mark.fontSize <= 7 ? null : () => _restyle(mark, fontSize: mark.fontSize - 1),
            ),
            IconButton(
              tooltip: 'Larger text',
              icon: const Icon(Icons.text_increase_rounded),
              onPressed: mark.fontSize >= 40 ? null : () => _restyle(mark, fontSize: mark.fontSize + 1),
            ),
            for (final entry in _textColors.entries)
              InkWell(
                onTap: () => _restyle(mark, color: entry.value),
                child: Padding(
                  padding: EdgeInsets.all(4.r),
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Color(entry.value),
                    child: mark.color == entry.value
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
              ),
          ],
          if (_sizes.length > 1)
            TextButton.icon(
              onPressed: _copyToAllPages,
              icon: const Icon(Icons.library_add_rounded, size: 18),
              label: const Text('All pages'),
            ),
          TextButton.icon(
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
            label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _restyle(_Mark mark, {double? fontSize, int? color}) {
    _snapshot();
    setState(() {
      if (fontSize != null) mark.fontSize = fontSize;
      if (color != null) mark.color = color;
      _fitTextHeight(mark);
    });
  }

  Widget _buildPage() {
    final page = _pageSize;
    return Padding(
      padding: EdgeInsets.all(12.r),
      child: Center(
        child: AspectRatio(
          aspectRatio: page.width / page.height,
          child: LayoutBuilder(
            builder: (context, box) {
              final area = Size(box.maxWidth, box.maxHeight);
              final image = _pageImages[_page];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = null),
                        child: image != null
                            ? Image(image: image, fit: BoxFit.fill, gaplessPlayback: true)
                            : _unrenderable.contains(_page)
                            ? Center(
                                child: Text(
                                  'Preview unavailable',
                                  style: TextStyle(color: mutedText(context)),
                                ),
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    for (final mark in _marks)
                      if (mark.page == _page) _buildMark(mark, area, page),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMark(_Mark mark, Size area, Size page) {
    final selected = mark.id == _selected;
    final rect = Rect.fromLTWH(
      mark.box.left * area.width,
      mark.box.top * area.height,
      mark.box.width * area.width,
      mark.box.height * area.height,
    );
    // Points to on-screen pixels, so text previews at its printed size.
    final scale = area.width / page.width;

    final Widget content = switch (mark.kind) {
      OverlayKind.image => Image.memory(mark.image!, fit: BoxFit.fill, gaplessPlayback: true),
      OverlayKind.text => Text(
        mark.text,
        style: TextStyle(fontSize: mark.fontSize * scale, height: 1.2, color: Color(mark.color)),
      ),
      OverlayKind.whiteout => Container(color: Colors.white),
      OverlayKind.highlight => Container(color: Color(mark.color).withValues(alpha: 0.35)),
      OverlayKind.box => Container(
        decoration: BoxDecoration(border: Border.all(color: Color(mark.color), width: 1.5 * scale)),
      ),
    };

    void move(DragUpdateDetails d) => setState(() {
      final b = mark.box;
      mark.box = Rect.fromLTWH(
        (b.left + d.delta.dx / area.width).clamp(0.0, 1 - b.width),
        (b.top + d.delta.dy / area.height).clamp(0.0, 1 - b.height),
        b.width,
        b.height,
      );
    });

    void resize(DragUpdateDetails d) => setState(() {
      final b = mark.box;
      final width = (b.width + d.delta.dx / area.width).clamp(0.03, 1 - b.left);
      double height;
      if (mark.kind == OverlayKind.image) {
        // Keep signatures and seals in proportion.
        height = (b.height * width / b.width).clamp(0.01, 1 - b.top);
      } else {
        height = (b.height + d.delta.dy / area.height).clamp(0.01, 1 - b.top);
      }
      mark.box = Rect.fromLTWH(b.left, b.top, width, height);
      if (mark.kind == OverlayKind.text) _fitTextHeight(mark);
    });

    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = mark.id),
        onPanStart: (_) {
          _snapshot();
          setState(() => _selected = mark.id);
        },
        onPanUpdate: move,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: content),
            if (selected || mark.kind == OverlayKind.whiteout)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? AppTheme.accent : const Color(0xFFCBD5E1),
                        width: selected ? 1.5 : 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            if (selected)
              Positioned(
                right: -14,
                bottom: -14,
                child: GestureDetector(
                  onPanStart: (_) => _snapshot(),
                  onPanUpdate: resize,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageBar() {
    final count = _sizes.length;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Undo',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.undo_rounded),
            onPressed: _undo.isEmpty ? null : _undoLast,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _page == 0 ? null : () => _goTo(_page - 1),
                ),
                Flexible(
                  child: Text(
                    'Page ${_page + 1} of $count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Next page',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _page >= count - 1 ? null : () => _goTo(_page + 1),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Choose another PDF',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: _busy ? null : _pick,
          ),
        ],
      ),
    );
  }
}

/// Makes clear what a placed signature is, and is not, in court terms.
class _SignNotice extends StatelessWidget {
  const _SignNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.info, size: 20),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'This places an image of your signature, like signing a printout: good for letters, '
              'notices and documents to print. Pleadings filed on the e-Courts portal are signed '
              'there with Aadhaar eSign or a DSC.',
              style: TextStyle(fontSize: 12.sp, height: 1.4, color: mutedText(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enter or change the text of a text mark (several lines allowed).
class _TextDialog extends StatefulWidget {
  final String initial;
  const _TextDialog({required this.initial});

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Text'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 5,
        decoration: const InputDecoration(hintText: 'English, Tamil or Hindi'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Done')),
      ],
    );
  }
}
