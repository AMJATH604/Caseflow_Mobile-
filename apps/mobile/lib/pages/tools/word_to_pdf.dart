import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';

class WordToPdf extends StatefulWidget {
  const WordToPdf({super.key});

  @override
  State<WordToPdf> createState() => _WordToPdfState();
}

class _WordToPdfState extends State<WordToPdf> {
  PlatformFile? _file;
  bool _isProcessing = false;
  bool _isDone = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['doc', 'docx'],
    );
    if (result != null) {
      setState(() {
        _file = result.files.first;
        _isDone = false;
      });
      _simulateConversion();
    }
  }

  Future<void> _simulateConversion() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      _isProcessing = false;
      _isDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withRed(100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.picture_as_pdf,
                  size: 64,
                  color: Color(0xFF1E293B),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Word to PDF Converter",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Convert your .docx legal drafts to PDF instantly",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _pickFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isProcessing ? "Converting..." : "Select Word File",
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing) ...[
            const SizedBox(height: 48),
            const LinearProgressIndicator(minHeight: 8),
            const SizedBox(height: 16),
            const Text(
              "Optimizing document structure...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
          if (_isDone) ...[
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    "${_file?.name ?? 'Document'} converted successfully!",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download),
                        label: const Text("Download PDF"),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.share),
                        label: const Text("Share"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
