import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

/// Dialog for adding/viewing notes on a hearing
/// Notes are stored in the hearing's 'notes' field in Supabase
class HearingNotesDialog extends StatefulWidget {
  final String hearingId;
  final String caseTitle;
  final DateTime hearingDate;
  final String? existingNotes;
  final VoidCallback onSaved;

  const HearingNotesDialog({
    super.key,
    required this.hearingId,
    required this.caseTitle,
    required this.hearingDate,
    this.existingNotes,
    required this.onSaved,
  });

  @override
  State<HearingNotesDialog> createState() => _HearingNotesDialogState();
}

class _HearingNotesDialogState extends State<HearingNotesDialog> {
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.existingNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.client
          .from('hearings')
          .update({'notes': _notesController.text})
          .eq('id', widget.hearingId);
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notes saved!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: AppTheme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hearing Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${widget.caseTitle} • ${DateFormat('dd MMM yyyy').format(widget.hearingDate)}",
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick note chips
            const Text(
              'Quick Notes:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _quickChip('Adjourned'),
                _quickChip('Arguments heard'),
                _quickChip('Evidence recorded'),
                _quickChip('Written arguments filed'),
                _quickChip('Order reserved'),
                _quickChip('Matter dismissed'),
                _quickChip('Judgment pronounced'),
                _quickChip('Next date fixed'),
              ],
            ),
            const SizedBox(height: 16),

            // Notes text field
            TextField(
              controller: _notesController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText:
                    'Type your hearing notes here...\n\nE.g. Judge asked for written arguments by next date.\nOpposing counsel requested adjournment.',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveNotes,
                icon:
                    _isSaving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String text) {
    return InkWell(
      onTap: () {
        final current = _notesController.text;
        _notesController.text = current.isEmpty ? text : '$current\n$text';
        _notesController.selection = TextSelection.collapsed(
          offset: _notesController.text.length,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
