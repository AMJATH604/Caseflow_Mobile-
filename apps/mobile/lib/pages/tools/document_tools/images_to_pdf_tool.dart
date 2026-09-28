import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/document_tools_service.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';

enum ImageSourceMode { scan, images }

class _ImageItem {
  final ToolFile file;
  int turns = 0;
  _ImageItem(this.file);
}

/// Scan to PDF (camera with edge detection) and Images to PDF (photos,
/// WhatsApp images) share this screen; [mode] picks the first action.
class ImagesToPdfTool extends StatefulWidget {
  final ImageSourceMode mode;
  const ImagesToPdfTool({super.key, required this.mode});

  @override
  State<ImagesToPdfTool> createState() => _ImagesToPdfToolState();
}

class _ImagesToPdfToolState extends State<ImagesToPdfTool> {
  final List<_ImageItem> _items = [];
  late bool _grayscale = widget.mode == ImageSourceMode.scan;
  ScanQuality _quality = ScanQuality.standard;
  PageSizeOption _pageSize = PageSizeOption.a4;
  int _margin = 0; // points
  bool _adding = false;
  bool _busy = false;
  List<ToolFile>? _result;

  bool get _isScan => widget.mode == ImageSourceMode.scan;

  Future<void> _addFrom(Future<List<ToolFile>> Function() source) async {
    setState(() => _adding = true);
    try {
      final files = await source();
      if (mounted) setState(() => _items.addAll(files.map(_ImageItem.new)));
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<List<ToolFile>> _scan() async {
    try {
      final paths = await CunningDocumentScanner.getPictures(
        scannerSource: ScannerSource.camera,
      );
      if (paths == null) return const [];
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final files = [
        for (var i = 0; i < paths.length; i++)
          ToolFile('scan_${stamp}_${i + 1}.jpg', await File(paths[i]).readAsBytes()),
      ];
      // The scanner keeps its own copies; the pages are in memory now.
      await CunningDocumentScanner.cleanCache().catchError((_) {});
      return files;
    } on CunningDocumentScannerException catch (e) {
      throw DocumentToolException(
        e.code == 'permission_denied'
            ? 'CaseFlow needs camera access to scan. Allow it in your phone settings.'
            : 'The scanner could not start: ${e.message}',
      );
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final bytes = await DocumentToolsService.imagesToPdf(
        [for (final i in _items) i.file.bytes],
        quarterTurns: [for (final i in _items) i.turns],
        prep: ImagePrepOptions(quality: _quality, grayscale: _grayscale),
        layout: ImagesToPdfOptions(pageSize: _pageSize, margin: _margin.toDouble()),
      );
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final name = '${_isScan ? 'Scan' : 'Images'}_$stamp.pdf';
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
        headline: 'PDF created · ${_items.length} page${_items.length == 1 ? '' : 's'}',
        onStartOver: () => setState(() {
          _items.clear();
          _result = null;
        }),
      );
    }

    final addButtons = Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        if (_isScan)
          OutlinedButton.icon(
            onPressed: _adding ? null : () => _addFrom(_scan),
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(_items.isEmpty ? 'Scan' : 'Scan more'),
          ),
        OutlinedButton.icon(
          onPressed: _adding ? null : () => _addFrom(DocumentFiles.pickImagesFromGallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Gallery'),
        ),
        OutlinedButton.icon(
          onPressed: _adding ? null : () => _addFrom(DocumentFiles.pickImageFiles),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Files'),
        ),
      ],
    );

    return DocToolLayout(
      action: _items.isEmpty
          ? null
          : ToolActionButton(
              label: 'Create PDF · ${_items.length} page${_items.length == 1 ? '' : 's'}',
              icon: Icons.picture_as_pdf_rounded,
              busy: _busy,
              onPressed: _create,
            ),
      children: [
        DocToolIntro(
          _isScan
              ? 'Scan paper documents with the camera. Edges are found and straightened automatically; each scan becomes a page.'
              : 'Turn photos and WhatsApp images into one PDF, one image per page.',
        ),
        if (_items.isEmpty) ...[
          PickTarget(
            icon: _isScan ? Icons.document_scanner_rounded : Icons.image_rounded,
            title: _adding ? 'Loading…' : (_isScan ? 'Start scanning' : 'Choose images'),
            subtitle: _isScan ? 'Uses the camera' : 'From the gallery',
            onTap: _adding
                ? () {}
                : () => _addFrom(_isScan ? _scan : DocumentFiles.pickImagesFromGallery),
          ),
          SizedBox(height: 12.h),
          addButtons,
        ] else ...[
          _buildPages(),
          SizedBox(height: 8.h),
          addButtons,
          const SectionLabel('Colour'),
          ChoiceRow<bool>(
            options: const {true: 'Black & white (grey)', false: 'Colour'},
            value: _grayscale,
            onChanged: (v) => setState(() => _grayscale = v),
          ),
          const SectionLabel('Quality'),
          ChoiceRow<ScanQuality>(
            options: const {
              ScanQuality.standard: '200 DPI · smaller',
              ScanQuality.high: '300 DPI · sharper',
            },
            value: _quality,
            onChanged: (v) => setState(() => _quality = v),
          ),
          const SectionLabel('Page size'),
          ChoiceRow<PageSizeOption>(
            options: const {
              PageSizeOption.a4: 'A4',
              PageSizeOption.fitImage: 'Same as image',
            },
            value: _pageSize,
            onChanged: (v) => setState(() => _pageSize = v),
          ),
          const SectionLabel('Margin'),
          ChoiceRow<int>(
            options: const {0: 'None', 18: 'Small', 36: 'Normal'},
            value: _margin,
            onChanged: (v) => setState(() => _margin = v),
          ),
          SizedBox(height: 12.h),
          Text(
            'For e-filing, black & white at 200 DPI on A4 is usually enough and keeps the file small.',
            style: TextStyle(fontSize: 12.sp, color: mutedText(context)),
          ),
        ],
      ],
    );
  }

  Widget _buildPages() {
    return SizedBox(
      height: 190.h,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: _items.length,
        onReorder: (from, to) => setState(() {
          if (to > from) to--;
          _items.insert(to, _items.removeAt(from));
        }),
        itemBuilder: (context, i) {
          final item = _items[i];
          return ReorderableDelayedDragStartListener(
            key: ObjectKey(item),
            index: i,
            child: Container(
              width: 110.w,
              margin: EdgeInsets.only(right: 10.w),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        color: Colors.white,
                      ),
                      child: AnimatedRotation(
                        turns: item.turns / 4,
                        duration: const Duration(milliseconds: 200),
                        child: Image.memory(
                          item.file.bytes,
                          fit: BoxFit.contain,
                          cacheWidth: 300,
                          color: _grayscale ? Colors.grey : null,
                          colorBlendMode: _grayscale ? BlendMode.saturation : null,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined, color: AppTheme.error),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${i + 1}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Turn right',
                        icon: const Icon(Icons.rotate_right_rounded, size: 20),
                        onPressed: () => setState(() => item.turns++),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => setState(() => _items.removeAt(i)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
