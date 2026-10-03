import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/pdf_engine.dart' show DocumentToolException;
import '../../../services/document_tools/server_tools_client.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';

/// The tools that need the CaseFlow document server. (Compress, Protect,
/// Unlock and Repair run on the phone: see `pdf_maintenance_tools.dart`.)
enum ServerTool {
  wordToPdf(
    'word-to-pdf',
    'Word to PDF',
    'Convert a Word document to PDF, ready to file. Tamil and Hindi text is kept.',
    ['doc', 'docx', 'odt', 'rtf'],
    'Choose a Word file',
    Icons.description_rounded,
  ),
  ocr(
    'ocr-pdf',
    'OCR (Searchable PDF)',
    'Make a scanned PDF or photo searchable: the text becomes selectable, as courts prefer. '
        'English, Tamil and Hindi.',
    ['pdf', 'jpg', 'jpeg', 'png'],
    'Choose a scanned PDF or photo',
    Icons.text_fields_rounded,
  ),
  pdfToWord(
    'pdf-to-word',
    'PDF to Word',
    'Turn a PDF into an editable Word document, e.g. to reuse an old pleading.',
    ['pdf'],
    'Choose a PDF',
    Icons.edit_document,
  ),
  pdfToExcel(
    'pdf-to-excel',
    'PDF to Excel',
    'Pull the tables out of a PDF into an Excel sheet, e.g. account statements.',
    ['pdf'],
    'Choose a PDF',
    Icons.table_chart_rounded,
  ),
  excelToPdf(
    'excel-to-pdf',
    'Excel to PDF',
    'Convert a spreadsheet to PDF.',
    ['xls', 'xlsx', 'ods'],
    'Choose an Excel file',
    Icons.grid_on_rounded,
  ),
  powerpointToPdf(
    'powerpoint-to-pdf',
    'PowerPoint to PDF',
    'Convert a presentation to PDF, one slide per page.',
    ['ppt', 'pptx', 'odp'],
    'Choose a PowerPoint file',
    Icons.slideshow_rounded,
  );

  final String slug;
  final String title;
  final String intro;
  final List<String> extensions;
  final String pickLabel;
  final IconData icon;
  const ServerTool(this.slug, this.title, this.intro, this.extensions, this.pickLabel, this.icon);
}

/// One screen for every server tool: pick a file, set the tool's options,
/// run the job with progress and cancel, then the usual result actions.
class ServerToolScreen extends StatefulWidget {
  final ServerTool tool;

  /// Defaults to [ServerToolsClient.shared]; tests pass their own.
  final ServerToolsClient? client;

  /// A file to start with, so tests need not drive the file picker.
  @visibleForTesting
  final ToolFile? initialFile;
  const ServerToolScreen({super.key, required this.tool, this.client, this.initialFile});

  @override
  State<ServerToolScreen> createState() => _ServerToolScreenState();
}

class _ServerToolScreenState extends State<ServerToolScreen> {
  late ToolFile? _input = widget.initialFile;
  bool _busy = false;
  JobProgress? _progress;
  CancelToken? _cancel;
  ServerOutput? _output;
  String? _error;

  // Options.
  final Set<String> _languages = {'eng', 'tam'};
  bool _cleanUp = true;
  bool _redoText = false;
  String _layout = 'pages';
  final _pages = TextEditingController();

  ServerTool get _tool => widget.tool;

