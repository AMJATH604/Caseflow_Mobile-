import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';
import 'page_rendering.dart';
import 'single_pdf_input.dart';

/// Renders pages to JPEGs; tests replace the platform renderer.
typedef JpegRenderer =
    Stream<Uint8List> Function(Uint8List pdf, List<int>? pages, double dpi, int quality, bool grayscale);

Stream<Uint8List> _platformJpegs(Uint8List pdf, List<int>? pages, double dpi, int quality, bool grayscale) =>
    PageRendering.jpegs(pdf, pages, dpi: dpi, quality: quality, grayscale: grayscale);

/// One file picked without reading it first (it may be locked or damaged).
Future<ToolFile?> _pickRawPdf(BuildContext context) async {
  try {
    final files = await DocumentFiles.pickPdfs(multiple: false);
    return files.isEmpty ? null : files.single;
  } catch (e) {
    if (context.mounted) showToolError(context, e);
    return null;
  }
}

// ── Compress ─────────────────────────────────────────────────────────

enum _Level {
  light('Light', 'Sharpest; smaller', 200, 80, false),
  recommended('Recommended', 'Clear to read, much smaller', 150, 70, false),
  strong('Strong', 'Smallest; black & white', 110, 60, true);

  final String title;
  final String detail;
  final double dpi;
  final int quality;
  final bool grayscale;
  const _Level(this.title, this.detail, this.dpi, this.quality, this.grayscale);
}

/// Shrinks a PDF on the phone by re-saving scanned pages at a lower
/// resolution. Typed pages are left untouched, so they stay sharp and
/// searchable.
class CompressPdfTool extends StatefulWidget {
  @visibleForTesting
  final PdfInput? initialInput;
  @visibleForTesting
  final JpegRenderer? renderJpegs;
  const CompressPdfTool({super.key, this.initialInput, this.renderJpegs});

  @override
  State<CompressPdfTool> createState() => _CompressPdfToolState();
}

class _CompressPdfToolState extends State<CompressPdfTool> {
  late PdfInput? _input = widget.initialInput;
  _Level _level = _Level.recommended;

  /// Also re-save pages that have text. An OCR'd scan has an invisible text
  /// layer on every page, so on its own Compress takes it for a typed
  /// document and leaves it as large as it was — exactly the file the
  /// portal rejects for size. Off by default: those pages become images.
  bool _includeText = false;
  bool _busy = false;
  String? _status;
  List<ToolFile>? _result;
  String _headline = '';

  Future<void> _pick() async {
    final input = await pickSinglePdf(context);
    if (input != null && mounted) setState(() => _input = input);
  }

