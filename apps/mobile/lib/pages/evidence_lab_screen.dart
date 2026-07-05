import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Premium Evidence Lab — No double header, custom segmented pills,
/// premium checklist cards, modern witness lab, and staggered photo vault.
class EvidenceLabScreen extends ConsumerStatefulWidget {
  final String caseId;
  const EvidenceLabScreen({super.key, required this.caseId});

  @override
  ConsumerState<EvidenceLabScreen> createState() => _EvidenceLabScreenState();
}

class _EvidenceLabScreenState extends ConsumerState<EvidenceLabScreen> {
  int _selectedTab = 0;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentVoiceNote = '';

  static const _tabLabels = ['Checklist', 'Witness Lab', 'Photo Vault'];
  static const _tabIcons = [
    Icons.fact_check_rounded,
    Icons.record_voice_over_rounded,
    Icons.photo_library_rounded,
  ];
  static const _tabColors = [
    Color(0xFF2563EB),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
  ];

  static const _typeColors = <String, Color>{
    'document': Color(0xFF2563EB),
    'witness': Color(0xFF8B5CF6),
    'exhibit': Color(0xFFEC4899),
    'pending': Color(0xFFF59E0B),
  };

  static const _typeIcons = <String, IconData>{
    'document': Icons.description_rounded,
    'witness': Icons.person_rounded,
    'exhibit': Icons.collections_rounded,
    'pending': Icons.pending_actions_rounded,
  };

