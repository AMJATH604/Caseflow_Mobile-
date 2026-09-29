import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import 'doc_tool_widgets.dart';
import 'page_rendering.dart';
import 'single_pdf_input.dart';

/// Saves PDF pages as JPG images, e.g. to send an order or a receipt on
/// WhatsApp, which shows images inline but PDFs only as attachments.
class PdfToImagesTool extends StatefulWidget {
  const PdfToImagesTool({super.key});

  @override
  State<PdfToImagesTool> createState() => _PdfToImagesToolState();
}

class _PdfToImagesToolState extends State<PdfToImagesTool> {
  PdfInput? _input;
  bool _allPages = true;
  final _pages = TextEditingController();
  int _dpi = 150;
  String? _error;
  bool _busy = false;
  int _done = 0;
  int _total = 0;
  List<ToolFile>? _result;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final input = await pickSinglePdf(context);
    if (input != null && mounted) setState(() => _input = input);
  }

  Future<void> _convert() async {
    final input = _input!;
    final List<int> pages;
    try {
      pages = _allPages
          ? [for (var i = 0; i < input.pageCount; i++) i]
          : flattenRanges(parsePageRanges(_pages.text, input.pageCount));
    } on PageRangeException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
      _done = 0;
      _total = pages.length;
    });
    try {
      final base = baseName(input.file.name);
      final files = <ToolFile>[];
      var n = 0;
      await for (final jpeg in PageRendering.jpegs(input.file.bytes, pages, dpi: _dpi.toDouble())) {
        files.add(ToolFile('${base}_page${pages[n] + 1}.jpg', jpeg));
        n++;
        if (mounted) setState(() => _done = n);
      }
      if (mounted) setState(() => _result = files);
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
        headline: '${_result!.length} image${_result!.length == 1 ? '' : 's'} ready',
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
              label: _busy ? 'Page $_done of $_total' : 'Convert to JPG',
              icon: Icons.image_rounded,
              busy: _busy,
              onPressed: _convert,
            ),
      children: [
        const DocToolIntro(
          'Save pages as JPG images, e.g. to send an order or receipt on WhatsApp, '
          'where images show in the chat.',
        ),
        if (input == null)
          PickTarget(
            icon: Icons.image_rounded,
            title: 'Choose a PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          )
        else ...[
          PdfInputCard(input: input, onChange: _pick),
          const SectionLabel('Pages'),
          ChoiceRow<bool>(
            options: {true: 'All ${input.pageCount} pages', false: 'Choose pages'},
            value: _allPages,
            onChanged: (v) => setState(() {
              _allPages = v;
              _error = null;
            }),
          ),
          if (!_allPages) ...[
            SizedBox(height: 12.h),
            TextField(
              controller: _pages,
              decoration: InputDecoration(
                labelText: 'Pages',
                hintText: 'e.g. 1-3, 7',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
          const SectionLabel('Quality'),
          ChoiceRow<int>(
            options: const {100: 'Phone screen', 150: 'Standard', 300: 'Print'},
            value: _dpi,
            onChanged: (v) => setState(() => _dpi = v),
          ),
        ],
      ],
    );
  }
}