  Future<void> _compress() async {
    final input = _input!;
    final original = input.file.bytes;
    setState(() {
      _busy = true;
      _status = 'Finding scanned pages…';
    });
    try {
      final scanned = _includeText
          ? [for (var i = 0; i < input.pageCount; i++) i]
          : await DocumentToolsService.scannedPages(original);
      var bytes = original;
      if (scanned.isNotEmpty) {
        final render = widget.renderJpegs ?? _platformJpegs;
        final images = <int, Uint8List>{};
        var n = 0;
        await for (final jpeg in render(original, scanned, _level.dpi, _level.quality, _level.grayscale)) {
          images[scanned[n++]] = jpeg;
          if (mounted) setState(() => _status = 'Page $n of ${scanned.length}…');
        }
        bytes = await DocumentToolsService.flattenPages(original, images);
      }
      if (mounted) setState(() => _status = 'Saving…');
      bytes = await DocumentToolsService.compressionRewrite(bytes);

      final before = original.length;
      if (bytes.length >= before) {
        // Nothing gained: hand back the original rather than a bigger copy.
        bytes = original;
        _headline = scanned.isEmpty
            ? 'Already compact: no scanned pages to shrink. If this is a '
                'scan with OCR text, turn on "Also shrink pages with text".'
            : 'Already as small as it can be at this level';
      } else {
        final saved = ((before - bytes.length) / before * 100).round();
        _headline = 'Compressed ${formatBytes(before)} → ${formatBytes(bytes.length)} ($saved% smaller)';
      }
      if (mounted) {
        setState(() => _result = [ToolFile('${baseName(input.file.name)}_compressed.pdf', bytes)]);
      }
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return ToolResultView(
        files: _result!,
        headline: _headline,
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
              label: _busy ? (_status ?? 'Working…') : 'Compress PDF',
              icon: Icons.compress_rounded,
              busy: _busy,
              onPressed: _compress,
            ),
      children: [
        const DocToolIntro(
          'Shrink a PDF to fit the e-Filing upload limit. Scanned pages are re-saved at a lower '
          'resolution; typed pages stay sharp and searchable. Runs on your phone.',
        ),
        if (input == null)
          PickTarget(
            icon: Icons.compress_rounded,
            title: 'Choose a PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          )
        else ...[
          PdfInputCard(input: input, onChange: _pick),
          const SectionLabel('Compression'),
          RadioGroup<_Level>(
            groupValue: _level,
            onChanged: (v) => setState(() => _level = v ?? _level),
            child: Column(
              children: [
                for (final level in _Level.values)
                  RadioListTile<_Level>(
                    value: level,
                    contentPadding: EdgeInsets.zero,
                    title: Text(level.title),
                    subtitle: Text('${level.detail} · ${level.dpi.round()} DPI'),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeText,
            onChanged: _busy ? null : (v) => setState(() => _includeText = v),
            title: const Text('Also shrink pages with text'),
            subtitle: const Text(
              'For scans that already have OCR text and are still too large. '
              'Those pages become images, so their text cannot be searched or '
              'copied until you run OCR again.',
            ),
          ),
        ],
      ],
    );
  }
}

// ── Protect / Unlock ─────────────────────────────────────────────────

enum PasswordMode { protect, unlock }

/// Adds an AES-256 password, or removes a password and print/copy
/// restrictions, on the phone. The password never leaves the device.
class PasswordPdfTool extends StatefulWidget {
  final PasswordMode mode;
  @visibleForTesting
  final ToolFile? initialFile;
  const PasswordPdfTool({super.key, required this.mode, this.initialFile});

  @override
  State<PasswordPdfTool> createState() => _PasswordPdfToolState();
}

class _PasswordPdfToolState extends State<PasswordPdfTool> {
  late ToolFile? _file = widget.initialFile;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  String? _error;
  bool _busy = false;
  List<ToolFile>? _result;

  bool get _protect => widget.mode == PasswordMode.protect;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await _pickRawPdf(context);
    if (file != null && mounted) {
      setState(() {
        _file = file;
        _error = null;
      });
    }
  }

  Future<void> _run() async {
    final file = _file!;
    final problem = !_protect
        ? null
        : _password.text.length < 4
        ? 'Use at least 4 characters'
        : (_password.text != _confirm.text ? 'The two passwords do not match' : null);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final bytes = _protect
          ? await DocumentToolsService.protect(file.bytes, _password.text)
          : await DocumentToolsService.unlock(file.bytes, _password.text);
      final suffix = _protect ? 'protected' : 'unlocked';
      if (mounted) setState(() => _result = [ToolFile('${baseName(file.name)}_$suffix.pdf', bytes)]);
    } on DocumentToolException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
        headline: _protect ? 'Password added (AES-256)' : 'Password and restrictions removed',
        onStartOver: () => setState(() {
          _file = null;
          _result = null;
          _password.clear();
          _confirm.clear();
        }),
        header: [
          if (_protect)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Text(
                'Keep the password safe: CaseFlow does not store it and cannot recover it.',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.warning, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      );
    }
    final file = _file;
    return DocToolLayout(
      action: file == null
          ? null
          : ToolActionButton(
              label: _protect ? 'Protect PDF' : 'Unlock PDF',
              icon: _protect ? Icons.lock_rounded : Icons.lock_open_rounded,
              busy: _busy,
              onPressed: _run,
            ),
      children: [
        DocToolIntro(
          _protect
              ? 'Lock a PDF with a password (AES-256) before sending it to a client. Done on your '
                    'phone; the password never leaves it.'
              : 'Remove the password from a PDF you have the password for, and any print or copy '
                    'restrictions, so it can be merged or filed.',
        ),
        if (file == null)
          PickTarget(
            icon: _protect ? Icons.lock_rounded : Icons.lock_open_rounded,
            title: _protect ? 'Choose a PDF' : 'Choose a locked PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          )
        else ...[
          FileCard(
            name: file.name,
            subtitle: file.sizeLabel,
            actions: [TextButton(onPressed: _busy ? null : _pick, child: const Text('Change'))],
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _password,
            obscureText: !_show,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: _protect ? 'New password' : 'PDF password',
              helperText: _protect ? null : 'Leave empty if the PDF opens without one',
              suffixIcon: IconButton(
                tooltip: _show ? 'Hide password' : 'Show password',
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_protect) ...[
            SizedBox(height: 8.h),
            TextField(
              controller: _confirm,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Type it again'),
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ),
        ],
      ],
    );
  }
}

// ── Repair ───────────────────────────────────────────────────────────

/// Fixes PDFs that will not open or that the portal rejects as damaged:
/// first by rebuilding the file's index (keeps everything), and as a last
/// resort by re-drawing each page as an image.
class RepairPdfTool extends StatefulWidget {
  @visibleForTesting
  final ToolFile? initialFile;
  @visibleForTesting
  final JpegRenderer? renderJpegs;
  const RepairPdfTool({super.key, this.initialFile, this.renderJpegs});

  @override
  State<RepairPdfTool> createState() => _RepairPdfToolState();
}

class _RepairPdfToolState extends State<RepairPdfTool> {
  late ToolFile? _file = widget.initialFile;
  bool _busy = false;
  List<ToolFile>? _result;
  String _headline = '';
  String? _note;

  Future<void> _pick() async {
    final file = await _pickRawPdf(context);
    if (file != null && mounted) setState(() => _file = file);
  }

  Future<void> _repair() async {
    final file = _file!;
    setState(() => _busy = true);
    try {
      var bytes = await DocumentToolsService.repair(file.bytes);
      if (bytes != null) {
        _headline = 'PDF repaired';
        _note = 'The file\'s index was rebuilt; all text, pages and links are kept.';
      } else {
        // Last resort: the platform renderer is far more forgiving.
        final render = widget.renderJpegs ?? _platformJpegs;
        final pages = <Uint8List>[];
        try {
          await for (final jpeg in render(file.bytes, null, 150, 85, false)) {
            pages.add(jpeg);
          }
        } catch (_) {
          // Handled below.
        }
        if (pages.isEmpty) {
          throw const DocumentToolException(
            'This file is too damaged to recover, or is not a PDF. Ask the sender for a fresh copy.',
          );
        }
        bytes = await DocumentToolsService.imagesToPdf(
          pages,
          prep: const ImagePrepOptions(quality: ScanQuality.high),
          layout: const ImagesToPdfOptions(pageSize: PageSizeOption.fitImage),
        );
        _headline = 'Recovered ${pages.length} page${pages.length == 1 ? '' : 's'}';
        _note = 'The pages were re-created as images, so their text cannot be selected. '
            'Run OCR to make it searchable again.';
      }
      if (mounted) setState(() => _result = [ToolFile('${baseName(file.name)}_repaired.pdf', bytes!)]);
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
        headline: _headline,
        onStartOver: () => setState(() {
          _file = null;
          _result = null;
        }),
        header: [
          if (_note != null)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Text(_note!, style: TextStyle(fontSize: 12.sp, color: mutedText(context), height: 1.4)),
            ),
        ],
      );
    }
    final file = _file;
    return DocToolLayout(
      action: file == null
          ? null
          : ToolActionButton(label: 'Repair PDF', icon: Icons.build_rounded, busy: _busy, onPressed: _repair),
      children: [
        const DocToolIntro(
          'Fix a PDF that will not open, or that the e-Filing portal rejects as damaged. '
          'Runs on your phone.',
        ),
        if (file == null)
          PickTarget(
            icon: Icons.build_rounded,
            title: 'Choose the damaged PDF',
            subtitle: 'From your phone, Drive or WhatsApp files',
            onTap: _pick,
          )
        else
          FileCard(
            name: file.name,
            subtitle: file.sizeLabel,
            actions: [TextButton(onPressed: _busy ? null : _pick, child: const Text('Change'))],
          ),
      ],
    );
  }
}
