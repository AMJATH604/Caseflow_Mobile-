import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Self-contained Documents tab for a case.
/// Displays uploaded files with download/delete actions and an upload FAB.
class CaseDocumentsTab extends ConsumerWidget {
  final String caseId;
  const CaseDocumentsTab({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(caseDocumentsProvider(caseId));
    return Stack(
      children: [
        docsAsync.when(
          data:
              (docs) =>
                  docs.isEmpty
                      ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_shared_rounded,
                              size: 48,
                              color: Color(0xFFE2E8F0),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'RECORDS VAULT EMPTY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final name = doc['name'] as String? ?? 'Unknown';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.darkCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.darkBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _docIcon(name),
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'SECURE VAULT',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    color: AppTheme.accent,
                                    size: 22,
                                  ),
                                  tooltip: 'Download',
                                  onPressed: () async {
                                    final url = doc['url'] as String?;
                                    if (url != null) {
                                      final uri = Uri.parse(url);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_sweep_rounded,
                                    color: AppTheme.error.withValues(
                                      alpha: 0.7,
                                    ),
                                    size: 22,
                                  ),
                                  tooltip: 'Delete',
                                  onPressed:
                                      () => _deleteDocument(
                                        context,
                                        ref,
                                        caseId,
                                        name,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
          error:
              (e, s) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Color(0xFF1E293B)),
                ),
              ),
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            heroTag: 'upload_doc',
            onPressed: () => _uploadDocument(context, ref, caseId),
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
            elevation: 8,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────

  IconData _docIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    return Icons.insert_drive_file;
  }

  Future<void> _uploadDocument(
    BuildContext context,
    WidgetRef ref,
    String caseId,
  ) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    try {
      await SupabaseService.uploadDocument(caseId, file.bytes!, file.name);
      ref.invalidate(caseDocumentsProvider(caseId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${file.name}" uploaded successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
    String caseId,
    String fileName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Document?'),
            content: Text('Are you sure you want to delete "$fileName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    try {
      await SupabaseService.deleteDocument(caseId, fileName);
      ref.invalidate(caseDocumentsProvider(caseId));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"$fileName" deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}
