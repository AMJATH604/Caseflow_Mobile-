import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/pdf_engine.dart' show DocumentToolException;
import '../../../services/document_tools/server_tools_client.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';

/// The tools that run on the CaseFlow document server.
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
  compress(
    'compress-pdf',
    'Compress PDF',
    'Shrink a PDF to fit the e-Filing upload limit, mostly by reducing scanned images.',
    ['pdf'],
    'Choose a PDF',
    Icons.compress_rounded,
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
  ),
  protect(
    'protect-pdf',
    'Protect PDF',
    'Lock a PDF with a password before sending it to a client. CaseFlow does not keep the password.',
    ['pdf'],
    'Choose a PDF',
    Icons.lock_rounded,
  ),
  unlock(
    'unlock-pdf',
    'Unlock PDF',
    'Remove the password from a PDF you have the password for, so it can be merged or filed.',
    ['pdf'],
    'Choose a locked PDF',
    Icons.lock_open_rounded,
  ),
  repair(
    'repair-pdf',
    'Repair PDF',
    'Fix a PDF that will not open or that the e-Filing portal rejects as damaged.',
    ['pdf'],
    'Choose a PDF',
    Icons.build_rounded,
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
  String _level = 'recommended';
  String _layout = 'pages';
  final _pages = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;

  ServerTool get _tool => widget.tool;

  @override
  void dispose() {
    // Leaving mid-job cancels it; the client then deletes it on the server.
    _cancel?.cancel();
    _pages.dispose();
    _password.dispose();
    _confirm.dispose();
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
      case ServerTool.compress:
        return {'level': _level};
      case ServerTool.excelToPdf:
        return {'layout': _layout};
      case ServerTool.pdfToExcel:
        return {'pages': _pages.text.trim()};
      case ServerTool.protect:
        if (_password.text.length < 4) {
          setState(() => _error = 'Use at least 4 characters');
          return null;
        }
        if (_password.text != _confirm.text) {
          setState(() => _error = 'The two passwords do not match');
          return null;
        }
        return {'password': _password.text};
      case ServerTool.unlock:
        if (_password.text.isEmpty) {
          setState(() => _error = 'Enter the PDF password');
          return null;
        }
        return {'password': _password.text};
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
    _password.clear();
    _confirm.clear();
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

  String _headline(ServerOutput output) {
    if (_tool == ServerTool.compress) {
      final before = _input!.bytes.length;
      final after = output.file.bytes.length;
      final saved = before == 0 ? 0 : ((before - after) / before * 100).round();
      return saved > 0
          ? 'Compressed ${formatBytes(before)} → ${formatBytes(after)} ($saved% smaller)'
          : 'Already as small as it can be';
    }
    return switch (_tool) {
      ServerTool.ocr => 'Text is now searchable',
      ServerTool.protect => 'Password added',
      ServerTool.unlock => 'Password removed',
      ServerTool.repair => 'PDF repaired',
      _ => 'Converted to ${output.file.kindLabel}',
    };
  }

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
      case ServerTool.compress:
        return [
          const SectionLabel('Compression'),
          RadioGroup<String>(
            groupValue: _level,
            onChanged: (v) => setState(() => _level = v ?? _level),
            child: Column(
              children: [
                for (final (value, title, detail) in const [
                  ('low', 'Light', 'Best quality; small saving'),
                  ('recommended', 'Recommended', 'Clear to read, much smaller (150 DPI)'),
                  ('extreme', 'Strong', 'Smallest file; fine print may blur'),
                ])
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: value,
                    title: Text(title),
                    subtitle: Text(detail),
                  ),
              ],
            ),
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
      case ServerTool.protect:
      case ServerTool.unlock:
        return [
          SizedBox(height: 12.h),
          TextField(
            controller: _password,
            obscureText: !_showPassword,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: _tool == ServerTool.protect ? 'New password' : 'PDF password',
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_tool == ServerTool.protect) ...[
            SizedBox(height: 8.h),
            TextField(
              controller: _confirm,
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Type it again'),
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
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
