import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import 'doc_tool_widgets.dart';
import 'page_rendering.dart';
import 'single_pdf_input.dart';

/// Stamps "DRAFT", "COPY", "CONFIDENTIAL" (or any text, Tamil included)
/// across pages, with a preview of the first page.
class WatermarkTool extends StatefulWidget {
  const WatermarkTool({super.key});

  @override
  State<WatermarkTool> createState() => _WatermarkToolState();
}

class _WatermarkToolState extends State<WatermarkTool> {
  PdfInput? _input;
  Size? _firstPage;
  ImageProvider? _preview;
  final _text = TextEditingController(text: 'DRAFT');
  bool _diagonal = true;
  int _size = 60;
  int _color = 0xFF9CA3AF;
  int _opacityPercent = 30;
  bool _allPages = true;
  final _pages = TextEditingController();
  String? _error;
  bool _busy = false;
  List<ToolFile>? _result;

  @override
  void dispose() {
    _text.dispose();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final input = await pickSinglePdf(context);
    if (input == null || !mounted) return;
    setState(() {
      _input = input;
      _preview = null;
    });
    try {
      final sizes = await DocumentToolsService.visualPageSizes(input.file.bytes);
      final preview = await PageRendering.page(input.file.bytes, 0, dpi: 60);
      if (mounted) {
        setState(() {
          _firstPage = sizes.first;
          _preview = preview;
        });
      }
    } catch (_) {
      // The preview is a convenience; the watermark still works without it.
    }
  }

  TextStyle get _style => TextStyle(
    fontSize: _size.toDouble(),
    fontWeight: FontWeight.bold,
    color: Color(_color),
  );

  Future<void> _apply() async {
    final input = _input!;
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter the watermark text');
      return;
    }
    Set<int>? pages;
    if (!_allPages) {
      try {
        pages = flattenRanges(parsePageRanges(_pages.text, input.pageCount)).toSet();
      } on PageRangeException catch (e) {
        setState(() => _error = e.message);
        return;
      }
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      var options = WatermarkOptions(
        text: text,
        fontSize: _size.toDouble(),
        color: _color,
        opacity: _opacityPercent / 100,
        diagonal: _diagonal,
        pages: pages,
      );
      if (!isStandardFontText(text)) {
        // Tamil, Hindi, curly quotes...: draw with the phone's fonts.
        final pageWidth = (_firstPage ?? a4Size).width;
        options = WatermarkOptions(
          image: await renderTextPng(text, _style),
          imageWidth: (measureText(text, _style).width / pageWidth).clamp(0.05, 0.95),
          opacity: options.opacity,
          diagonal: _diagonal,
          pages: pages,
        );
      }
      final bytes = await DocumentToolsService.watermark(input.file.bytes, options);
      if (mounted) {
        setState(() => _result = [ToolFile('${baseName(input.file.name)}_watermarked.pdf', bytes)]);
      }
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return ToolResultView(
        files: _result!,
        headline: 'Watermark added',
        onStartOver: () => setState(() {
          _input = null;
          _result = null;
        }),
      );
    }
    final input = _input;
    return DocToolLayout(
      action: input == null
          ? null
          : ToolActionButton(
              label: 'Add watermark',
              icon: Icons.branding_watermark_rounded,
              busy: _busy,
              onPressed: _apply,
            ),
      children: [
        const DocToolIntro(
          'Mark copies as DRAFT, COPY or CONFIDENTIAL before sharing them with a client '
          'or the other side.',
        ),
        if (input == null)
          PickTarget(
            icon: Icons.branding_watermark_rounded,
            title: 'Choose a PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          )
        else ...[
          PdfInputCard(input: input, onChange: _pick),
          if (_preview != null && _firstPage != null) _buildPreview(),
          SizedBox(height: 12.h),
          TextField(
            controller: _text,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: 'Watermark text', errorText: _error),
            onChanged: (_) => setState(() => _error = null),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            children: [
              for (final s in const ['DRAFT', 'COPY', 'CONFIDENTIAL', 'NOT FOR FILING'])
                ActionChip(label: Text(s), onPressed: () => setState(() => _text.text = s)),
            ],
          ),
          const SectionLabel('Look'),
          ChoiceRow<bool>(
            options: const {true: 'Diagonal', false: 'Straight'},
            value: _diagonal,
            onChanged: (v) => setState(() => _diagonal = v),
          ),
          SizedBox(height: 8.h),
          ChoiceRow<int>(
            options: const {40: 'Small', 60: 'Medium', 90: 'Large'},
            value: _size,
            onChanged: (v) => setState(() => _size = v),
          ),
          SizedBox(height: 8.h),
          ChoiceRow<int>(
            options: const {0xFF9CA3AF: 'Grey', 0xFFDC2626: 'Red', 0xFF2563EB: 'Blue'},
            value: _color,
            onChanged: (v) => setState(() => _color = v),
          ),
          SizedBox(height: 8.h),
          ChoiceRow<int>(
            options: const {15: 'Faint', 30: 'Normal', 50: 'Strong'},
            value: _opacityPercent,
            onChanged: (v) => setState(() => _opacityPercent = v),
          ),
          const SectionLabel('Pages'),
          ChoiceRow<bool>(
            options: {true: 'All ${input.pageCount} pages', false: 'Choose pages'},
            value: _allPages,
            onChanged: (v) => setState(() => _allPages = v),
          ),
          if (!_allPages) ...[
            SizedBox(height: 12.h),
            TextField(
              controller: _pages,
              decoration: const InputDecoration(labelText: 'Pages', hintText: 'e.g. 1-3, 7'),
            ),
          ],
        ],
      ],
    );
  }

  /// The first page with the watermark drawn the way the PDF will have it.
  Widget _buildPreview() {
    final page = _firstPage!;
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Center(
        child: SizedBox(
          width: 170.w,
          child: AspectRatio(
            aspectRatio: page.width / page.height,
            child: LayoutBuilder(
              builder: (context, box) {
                final scale = box.maxWidth / page.width;
                final angle = _diagonal ? -math.atan2(page.height, page.width) : 0.0;
                return Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: _preview!, fit: BoxFit.fill),
                      Center(
                        child: Transform.rotate(
                          angle: angle,
                          child: Opacity(
                            opacity: _opacityPercent / 100,
                            child: Text(
                              _text.text.trim(),
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: _style.copyWith(fontSize: _size * scale),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
