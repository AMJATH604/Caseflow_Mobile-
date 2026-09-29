import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_tools_service.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';
import 'single_pdf_input.dart';

const _removedColor = Color(0xFFDC2626);
const _addedColor = Color(0xFF059669);

/// Shows what changed between two versions of a document (e.g. your draft
/// agreement and the other side's "final" copy), word by word.
class ComparePdfTool extends StatefulWidget {
  /// Files to start with, so tests need not drive the file picker.
  @visibleForTesting
  final PdfInput? initialOld;
  @visibleForTesting
  final PdfInput? initialNew;
  const ComparePdfTool({super.key, this.initialOld, this.initialNew});

  @override
  State<ComparePdfTool> createState() => _ComparePdfToolState();
}

class _ComparePdfToolState extends State<ComparePdfTool> {
  late PdfInput? _old = widget.initialOld;
  late PdfInput? _new = widget.initialNew;
  bool _busy = false;
  Comparison? _result;

  Future<void> _pick(bool isOld) async {
    final input = await pickSinglePdf(context);
    if (input == null || !mounted) return;
    setState(() => isOld ? _old = input : _new = input);
  }

  Future<void> _compare() async {
    setState(() => _busy = true);
    try {
      final result = await DocumentToolsService.compare(_old!.file.bytes, _new!.file.bytes);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _summaryText(Comparison r) {
    final lines = [
      'Comparison of "${_old!.file.name}" (original) and "${_new!.file.name}" (revised)',
      '${r.changes.length} change${r.changes.length == 1 ? '' : 's'}: '
          '${r.wordsRemoved} words removed, ${r.wordsAdded} words added',
      '',
      for (var i = 0; i < r.changes.length; i++) ...[
        '${i + 1}. Page ${r.changes[i].oldPage} → ${r.changes[i].newPage}',
        if (r.changes[i].removed.isNotEmpty) '   Removed: ${r.changes[i].removed}',
        if (r.changes[i].added.isNotEmpty) '   Added: ${r.changes[i].added}',
      ],
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) return _buildResult(result);

    return DocToolLayout(
      action: _old == null || _new == null
          ? null
          : ToolActionButton(
              label: 'Compare',
              icon: Icons.compare_rounded,
              busy: _busy,
              onPressed: _compare,
            ),
      children: [
        const DocToolIntro(
          'See exactly what changed between two versions of a document: every word added '
          'or removed, with its page. Works on PDFs with text; OCR scans first.',
        ),
        for (final (isOld, label) in const [(true, 'Original version'), (false, 'Revised version')]) ...[
          SectionLabel(label),
          if ((isOld ? _old : _new) case final input?)
            PdfInputCard(input: input, onChange: () => _pick(isOld))
          else
            PickTarget(
              icon: isOld ? Icons.description_outlined : Icons.edit_document,
              title: 'Choose the ${label.toLowerCase()}',
              subtitle: 'PDF',
              onTap: () => _pick(isOld),
            ),
        ],
      ],
    );
  }

  Widget _buildResult(Comparison r) {
    return DocToolLayout(
      action: OutlinedButton.icon(
        onPressed: () => setState(() => _result = null),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Compare other files'),
        style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 46.h)),
      ),
      children: [
        Row(
          children: [
            Icon(
              r.identical ? Icons.check_circle_rounded : Icons.difference_rounded,
              color: r.identical ? AppTheme.success : AppTheme.accent,
              size: 28,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                r.identical
                    ? 'The text is identical'
                    : '${r.changes.length} change${r.changes.length == 1 ? '' : 's'} found',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ),
            if (!r.identical)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _summaryText(r)));
                  showToolMessage(context, 'Summary copied');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          children: [
            Chip(label: Text('−${r.wordsRemoved} words'), labelStyle: const TextStyle(color: _removedColor)),
            Chip(label: Text('+${r.wordsAdded} words'), labelStyle: const TextStyle(color: _addedColor)),
            Chip(label: Text('${r.oldPages} → ${r.newPages} pages')),
          ],
        ),
        if (r.identical)
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Text(
              'Only the words are compared: layout, fonts and images may still differ.',
              style: TextStyle(fontSize: 12.sp, color: mutedText(context)),
            ),
          ),
        SizedBox(height: 12.h),
        for (var i = 0; i < r.changes.length; i++) _ChangeCard(number: i + 1, change: r.changes[i]),
      ],
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final int number;
  final TextChange change;
  const _ChangeCard({required this.number, required this.change});

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    final base = TextStyle(fontSize: 13.sp, height: 1.45, color: Theme.of(context).textTheme.bodyMedium?.color);
    final pages = change.oldPage == change.newPage
        ? 'Page ${change.oldPage}'
        : 'Page ${change.oldPage} → ${change.newPage}';
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: AppTheme.cardDecoration(isDark: Theme.of(context).brightness == Brightness.dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number · $pages · ${switch (change.kind) {
              ChangeKind.added => 'added',
              ChangeKind.removed => 'removed',
              ChangeKind.replaced => 'changed',
            }}',
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: muted),
          ),
          SizedBox(height: 4.h),
          Text.rich(
            TextSpan(
              style: base,
              children: [
                if (change.before.isNotEmpty) TextSpan(text: '…${change.before} ', style: TextStyle(color: muted)),
                if (change.removed.isNotEmpty)
                  TextSpan(
                    text: change.removed,
                    style: TextStyle(
                      color: _removedColor,
                      decoration: TextDecoration.lineThrough,
                      backgroundColor: _removedColor.withValues(alpha: 0.08),
                    ),
                  ),
                if (change.removed.isNotEmpty && change.added.isNotEmpty) const TextSpan(text: ' '),
                if (change.added.isNotEmpty)
                  TextSpan(
                    text: change.added,
                    style: TextStyle(
                      color: _addedColor,
                      fontWeight: FontWeight.w600,
                      backgroundColor: _addedColor.withValues(alpha: 0.1),
                    ),
                  ),
                if (change.after.isNotEmpty) TextSpan(text: ' ${change.after}…', style: TextStyle(color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
