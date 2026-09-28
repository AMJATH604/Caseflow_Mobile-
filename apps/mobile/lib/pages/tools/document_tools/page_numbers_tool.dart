import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';
import 'single_pdf_input.dart';

/// Stamps page numbers in Times New Roman. Defaults follow the usual court
/// practice: plain numbers at the bottom centre.
class PageNumbersTool extends StatefulWidget {
  const PageNumbersTool({super.key});

  @override
  State<PageNumbersTool> createState() => _PageNumbersToolState();
}

class _PageNumbersToolState extends State<PageNumbersTool> {
  PdfInput? _input;
  NumberPosition _position = NumberPosition.bottomCenter;
  PageNumberStyle _style = PageNumberStyle.plain;
  int _fontSize = 12;
  final _startController = TextEditingController(text: '1');
  final _skipController = TextEditingController(text: '0');
  String? _error;
  bool _busy = false;
  List<ToolFile>? _result;

  @override
  void dispose() {
    _startController.dispose();
    _skipController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final input = await pickSinglePdf(context);
    if (input != null && mounted) setState(() => _input = input);
  }

  PageNumberOptions? _options() {
    final start = int.tryParse(_startController.text.trim());
    final skip = int.tryParse(_skipController.text.trim());
    if (start == null || start < 0) {
      setState(() => _error = 'Enter the first page number, e.g. 1');
      return null;
    }
    if (skip == null || skip < 0) {
      setState(() => _error = 'Enter how many pages to leave unnumbered, e.g. 0');
      return null;
    }
    return PageNumberOptions(
      position: _position,
      style: _style,
      startAt: start,
      skipFirst: skip,
      fontSize: _fontSize.toDouble(),
    );
  }

  Future<void> _apply() async {
    final options = _options();
    if (options == null) return;
    final input = _input!;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final bytes = await DocumentToolsService.addPageNumbers(input.file.bytes, options);
      setState(() => _result = [ToolFile('${baseName(input.file.name)}_numbered.pdf', bytes)]);
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
        headline: 'Page numbers added',
        onStartOver: () => setState(() {
          _input = null;
          _result = null;
        }),
      );
    }
    final input = _input;
    final start = int.tryParse(_startController.text.trim()) ?? 1;
    final skip = int.tryParse(_skipController.text.trim()) ?? 0;
    final example = PageNumberOptions(style: _style).label(
      start,
      start + (input?.pageCount ?? 10) - skip - 1,
    );
    return DocToolLayout(
      action: input == null
          ? null
          : ToolActionButton(
              label: 'Add page numbers',
              icon: Icons.format_list_numbered_rounded,
              busy: _busy,
              onPressed: _apply,
            ),
      children: [
        const DocToolIntro(
          'Number every page so the court and the index can refer to them. '
          'Numbers are printed in Times New Roman.',
        ),
        if (input == null)
          PickTarget(
            icon: Icons.format_list_numbered_rounded,
            title: 'Choose a PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          )
        else ...[
          PdfInputCard(input: input, onChange: _pick),
          const SectionLabel('Position'),
          ChoiceRow<NumberPosition>(
            options: const {
              NumberPosition.bottomCenter: 'Bottom centre',
              NumberPosition.bottomRight: 'Bottom right',
              NumberPosition.topRight: 'Top right',
            },
            value: _position,
            onChanged: (v) => setState(() => _position = v),
          ),
          const SectionLabel('Style'),
          ChoiceRow<PageNumberStyle>(
            options: const {
              PageNumberStyle.plain: '1',
              PageNumberStyle.dashed: '- 1 -',
              PageNumberStyle.pageN: 'Page 1',
              PageNumberStyle.pageNofTotal: 'Page 1 of N',
            },
            value: _style,
            onChanged: (v) => setState(() => _style = v),
          ),
          const SectionLabel('Size'),
          ChoiceRow<int>(
            options: const {11: 'Small', 12: 'Normal', 14: 'Large'},
            value: _fontSize,
            onChanged: (v) => setState(() => _fontSize = v),
          ),
          const SectionLabel('Numbering'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Skip first pages',
                    helperText: 'e.g. 1 for a cover',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  controller: _startController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'First number',
                    helperText: 'Usually 1',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ),
          SizedBox(height: 16.h),
          Text(
            'First numbered page will read "$example".',
            style: TextStyle(fontSize: 12.sp, color: mutedText(context)),
          ),
        ],
      ],
    );
  }
}