  @override
  Widget build(BuildContext context) {
    // No Scaffold — embeds directly as a tab
    return Column(
      children: [
        SizedBox(height: 12.h),
        _buildSegmentedControl(),
        SizedBox(height: 12.h),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _buildChecklistTab(),
              _buildWitnessLabTab(),
              _buildPhotoVaultTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── SEGMENTED PILL CONTROL ──────────────────────────
  Widget _buildSegmentedControl() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final sel = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow:
                      sel
                          ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _tabIcons[i],
                      size: 15,
                      color: sel ? _tabColors[i] : const Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      _tabLabels[i],
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: sel ? _tabColors[i] : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── CHECKLIST TAB ────────────────────────────────────
  // ═══════════════════════════════════════════════════════
  Widget _buildChecklistTab() {
    final checklistAsync = ref.watch(evidenceChecklistProvider(widget.caseId));

    return checklistAsync.when(
      data: (items) {
        final completed = items.where((i) => i.isCompleted).length;
        final total = items.length;

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // Progress header
                if (total > 0) ...[
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48.w,
                          height: 48.h,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: total > 0 ? completed / total : 0,
                                strokeWidth: 5,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF10B981),
                                ),
                              ),
                              Text(
                                '${total > 0 ? ((completed / total) * 100).round() : 0}%',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preparation Progress',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.sp,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '$completed of $total items completed',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                ],

                // Checklist Items
                ...items.map((item) => _buildChecklistCard(item)),

                if (items.isEmpty)
                  _buildInlineEmptyState(
                    'No checklist items yet',
                    'Add documents, exhibits, and witness prep items',
                    Icons.fact_check_rounded,
                    const Color(0xFF2563EB),
                  ),
              ],
            ),
            // FAB
            Positioned(
              bottom: 24.h,
              right: 20.w,
              child: _buildActionFab(
                'Add Item',
                Icons.add_task_rounded,
                const Color(0xFF2563EB),
                _showAddItemDialog,
              ),
            ),
          ],
        );
      },
      loading:
          () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildChecklistCard(dynamic item) {
    final typeColor = _typeColors[item.itemType] ?? const Color(0xFF94A3B8);
    final typeIcon = _typeIcons[item.itemType] ?? Icons.pending_actions_rounded;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      onDismissed: (_) async {
        await SupabaseService.deleteEvidenceChecklistItem(item.id);
        ref.invalidate(evidenceChecklistProvider(widget.caseId));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color:
                item.isCompleted
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Custom Checkbox
            GestureDetector(
              onTap: () async {
                await SupabaseService.updateEvidenceChecklistItem(item.id, {
                  'is_completed': !item.isCompleted,
                });
                ref.invalidate(evidenceChecklistProvider(widget.caseId));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28.w,
                height: 28.h,
                decoration: BoxDecoration(
                  gradient:
                      item.isCompleted
                          ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF34D399)],
                          )
                          : null,
                  color: item.isCompleted ? null : Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  border:
                      item.isCompleted
                          ? null
                          : Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 2.w,
                          ),
                ),
                child:
                    item.isCompleted
                        ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                        : null,
              ),
            ),
            SizedBox(width: 12.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                      color:
                          item.isCompleted
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                      decoration:
                          item.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
            // Type Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(typeIcon, size: 12, color: typeColor),
                  SizedBox(width: 4.w),
                  Text(
                    item.itemType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      color: typeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    String name = '';
    String type = 'document';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: const Icon(
                            Icons.add_task_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Prep Item',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18.sp,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Track evidence preparation',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: const Icon(Icons.edit_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      onChanged: (v) => name = v,
                      autofocus: true,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                        color: Color(0xFF334155),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ['document', 'witness', 'exhibit', 'pending'].map((
                            t,
                          ) {
                            final sel = type == t;
                            final color = _typeColors[t]!;
                            return GestureDetector(
                              onTap: () => setSheetState(() => type = t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient:
                                      sel
                                          ? LinearGradient(
                                            colors: [
                                              color,
                                              color.withValues(alpha: 0.7),
                                            ],
                                          )
                                          : null,
                                  color: sel ? null : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border:
                                      sel
                                          ? null
                                          : Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _typeIcons[t],
                                      size: 16,
                                      color:
                                          sel
                                              ? Colors.white
                                              : const Color(0xFF64748B),
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      t.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            sel
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (name.isNotEmpty) {
                            await SupabaseService.createEvidenceChecklistItem({
                              'case_id': widget.caseId,
                              'item_name': name,
                              'item_type': type,
                            });
                            ref.invalidate(
                              evidenceChecklistProvider(widget.caseId),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Add Item',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── WITNESS LAB TAB ──────────────────────────────────
  // ═══════════════════════════════════════════════════════
  Widget _buildWitnessLabTab() {
    final notesAsync = ref.watch(witnessNotesProvider(widget.caseId));

    return Column(
      children: [
        _buildVoiceRecorder(),
        Expanded(
          child: notesAsync.when(
            data: (notes) {
              if (notes.isEmpty) {
                return _buildInlineEmptyState(
                  'No voice notes yet',
                  'Record examination notes using the microphone',
                  Icons.record_voice_over_rounded,
                  const Color(0xFF8B5CF6),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: notes.length,
                itemBuilder: (_, i) => _buildVoiceNoteCard(notes[i], i),
              );
            },
            loading:
                () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceRecorder() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              _isListening
                  ? [const Color(0xFFFEF2F2), const Color(0xFFFFF7ED)]
                  : [const Color(0xFFF5F3FF), const Color(0xFFEEF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color:
              _isListening ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color:
                      _isListening
                          ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                          : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  size: 20,
                  color:
                      _isListening
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF8B5CF6),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  _isListening ? 'Listening...' : 'Voice Examination Lab',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.sp,
                    color:
                        _isListening
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0F172A),
                  ),
                ),
              ),
              // Record button
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          _isListening
                              ? [
                                const Color(0xFFEF4444),
                                const Color(0xFFF87171),
                              ]
                              : [
                                const Color(0xFF8B5CF6),
                                const Color(0xFFA78BFA),
                              ],
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    _isListening ? 'Stop' : 'Record',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_currentVoiceNote.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                _currentVoiceNote,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Color(0xFF334155),
                  height: 1.4.h,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _currentVoiceNote = ''),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: _saveVoiceNote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Note',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceNoteCard(dynamic note, int index) {
    final tagColors = <String, List<Color>>{
      'PW': [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
      'DW': [const Color(0xFFDC2626), const Color(0xFFEF4444)],
      'CW': [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
    };
    final prefix = note.witnessTag.toUpperCase().replaceAll(
      RegExp(r'[0-9]'),
      '',
    );
    final colors = tagColors[prefix] ?? tagColors['CW']!;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              note.witnessTag.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.witnessName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.sp,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (note.notes != null && note.notes!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    note.notes!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Color(0xFF64748B),
                      height: 1.4.h,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 6.h),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(note.createdAt),
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Color(0xFFEF4444),
            ),
            onPressed: () async {
              await SupabaseService.deleteWitnessNote(note.id);
              ref.invalidate(witnessNotesProvider(widget.caseId));
            },
          ),
        ],
      ),
    );
  }

  void _toggleListening() async {
    if (!_isListening) {
      final bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() => _currentVoiceNote = val.recognizedWords);
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _saveVoiceNote() {
    String tag = 'PW1';
    String name = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Save Voice Note',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18.sp,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 20.h),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Witness Name',
                    prefixIcon: const Icon(Icons.person_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  onChanged: (v) => name = v,
                  autofocus: true,
                ),
                SizedBox(height: 12.h),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Tag (e.g., PW1, DW1)',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  controller: TextEditingController(text: tag),
                  onChanged: (v) => tag = v,
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (name.isNotEmpty) {
                        await SupabaseService.createWitnessNote({
                          'case_id': widget.caseId,
                          'witness_name': name,
                          'witness_tag': tag,
                          'notes': _currentVoiceNote,
                        });
                        ref.invalidate(witnessNotesProvider(widget.caseId));
                        setState(() => _currentVoiceNote = '');
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── PHOTO VAULT TAB ──────────────────────────────────
  // ═══════════════════════════════════════════════════════
  Widget _buildPhotoVaultTab() {
    final photosAsync = ref.watch(evidencePhotosProvider(widget.caseId));

    return Stack(
      children: [
        photosAsync.when(
          data: (photos) {
            if (photos.isEmpty) {
              return _buildInlineEmptyState(
                'No evidence photos',
                'Capture or upload visual evidence',
                Icons.photo_library_rounded,
                const Color(0xFFF59E0B),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) => _buildPhotoCard(photos[i]),
            );
          },
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        // Capture FAB
        Positioned(
          bottom: 24.h,
          right: 20.w,
          child: _buildActionFab(
            'Capture',
            Icons.camera_alt_rounded,
            const Color(0xFFF59E0B),
            _capturePhoto,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(dynamic photo) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.photoUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: Color(0xFF94A3B8),
                      size: 32,
                    ),
                  ),
            ),
            // Gradient overlay at bottom
            Positioned(
              bottom: 0.h,
              left: 0.w,
              right: 0.w,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        photo.description ?? 'Evidence',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await SupabaseService.deleteEvidencePhoto(photo.id);
                        ref.invalidate(evidencePhotosProvider(widget.caseId));
                      },
                      child: Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tags
            if (photo.tags.isNotEmpty)
              Positioned(
                top: 8.h,
                left: 8.w,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    photo.tags.first.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await SupabaseService.createEvidencePhoto({
        'case_id': widget.caseId,
        'photo_url':
            'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&q=80&w=300',
        'description':
            "Evidence captured on ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
      });
      ref.invalidate(evidencePhotosProvider(widget.caseId));
    }
  }

  // ─── SHARED HELPERS ──────────────────────────────────
  Widget _buildInlineEmptyState(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: color),
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16.sp,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFab(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
