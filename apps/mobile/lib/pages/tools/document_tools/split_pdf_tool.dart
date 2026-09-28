import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import 'doc_tool_widgets.dart';
import 'single_pdf_input.dart';

enum _SplitMode { extract, ranges, everyN }

/// Takes pages out of a PDF: one file of chosen pages, one file per range,
/// or equal chunks (useful when a portal caps the file size).
class SplitPdfTool extends StatefulWidget {
  const SplitPdfTool({super.key});

  @override
  State<SplitPdfTool> createState() => _SplitPdfToolState();
}

class _SplitPdfToolState extends State<SplitPdfTool> {
  PdfInput? _input;
  _SplitMode _mode = _SplitMode.extract;
  final _rangesController = TextEditingController();
  final _chunkController = TextEditingController(text: '10');
  String? _error;
  bool _busy = false;
  List<ToolFile>? _result;

  @override
  void dispose() {
    _rangesController.dispose();
    _chunkController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final input = await pickSinglePdf(context);
    if (input != null && mounted) setState(() => _input = input);
  }

  /// The output files as page ranges, or null (with [_error] set).
  List<List<PageRange>>? _plan() {
    final count = _input!.pageCount;
    try {
      switch (_mode) {
        case _SplitMode.extract:
          final ranges = parsePageRanges(_rangesController.text, count);
          return [ranges];
        case _SplitMode.ranges:
          return [for (final r in parsePageRanges(_rangesController.text, count)) [r]];
        case _SplitMode.everyN:
          final n = int.tryParse(_chunkController.text.trim());
          if (n == null) throw const PageRangeException('Enter how many pages per file');
          return [for (final r in chunkPages(count, n)) [r]];
      }
    } on PageRangeException catch (e) {
      setState(() => _error = e.message);
      return null;
    }
  }

  Future<void> _split() async {
    final plan = _plan();
    if (plan == null) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    final input = _input!;
    final base = baseName(input.file.name);
    try {
      final List<ToolFile> files;
      if (_mode == _SplitMode.extract) {
        final pages = flattenRanges(plan.single);
        final bytes = await DocumentToolsService.composePages(
          [input.file.bytes],
          [for (final p in pages) PageRef(0, p)],
        );
        final label = plan.single.map((r) => r.label).join(',');
        files = [ToolFile(safeFileName('${base}_pages_$label'), bytes)];
      } else {
        final ranges = [for (final group in plan) group.single];
        final parts = await DocumentToolsService.split(input.file.bytes, ranges);
        files = [
          for (var i = 0; i < parts.length; i++)
            ToolFile(safeFileName('${base}_pages_${ranges[i].label}'), parts[i]),
        ];
      }
      setState(() => _result = files);
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
        headline: _result!.length == 1 ? 'Pages extracted' : 'Split into ${_result!.length} files',
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
              label: _mode == _SplitMode.extract ? 'Extract pages' : 'Split PDF',
              icon: Icons.call_split_rounded,
              busy: _busy,
              onPressed: _split,
            ),
      children: [
        const DocToolIntro(
          'Take out the pages you need, or cut a large PDF into smaller files for upload.',
        ),
        if (input == null)
          PickTarget(
            icon: Icons.call_split_rounded,
            title: 'Choose a PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          )
        else ...[
          PdfInputCard(input: input, onChange: _pick),
          const SectionLabel('How to split'),
          ChoiceRow<_SplitMode>(
            options: const {
              _SplitMode.extract: 'Pick pages → 1 file',
              _SplitMode.ranges: 'One file per range',
              _SplitMode.everyN: 'Every N pages',
            },
            value: _mode,
            onChanged: (m) => setState(() {
              _mode = m;
              _error = null;
            }),
          ),
          SizedBox(height: 16.h),
          if (_mode == _SplitMode.everyN)
            TextField(
              controller: _chunkController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Pages per file',
                errorText: _error,
                helperText: 'A ${input.pageCount}-page PDF becomes '
                    '${_chunkCount(input.pageCount)} files',
              ),
              onChanged: (_) => setState(() => _error = null),
            )
          else
            TextField(
              controller: _rangesController,
              decoration: InputDecoration(
                labelText: 'Pages',
                hintText: _mode == _SplitMode.extract ? 'e.g. 1-3, 7, 10-' : 'e.g. 1-5, 6-12, 13-',
                helperText: _mode == _SplitMode.extract
                    ? 'The chosen pages are put into one new PDF, in this order'
                    : 'Each range becomes its own PDF',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
        ],
      ],
    );
  }

  String _chunkCount(int pages) {
    final n = int.tryParse(_chunkController.text.trim());
    if (n == null || n < 1) return '…';
    return '${(pages / n).ceil()}';
  }
}
