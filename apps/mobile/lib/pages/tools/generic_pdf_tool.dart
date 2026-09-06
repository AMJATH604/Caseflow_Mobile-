import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/local_pdf_service.dart';
import '../../services/ilovepdf_service.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GenericPdfTool extends StatefulWidget {
  final String toolId;
  final String title;
  final String description;
  final IconData icon;
  final List<String> allowedExtensions;
  final String targetExtension;
  final Map<String, dynamic>? toolParams;

  const GenericPdfTool({
    super.key,
    required this.toolId,
    required this.title,
    required this.description,
    required this.icon,
    required this.allowedExtensions,
    required this.targetExtension,
    this.toolParams,
  });

  @override
  State<GenericPdfTool> createState() => _GenericPdfToolState();
}

class _GenericPdfToolState extends State<GenericPdfTool> {
  // ─── State ───
  List<PlatformFile> _selectedFiles = [];
  bool _isProcessing = false;
  double _progress = 0;
  String? _outputPath;
  String? _error;

  // ─── Tool-specific option state ───
  // Rotate
  int _rotateDegrees = 90;
  // Split
  String _splitMode = 'all'; // 'all' or 'range'
  final TextEditingController _splitRangeController = TextEditingController(
    text: '1-3',
  );
  // Compress
  String _compressLevel = 'recommended'; // 'low', 'recommended', 'maximum'
  // Watermark
  final TextEditingController _watermarkTextController = TextEditingController(
    text: 'CONFIDENTIAL',
  );
  double _watermarkOpacity = 0.25;
  double _watermarkFontSize = 60;
  // PDF to JPG
  String _jpgQuality = 'high'; // 'low', 'medium', 'high'
  // JPG to PDF
  String _pageSize = 'a4'; // 'a4', 'letter', 'original'

  bool get _isMultiFile =>
      widget.toolId == 'merge' || widget.toolId == 'imagepdf';
  bool get _isLocalTool => !_iLovePdfOnly.contains(widget.toolId);
  static const _iLovePdfOnly = {'officepdf', 'pdfword', 'pdfocr'};

  bool get _hasSelectedFiles => _selectedFiles.isNotEmpty;
  bool get _showOptionsStep =>
      _hasSelectedFiles && !_isProcessing && _outputPath == null;

