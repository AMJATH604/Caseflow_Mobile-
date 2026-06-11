import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Premium Witnesses Tab — PW/DW/CW tagging, examination status, gradient avatars.
class CaseWitnessesTab extends ConsumerStatefulWidget {
  final String caseId;
  const CaseWitnessesTab({super.key, required this.caseId});

  @override
  ConsumerState<CaseWitnessesTab> createState() => _CaseWitnessesTabState();
}

class _CaseWitnessesTabState extends ConsumerState<CaseWitnessesTab> {
  static const _tagColors = <String, List<Color>>{
    'PW': [Color(0xFF2563EB), Color(0xFF3B82F6)],
    'DW': [Color(0xFFDC2626), Color(0xFFEF4444)],
    'CW': [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
  };

  static const _avatarGradients = [
    [Color(0xFF6366F1), Color(0xFF818CF8)],
    [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  ];

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(witnessNotesProvider(widget.caseId));

    return Stack(
      children: [
        notesAsync.when(
          data: (notes) {
            if (notes.isEmpty) return _buildEmptyState();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: notes.length,
              itemBuilder: (_, i) => _buildWitnessCard(notes[i], i),
            );
          },
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        // FAB
        Positioned(bottom: 24, right: 20, child: _buildAddFab()),
      ],
    );
  }

  // ─── WITNESS CARD ────────────────────────────────────
  Widget _buildWitnessCard(WitnessNote note, int index) {
    final tag = note.witnessTag.toUpperCase();
    final tagPrefix = tag.replaceAll(RegExp(r'[0-9]'), '');
    final colors = _tagColors[tagPrefix] ?? _tagColors['CW']!;
    final avatarColors = _avatarGradients[index % _avatarGradients.length];
    final initial =
        note.witnessName.isNotEmpty ? note.witnessName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                // Gradient Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: avatarColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: avatarColors[0].withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name + Tag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.witnessName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Tag Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: colors),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Full label
                          Text(
                            _getTagLabel(tagPrefix),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors[0],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await SupabaseService.deleteWitnessNote(note.id);
                      ref.invalidate(witnessNotesProvider(widget.caseId));
                    }
                  },
                  itemBuilder:
                      (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Color(0xFFEF4444),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete Witness',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),

          // Examination Status Row
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                _examChip(
                  'Chief',
                  Icons.record_voice_over_rounded,
                  const Color(0xFF10B981),
                  true,
                ),
                const SizedBox(width: 12),
                _examChip(
                  'Cross',
                  Icons.gavel_rounded,
                  const Color(0xFFF59E0B),
                  false,
                ),
                const SizedBox(width: 12),
                _examChip(
                  'Re-Exam',
                  Icons.replay_rounded,
                  const Color(0xFF94A3B8),
                  false,
                ),
              ],
            ),
          ),

          // Notes
          if (note.notes != null && note.notes!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEF3C7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 14,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Date footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Text(
                  "Added ${DateFormat('dd MMM yyyy').format(note.createdAt)}",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _examChip(String label, IconData icon, Color color, bool isDone) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isDone ? color : const Color(0xFFCBD5E1),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDone ? color : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  String _getTagLabel(String prefix) {
    switch (prefix) {
      case 'PW':
        return 'Plaintiff Witness';
      case 'DW':
        return 'Defendant Witness';
      case 'CW':
        return 'Court Witness';
      default:
        return 'Witness';
    }
  }

  // ─── EMPTY STATE ─────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              size: 48,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Witnesses Recorded',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add PW, DW, or CW witnesses\nwith examination notes',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  'Add First Witness',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ADD FAB ─────────────────────────────────────────
  Widget _buildAddFab() {
    return GestureDetector(
      onTap: _showAddWitnessSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Add Witness',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADD WITNESS BOTTOM SHEET ────────────────────────
  void _showAddWitnessSheet() {
    String name = '';
    String tag = 'PW1';
    String notes = '';

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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Witness',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Record witness details for this case',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Witness Name
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Witness Name',
                        prefixIcon: const Icon(Icons.person_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 16),

                    // Tag Selector
                    const Text(
                      'Witness Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children:
                          ['PW', 'DW', 'CW'].map((type) {
                            final sel = tag.startsWith(type);
                            final colors = _tagColors[type]!;
                            return Expanded(
                              child: GestureDetector(
                                onTap:
                                    () => setSheetState(() => tag = '${type}1'),
                                child: Container(
                                  margin: EdgeInsets.only(
                                    right: type != 'CW' ? 8 : 0,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient:
                                        sel
                                            ? LinearGradient(colors: colors)
                                            : null,
                                    color: sel ? null : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        sel
                                            ? null
                                            : Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        type,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color:
                                              sel
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getTagLabel(type),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color:
                                              sel
                                                  ? Colors.white.withValues(
                                                    alpha: 0.8,
                                                  )
                                                  : const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Tag Number
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Tag (e.g., PW1, DW2)',
                        prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      controller: TextEditingController(text: tag),
                      onChanged: (v) => tag = v,
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Examination Notes (Optional)',
                        prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      maxLines: 3,
                      onChanged: (v) => notes = v,
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (name.isEmpty) return;
                          Navigator.pop(ctx);
                          try {
                            await SupabaseService.createWitnessNote({
                              'case_id': widget.caseId,
                              'witness_name': name,
                              'witness_tag': tag,
                              'notes': notes.isNotEmpty ? notes : null,
                            });
                            ref.invalidate(witnessNotesProvider(widget.caseId));
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save Witness',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
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
}