  @override
  void dispose() {
    // Leaving mid-job cancels it; the client then deletes it on the server.
    _cancel?.cancel();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await DocumentFiles.pickFile(_tool.extensions);
      if (file != null && mounted) {
        setState(() {
          _input = file;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) showToolError(context, e);
    }
  }

  /// The options JSON for the server, or null with [_error] set.
  Map<String, Object?>? _options() {
    switch (_tool) {
      case ServerTool.ocr:
        if (_languages.isEmpty) {
          setState(() => _error = 'Choose at least one language');
          return null;
        }
        return {
          'languages': [for (final l in const ['eng', 'tam', 'hin']) if (_languages.contains(l)) l],
          'mode': _redoText ? 'force' : 'skip',
          'clean_up': _cleanUp,
        };
      case ServerTool.excelToPdf:
        return {'layout': _layout};
      case ServerTool.pdfToExcel:
        return {'pages': _pages.text.trim()};
      default:
        return const {};
    }
  }

  Future<void> _run() async {
    final client = widget.client ?? ServerToolsClient.shared;
    final options = _options();
    if (options == null || client == null) return;
    final cancel = CancelToken();
    setState(() {
      _error = null;
      _busy = true;
      _cancel = cancel;
      _progress = const JobProgress(JobPhase.uploading, 0);
    });
    try {
      final output = await client.run(
        _tool.slug,
        [_input!],
        options: options,
        cancel: cancel,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) setState(() => _output = output);
    } on DocumentToolException catch (e) {
      if (mounted && !cancel.isCancelled) showToolError(context, e);
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _cancel = null;
          _progress = null;
        });
      }
    }
  }

  void _reset() => setState(() {
    _input = null;
    _output = null;
  });

  @override
  Widget build(BuildContext context) {
    final output = _output;
    if (output != null) {
      return ToolResultView(
        files: [output.file],
        headline: _headline(output),
        onStartOver: _reset,
        header: [
          if (output.note != null)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Text(
                output.note!,
                style: TextStyle(fontSize: 12.sp, color: mutedText(context), height: 1.4),
              ),
            ),
        ],
      );
    }

    final input = _input;
    return DocToolLayout(
      action: input == null
          ? null
          : _busy
          ? _ProgressPanel(progress: _progress, onCancel: () => _cancel?.cancel())
          : ToolActionButton(
              label: _tool == ServerTool.ocr ? 'Make searchable' : _tool.title,
              icon: _tool.icon,
              onPressed: _run,
            ),
      children: [
        DocToolIntro(_tool.intro),
        if (input == null)
          PickTarget(
            icon: _tool.icon,
            title: _tool.pickLabel,
            subtitle: _tool.extensions.map((e) => e.toUpperCase()).join(', '),
            onTap: _pick,
          )
        else ...[
          FileCard(
            name: input.name,
            subtitle: '${input.kindLabel} · ${input.sizeLabel}',
            leading: fileTypeIcon(input),
            actions: [
              TextButton(onPressed: _busy ? null : _pick, child: const Text('Change')),
            ],
          ),
          ..._optionsFields(),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 16, color: mutedText(context)),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Processed on the CaseFlow document server over an encrypted connection, '
                  'and deleted from it as soon as you have the result.',
                  style: TextStyle(fontSize: 11.sp, color: mutedText(context), height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _headline(ServerOutput output) => switch (_tool) {
    ServerTool.ocr => 'Text is now searchable',
    _ => 'Converted to ${output.file.kindLabel}',
  };

  List<Widget> _optionsFields() {
    switch (_tool) {
      case ServerTool.ocr:
        return [
          const SectionLabel('Languages in the document'),
          Wrap(
            spacing: 8.w,
            children: [
              for (final (code, name) in const [('eng', 'English'), ('tam', 'Tamil'), ('hin', 'Hindi')])
                FilterChip(
                  label: Text(name),
                  selected: _languages.contains(code),
                  onSelected: (on) => setState(() {
                    on ? _languages.add(code) : _languages.remove(code);
                    _error = null;
                  }),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              'Pick only the languages present; each extra one makes OCR slower.',
              style: TextStyle(fontSize: 11.sp, color: mutedText(context)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Straighten and turn pages upright'),
            value: _cleanUp,
            onChanged: (v) => setState(() => _cleanUp = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Redo pages that already have text'),
            subtitle: const Text('Only if earlier OCR is poor'),
            value: _redoText,
            onChanged: (v) => setState(() => _redoText = v),
          ),
        ];
      case ServerTool.excelToPdf:
        return [
          const SectionLabel('Layout'),
          ChoiceRow<String>(
            options: const {'pages': 'As printed', 'sheet': 'Each sheet on one page'},
            value: _layout,
            onChanged: (v) => setState(() => _layout = v),
          ),
        ];
      case ServerTool.pdfToExcel:
        return [
          SizedBox(height: 12.h),
          TextField(
            controller: _pages,
            decoration: const InputDecoration(
              labelText: 'Pages (optional)',
              hintText: 'e.g. 1-3, 5 (blank for all)',
            ),
          ),
        ];
      default:
        return const [];
    }
  }
}

class _ProgressPanel extends StatelessWidget {
  final JobProgress? progress;
  final VoidCallback onCancel;
  const _ProgressPanel({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                p?.label ?? 'Working…',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
        LinearProgressIndicator(value: p?.fraction, minHeight: 6),
      ],
    );
  }
}
