import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/models.dart';
import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/pdf_engine.dart' show DocumentToolException;
import '../../../services/providers.dart';
import '../../../theme/app_theme.dart';

/// A case to save into directly, when a tool was opened from that case.
class CaseTarget {
  final String id;
  final String title;
  const CaseTarget(this.id, this.title);
}

/// Uploads [files] to the case's Documents, never overwriting a document of
/// the same name. Checks every size first so a batch is never half saved.
/// Returns the names used.
Future<List<String>> saveFilesToCase(WidgetRef ref, String caseId, List<ToolFile> files) async {
  files.forEach(DocumentFiles.checkCaseDocumentSize);
  final existing = await ref.read(caseDocumentsProvider(caseId).future);
  final taken = [for (final d in existing) d['name'].toString()];
  final saved = <String>[];
  for (final file in files) {
    saved.add(
      await DocumentFiles.saveToCase(caseId, file, existingNames: [...taken, ...saved]),
    );
  }
  ref.invalidate(caseDocumentsProvider(caseId));
  return saved;
}

String _savedMessage(List<String> saved, String caseTitle) => saved.length == 1
    ? 'Saved "${saved.single}" to $caseTitle › Documents'
    : 'Saved ${saved.length} files to $caseTitle › Documents';

SnackBar _saveError(Object e) => SnackBar(
  content: Text(e is DocumentToolException ? e.message : 'Could not save to the case: $e'),
  backgroundColor: AppTheme.error,
);

/// "Save to case": straight into [target] when given, otherwise lets the
/// user choose a case.
class SaveToCaseButton extends ConsumerStatefulWidget {
  final List<ToolFile> files;
  final CaseTarget? target;
  final bool primary;
  const SaveToCaseButton({super.key, required this.files, this.target, this.primary = true});

  @override
  ConsumerState<SaveToCaseButton> createState() => _SaveToCaseButtonState();
}

class _SaveToCaseButtonState extends ConsumerState<SaveToCaseButton> {
  bool _saving = false;

  Future<void> _onPressed() async {
    final target = widget.target;
    if (target == null) return SaveToCaseSheet.show(context, widget.files);
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await saveFilesToCase(ref, target.id, widget.files);
      messenger.showSnackBar(SnackBar(content: Text(_savedMessage(saved, target.title))));
    } catch (e) {
      messenger.showSnackBar(_saveError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.files.length;
    final label = widget.target != null
        ? (count == 1 ? 'Save to this case' : 'Save all $count to this case')
        : (count == 1 ? 'Save to case' : 'Save all $count to a case');
    final icon = _saving
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.folder_shared_outlined, size: 18);
    final onPressed = _saving ? null : _onPressed;
    return widget.primary
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 46.h),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: icon,
            label: Text(label),
            style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 46.h)),
          );
  }
}

/// Bottom sheet that files tool results into one of the user's cases
/// (the case's Documents tab).
class SaveToCaseSheet extends ConsumerStatefulWidget {
  final List<ToolFile> files;
  const SaveToCaseSheet._(this.files);

  static Future<void> show(BuildContext context, List<ToolFile> files) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SaveToCaseSheet._(files),
    );
  }

  @override
  ConsumerState<SaveToCaseSheet> createState() => _SaveToCaseSheetState();
}

class _SaveToCaseSheetState extends ConsumerState<SaveToCaseSheet> {
  String _query = '';
  String? _savingCaseId;

  Future<void> _save(CaseModel caseModel) async {
    setState(() => _savingCaseId = caseModel.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await saveFilesToCase(ref, caseModel.id, widget.files);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(_savedMessage(saved, caseModel.caseTitle))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingCaseId = null);
      messenger.showSnackBar(_saveError(e));
    }
  }

  bool _matches(CaseModel c) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return [c.caseTitle, c.caseNumber, c.clientName, c.courtName, c.cnrNumber]
        .whereType<String>()
        .any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(casesProvider);
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFCBD5E1)
        : Colors.black54;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save to case',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4.h),
                Text(
                  widget.files.length == 1
                      ? '"${widget.files.single.name}" will be added to the case\'s Documents.'
                      : '${widget.files.length} files will be added to the case\'s Documents.',
                  style: TextStyle(fontSize: 12.sp, color: muted),
                ),
                SizedBox(height: 12.h),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search by title, number, client or CNR',
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ],
            ),
          ),
          Expanded(
            child: casesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load your cases: $e')),
              data: (cases) {
                final shown = cases.where(_matches).toList();
                if (shown.isEmpty) {
                  return Center(
                    child: Text(cases.isEmpty ? 'You have no cases yet.' : 'No matching cases.'),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final c = shown[i];
                    final details = [c.caseNumber, c.courtName]
                        .whereType<String>()
                        .where((v) => v.isNotEmpty)
                        .join(' · ');
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined, color: AppTheme.accent),
                      title: Text(c.caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: details.isEmpty ? null : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: _savingCaseId == c.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      enabled: _savingCaseId == null,
                      onTap: () => _save(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
