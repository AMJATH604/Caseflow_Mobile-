import 'package:flutter/material.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import 'doc_tool_widgets.dart';

/// A picked PDF and how many pages it has.
class PdfInput {
  final ToolFile file;
  final int pageCount;
  const PdfInput(this.file, this.pageCount);

  String get summary => '$pageCount page${pageCount == 1 ? '' : 's'} · ${file.sizeLabel}';
}

/// Lets the user choose one PDF and reads its page count. Shows the reason
/// and returns null if the file cannot be used.
Future<PdfInput?> pickSinglePdf(BuildContext context) async {
  try {
    final files = await DocumentFiles.pickPdfs(multiple: false);
    if (files.isEmpty) return null;
    final count = await DocumentToolsService.pageCount(files.single.bytes);
    return PdfInput(files.single, count);
  } catch (e) {
    if (context.mounted) showToolError(context, e);
    return null;
  }
}

/// The picked file with a "change" button.
class PdfInputCard extends StatelessWidget {
  final PdfInput input;
  final VoidCallback onChange;
  const PdfInputCard({super.key, required this.input, required this.onChange});

  @override
  Widget build(BuildContext context) => FileCard(
    name: input.file.name,
    subtitle: input.summary,
    actions: [TextButton(onPressed: onChange, child: const Text('Change'))],
  );
}