  @override
  void dispose() {
    _splitRangeController.dispose();
    _watermarkTextController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  FILE PICK
  // ═══════════════════════════════════════════════════════════
  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _outputPath = null;
      _progress = 0;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.allowedExtensions,
      allowMultiple: _isMultiFile,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFiles = result.files);
      // DON'T auto-process — wait for user to configure options
    }
  }

  Future<void> _addMoreFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.allowedExtensions,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFiles = [..._selectedFiles, ...result.files]);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles = List.from(_selectedFiles)..removeAt(index);
    });
  }

  void _reorderFiles(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final item = _selectedFiles.removeAt(oldIdx);
      _selectedFiles.insert(newIdx, item);
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  PROCESS
  // ═══════════════════════════════════════════════════════════
  Future<void> _processFile() async {
    if (_selectedFiles.isEmpty || _selectedFiles.first.path == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.05;
    });

    try {
      String outputPath;
      if (_isLocalTool) {
        outputPath = await _runLocalTool();
      } else {
        outputPath = await ILovePdfService.runTool(
          tool: widget.toolId,
          inputFile: File(_selectedFiles.first.path!),
          targetExtension: widget.targetExtension,
          params: widget.toolParams,
          onProgress: (p) => setState(() => _progress = p),
        );
      }
      setState(() {
        _outputPath = outputPath;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  Future<String> _runLocalTool() async {
    final files =
        _selectedFiles
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();
    final primaryFile = files.first;
    void progress(double p) => setState(() => _progress = p);

    switch (widget.toolId) {
      case 'merge':
        if (files.length < 2) {
          throw Exception('Please select at least 2 PDF files to merge.');
        }
        return await LocalPdfService.mergePdfs(files, onProgress: progress);

      case 'split':
        final pageRange =
            _splitMode == 'range' ? _splitRangeController.text.trim() : null;
        return await LocalPdfService.splitPdf(
          primaryFile,
          pageRange: pageRange,
          onProgress: progress,
        );

      case 'compress':
        return await LocalPdfService.compressPdf(
          primaryFile,
          level: _compressLevel,
          onProgress: progress,
        );

      case 'rotate':
        return await LocalPdfService.rotatePdf(
          primaryFile,
          _rotateDegrees,
          onProgress: progress,
        );

      case 'watermark':
        return await LocalPdfService.addWatermark(
          primaryFile,
          _watermarkTextController.text.trim().isEmpty
              ? 'CONFIDENTIAL'
              : _watermarkTextController.text.trim(),
          opacity: _watermarkOpacity,
          fontSize: _watermarkFontSize,
          onProgress: progress,
        );

      case 'imagepdf':
        return await LocalPdfService.imagesToPdf(
          files,
          pageSize: _pageSize,
          onProgress: progress,
        );

      case 'pdfjpg':
        return await LocalPdfService.pdfToImages(
          primaryFile,
          quality: _jpgQuality,
          onProgress: progress,
        );

      default:
        throw Exception('Tool "${widget.toolId}" is not supported locally.');
    }
  }

  void _openFile() {
    if (_outputPath != null) OpenFile.open(_outputPath);
  }

  void _shareFile() {
    if (_outputPath != null) Share.shareXFiles([XFile(_outputPath!)]);
  }

  void _reset() {
    setState(() {
      _selectedFiles = [];
      _outputPath = null;
      _error = null;
      _progress = 0;
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Column(
        children: [
          _buildHeader(),
          if (_showOptionsStep) ...[
            SizedBox(height: 20.h),
            _buildSelectedFilesCard(),
            SizedBox(height: 16.h),
            _buildOptionsPanel(),
            SizedBox(height: 20.h),
            _buildProcessButton(),
          ],
          if (_isProcessing) _buildProgressSection(),
          if (_error != null) _buildErrorSection(),
          if (_outputPath != null) _buildSuccessSection(),
        ],
      ),
    );
  }

  // ─── Header Card ───
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(widget.icon, size: 52, color: const Color(0xFF1E293B)),
          SizedBox(height: 12.h),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xBBFFFFFF), fontSize: 13.sp),
          ),
          if (_isLocalTool) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.offline_bolt, size: 13, color: Color(0xFF1E293B)),
                  SizedBox(width: 4.w),
                  Text(
                    'Works Offline',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!_hasSelectedFiles || _outputPath != null) ...[
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed:
                  _isProcessing
                      ? null
                      : () {
                        if (_outputPath != null) _reset();
                        _pickFile();
                      },
              icon: Icon(
                _isMultiFile ? Icons.file_copy : Icons.upload_file,
                size: 18,
              ),
              label: Text(
                _outputPath != null
                    ? 'Process Another'
                    : _isMultiFile
                    ? 'Select Files'
                    : 'Select File',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Selected Files Card ───
  Widget _buildSelectedFilesCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: 18, color: AppTheme.primary),
              SizedBox(width: 8.w),
              Text(
                "${_selectedFiles.length} file${_selectedFiles.length > 1 ? 's' : ''} selected",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
              Spacer(),
              if (_isMultiFile)
                TextButton.icon(
                  onPressed: _addMoreFiles,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Add More', style: TextStyle(fontSize: 12.sp)),
                ),
            ],
          ),
          Divider(height: 16.h),
          if (_isMultiFile)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedFiles.length,
              onReorder: _reorderFiles,
              itemBuilder:
                  (context, i) => _buildFileRow(
                    i,
                    key: ValueKey(_selectedFiles[i].name + i.toString()),
                  ),
            )
          else
            ..._selectedFiles.asMap().entries.map((e) => _buildFileRow(e.key)),
        ],
      ),
    );
  }

  Widget _buildFileRow(int index, {Key? key}) {
    final f = _selectedFiles[index];
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          if (_isMultiFile) ...[
            Icon(Icons.drag_handle, size: 18, color: Colors.grey),
            SizedBox(width: 6.w),
            Container(
              width: 22.w,
              height: 22.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Icon(Icons.insert_drive_file, size: 16, color: Colors.blueGrey),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              f.name,
              style: TextStyle(fontSize: 12.sp),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${(f.size / 1024).toStringAsFixed(0)} KB',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey),
          ),
          if (_isMultiFile && _selectedFiles.length > 1) ...[
            SizedBox(width: 4.w),
            InkWell(
              onTap: () => _removeFile(index),
              child: const Icon(Icons.close, size: 16, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TOOL-SPECIFIC OPTIONS PANELS
  // ═══════════════════════════════════════════════════════════
  Widget _buildOptionsPanel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: AppTheme.primary),
              SizedBox(width: 8.w),
              Text(
                'Options',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildToolOptions(),
        ],
      ),
    );
  }

  Widget _buildToolOptions() {
    switch (widget.toolId) {
      case 'rotate':
        return _buildRotateOptions();
      case 'split':
        return _buildSplitOptions();
      case 'compress':
        return _buildCompressOptions();
      case 'watermark':
        return _buildWatermarkOptions();
      case 'pdfjpg':
        return _buildPdfToJpgOptions();
      case 'imagepdf':
        return _buildImageToPdfOptions();
      case 'merge':
        return _buildMergeOptions();
      default:
        return const Text(
          'Ready to process!',
          style: TextStyle(color: Colors.grey),
        );
    }
  }

  // ─── ROTATE ───
  Widget _buildRotateOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose rotation direction:',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            _rotateButton(Icons.rotate_left, '90° Left', -90),
            SizedBox(width: 10.w),
            _rotateButton(Icons.rotate_right, '90° Right', 90),
            SizedBox(width: 10.w),
            _rotateButton(Icons.sync, '180°', 180),
          ],
        ),
      ],
    );
  }

  Widget _rotateButton(IconData icon, String label, int degrees) {
    final selected =
        _rotateDegrees == degrees || (_rotateDegrees == 270 && degrees == -90);
    final actualDegrees = degrees == -90 ? 270 : degrees;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _rotateDegrees = actualDegrees),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color:
                selected
                    ? AppTheme.primary.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.05),
            border: Border.all(
              color:
                  selected
                      ? AppTheme.primary
                      : Colors.grey.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? AppTheme.primary : Colors.grey,
              ),
              SizedBox(height: 6.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppTheme.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SPLIT ───
  Widget _buildSplitOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How would you like to split?',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey),
        ),
        SizedBox(height: 12.h),
        _optionTile(
          'All Pages',
          'Each page becomes a separate PDF',
          _splitMode == 'all',
          () => setState(() => _splitMode = 'all'),
          Icons.select_all,
        ),
        SizedBox(height: 8.h),
        _optionTile(
          'Specific Pages',
          'Choose which pages to extract',
          _splitMode == 'range',
          () => setState(() => _splitMode = 'range'),
          Icons.filter_list,
        ),
        if (_splitMode == 'range') ...[
          SizedBox(height: 12.h),
          TextField(
            controller: _splitRangeController,
            decoration: InputDecoration(
              labelText: 'Page numbers',
              hintText: 'e.g. 1, 3, 5-8',
              prefixIcon: const Icon(Icons.numbers, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            keyboardType: TextInputType.text,
          ),
        ],
      ],
    );
  }

  // ─── COMPRESS ───
  Widget _buildCompressOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose compression level:',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey),
        ),
        SizedBox(height: 12.h),
        _optionTile(
          'Low Compression',
          'Best quality, larger file',
          _compressLevel == 'low',
          () => setState(() => _compressLevel = 'low'),
          Icons.high_quality,
        ),
        SizedBox(height: 8.h),
        _optionTile(
          'Recommended',
          'Good quality, balanced size',
          _compressLevel == 'recommended',
          () => setState(() => _compressLevel = 'recommended'),
          Icons.recommend,
        ),
        SizedBox(height: 8.h),
        _optionTile(
          'Maximum Compression',
          'Smallest file, may reduce quality',
          _compressLevel == 'maximum',
          () => setState(() => _compressLevel = 'maximum'),
          Icons.compress,
        ),
      ],
    );
  }

  // ─── WATERMARK ───
  Widget _buildWatermarkOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _watermarkTextController,
          decoration: InputDecoration(
            labelText: 'Watermark Text',
            hintText: 'e.g. CONFIDENTIAL, DRAFT, etc.',
            prefixIcon: const Icon(Icons.text_fields, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        SizedBox(height: 20.h),
        Row(
          children: [
            Icon(Icons.opacity, size: 16, color: Colors.grey),
            SizedBox(width: 8.w),
            Text('Opacity', style: TextStyle(fontSize: 13.sp)),
            Spacer(),
            Text(
              '${(_watermarkOpacity * 100).toInt()}%',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
            ),
          ],
        ),
        Slider(
          value: _watermarkOpacity,
          min: 0.05,
          max: 0.8,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() => _watermarkOpacity = v),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Icon(Icons.format_size, size: 16, color: Colors.grey),
            SizedBox(width: 8.w),
            Text('Font Size', style: TextStyle(fontSize: 13.sp)),
            Spacer(),
            Text(
              '${_watermarkFontSize.toInt()}pt',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
            ),
          ],
        ),
        Slider(
          value: _watermarkFontSize,
          min: 20,
          max: 120,
          activeColor: AppTheme.primary,
          onChanged: (v) => setState(() => _watermarkFontSize = v),
        ),
      ],
    );
  }

  // ─── PDF TO JPG ───
  Widget _buildPdfToJpgOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose image quality:',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey),
        ),
        SizedBox(height: 12.h),
        _optionTile(
          'Low Quality',
          'Smaller images, faster export',
          _jpgQuality == 'low',
          () => setState(() => _jpgQuality = 'low'),
          Icons.photo_size_select_small,
        ),
        SizedBox(height: 8.h),
        _optionTile(
          'Medium Quality',
          'Balanced size and quality',
          _jpgQuality == 'medium',
          () => setState(() => _jpgQuality = 'medium'),
          Icons.photo_size_select_large,
        ),
        SizedBox(height: 8.h),
        _optionTile(
          'High Quality',
          'Best quality for printing',
          _jpgQuality == 'high',
          () => setState(() => _jpgQuality = 'high'),
          Icons.hd,
        ),
      ],
    );
  }

  // ─── JPG TO PDF ───
  Widget _buildImageToPdfOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose page size:',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey),
        ),
        SizedBox(height: 12.h),
        _optionTile(
          'A4 (Standard)',
          '210 × 297 mm — Most common',
          _pageSize == 'a4',
          () => setState(() => _pageSize = 'a4'),
          Icons.description,
        ),
        SizedBox(height: 8.h),
        _optionTile(
          'Letter (US)',
          '8.5 × 11 in — US standard',
          _pageSize == 'letter',
          () => setState(() => _pageSize = 'letter'),
          Icons.article,
        ),
        SizedBox(height: 8.h),
        _optionTile(
          'Original Size',
          'Match image dimensions',
          _pageSize == 'original',
          () => setState(() => _pageSize = 'original'),
          Icons.aspect_ratio,
        ),
      ],
    );
  }

  // ─── MERGE ───
  Widget _buildMergeOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.swap_vert, size: 16, color: Colors.grey),
            SizedBox(width: 8.w),
            Text(
              'Drag files above to reorder them',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Files will be merged in the order shown above.',
                  style: TextStyle(fontSize: 12.sp, color: Colors.blue[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Shared option tile widget ───
  Widget _optionTile(
    String title,
    String subtitle,
    bool selected,
    VoidCallback onTap,
    IconData icon,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.04),
          border: Border.all(
            color:
                selected
                    ? AppTheme.primary
                    : Colors.grey.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppTheme.primary : Colors.grey,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      color: selected ? AppTheme.primary : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color:
                          selected
                              ? AppTheme.primary.withValues(alpha: 0.7)
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }

  // ─── Process Button ───
  Widget _buildProcessButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _processFile,
        icon: const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(
          _getProcessLabel(),
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 4,
          shadowColor: AppTheme.accent.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  String _getProcessLabel() {
    switch (widget.toolId) {
      case 'merge':
        return 'Merge ${_selectedFiles.length} Files';
      case 'split':
        return 'Split PDF';
      case 'compress':
        return 'Compress PDF';
      case 'rotate':
        return 'Rotate PDF';
      case 'watermark':
        return 'Add Watermark';
      case 'imagepdf':
        return 'Convert to PDF';
      case 'pdfjpg':
        return 'Extract Images';
      default:
        return 'Process';
    }
  }

  // ─── Progress Section ───
  Widget _buildProgressSection() {
    return Padding(
      padding: EdgeInsets.only(top: 32.h),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            _getProgressText(),
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error Section ───
  Widget _buildErrorSection() {
    return Padding(
      padding: EdgeInsets.only(top: 32.h),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red, fontSize: 13.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Success Section ───
  Widget _buildSuccessSection() {
    return Padding(
      padding: EdgeInsets.only(top: 32.h),
      child: Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.05),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 56),
            SizedBox(height: 16.h),
            Text(
              'Success!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _isLocalTool
                  ? 'Processed locally on your device'
                  : 'File saved to local storage',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _openFile,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Open'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                OutlinedButton.icon(
                  onPressed: _shareFile,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getProgressText() {
    if (_isLocalTool) {
      if (_progress < 0.3) return 'Reading file...';
      if (_progress < 0.7) return 'Processing locally on your device...';
      if (_progress < 0.9) return 'Almost done...';
      return 'Saving output file...';
    } else {
      if (_progress < 0.3) return 'Starting secure task...';
      if (_progress < 0.6) return 'Uploading to secure server...';
      if (_progress < 0.8) return 'Processing on cloud engines...';
      return 'Downloading results...';
    }
  }
}
