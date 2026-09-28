import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import 'doc_tool_widgets.dart';
import 'single_pdf_input.dart';

/// Joins several PDFs (petition, vakalat, annexures...) into one, in the
/// order the user arranges them.
class MergePdfTool extends StatefulWidget {
  const MergePdfTool({super.key});

  @override
  State<MergePdfTool> createState() => _MergePdfToolState();
}

class _MergePdfToolState extends State<MergePdfTool> {
  final List<PdfInput> _inputs = [];
  bool _adding = false;
  bool _busy = false;
  List<ToolFile>? _result;

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final files = await DocumentFiles.pickPdfs();
      final problems = <String>[];
      for (final f in files) {
        try {
          _inputs.add(PdfInput(f, await DocumentToolsService.pageCount(f.bytes)));
        } catch (e) {
          problems.add('${f.name}: $e');
        }
      }
      if (problems.isNotEmpty && mounted) {
        showToolError(context, DocumentToolException(problems.join('\n')));
      }
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _merge() async {
    setState(() => _busy = true);
    try {
      final bytes = await DocumentToolsService.merge([for (final i in _inputs) i.file.bytes]);
      final name = '${baseName(_inputs.first.file.name)}_merged.pdf';
      setState(() => _result = [ToolFile(name, bytes)]);
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
        headline: 'Merged ${_inputs.length} PDFs',
        onStartOver: () => setState(() {
          _inputs.clear();
          _result = null;
        }),
      );
    }

    final totalPages = _inputs.fold<int>(0, (sum, i) => sum + i.pageCount);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: const DocToolIntro(
            'Combine several PDFs into one file. Drag ≡ to set the order; the first file comes first.',
          ),
        ),
        if (_inputs.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: PickTarget(
              icon: Icons.merge_rounded,
              title: _adding ? 'Reading files…' : 'Choose PDFs',
              subtitle: 'Pick two or more; you can add more later',
              onTap: _adding ? () {} : _add,
            ),
          )
        else
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              buildDefaultDragHandles: false,
              itemCount: _inputs.length,
              onReorder: (from, to) => setState(() {
                if (to > from) to--;
                _inputs.insert(to, _inputs.removeAt(from));
              }),
              footer: Padding(
                padding: EdgeInsets.only(top: 4.h, bottom: 16.h),
                child: OutlinedButton.icon(
                  onPressed: _adding ? null : _add,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_adding ? 'Reading files…' : 'Add more PDFs'),
                ),
              ),
              itemBuilder: (context, i) {
                final input = _inputs[i];
                return KeyedSubtree(
                  key: ObjectKey(input),
                  child: FileCard(
                    name: '${i + 1}. ${input.file.name}',
                    subtitle: input.summary,
                    actions: [
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _inputs.removeAt(i)),
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
            ),
          ),
        if (_inputs.isEmpty) const Spacer(),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
            child: ToolActionButton(
              label: _inputs.length < 2
                  ? 'Merge PDFs'
                  : 'Merge ${_inputs.length} PDFs · $totalPages pages',
              icon: Icons.merge_rounded,
              busy: _busy,
              onPressed: _inputs.length < 2 ? null : _merge,
            ),
          ),
        ),
      ],
    );
  }
}
