import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OcrTool extends StatefulWidget {
  const OcrTool({super.key});

  @override
  State<OcrTool> createState() => _OcrToolState();
}

class _OcrToolState extends State<OcrTool> {
  bool _isProcessing = false;
  String? _extractedText;
  File? _selectedImage;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _extractedText = null;
          _error = null;
        });
        _performOcr();
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _performOcr() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final inputImage = InputImage.fromFile(_selectedImage!);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();

      if (recognizedText.text.isEmpty) {
        setState(() {
          _error =
              'No text found in the image. Try a clearer photo with better lighting.';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _extractedText = recognizedText.text;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'OCR failed: $e';
        _isProcessing = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_extractedText != null) {
      Clipboard.setData(ClipboardData(text: _extractedText!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Text copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.r),
      child: Column(
        children: [
          // ─── Header Card ───
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(36.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF11998e).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.document_scanner_rounded,
                  size: 56,
                  color: Color(0xFF1E293B),
                ),
                SizedBox(height: 16.h),
                const Text(
                  'OCR Document Scanner',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 8.h),
                const Text(
                  'Extract text from photos of court orders, judgments, and legal documents',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_bolt,
                        size: 14,
                        color: Color(0xFF1E293B),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Works Offline · Google ML Kit',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _isProcessing
                              ? null
                              : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF11998e),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    OutlinedButton.icon(
                      onPressed:
                          _isProcessing
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
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

          // ─── Processing ───
          if (_isProcessing) ...[
            SizedBox(height: 40.h),
            const CircularProgressIndicator(),
            SizedBox(height: 16.h),
            const Text(
              'Analyzing document with ML Kit...',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],

          // ─── Error ───
          if (_error != null) ...[
            SizedBox(height: 32.h),
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13.sp),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ─── Results ───
          if (_extractedText != null) ...[
            SizedBox(height: 32.h),
            Row(
              children: [
                const Icon(
                  Icons.text_snippet,
                  size: 20,
                  color: AppTheme.primary,
                ),
                SizedBox(width: 8.w),
                const Expanded(
                  child: Text(
                    'EXTRACTED TEXT',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy All', style: TextStyle(fontSize: 12.sp)),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                _extractedText!,
                style: const TextStyle(height: 1.6.h, fontSize: 14.sp),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
