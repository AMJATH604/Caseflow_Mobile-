import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/providers.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'dossier_shared.dart';

class IASection extends ConsumerStatefulWidget {
  final String caseId;

  const IASection({super.key, required this.caseId});

  @override
  ConsumerState<IASection> createState() => _IASectionState();
}

class _IASectionState extends ConsumerState<IASection> {
  void _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete IA?'),
            content: const Text(
              'Are you sure you want to remove this IA entry?',
            ),
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
      await SupabaseService.deleteCaseIA(id);
      ref.invalidate(caseIAProvider(widget.caseId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddIADialog() {
    final iaNumberCtrl = TextEditingController();
    final partyCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    DateTime? filingDate;
    String status = 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => Container(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.8,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Add IA Application',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: iaNumberCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'IA Number',
                            hintText: 'IA/1/2023',
                            prefixIcon: const Icon(Icons.tag_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: partyCtrl,
                          decoration: InputDecoration(
                            labelText: 'Party Name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: classCtrl,
                          decoration: InputDecoration(
                            labelText: 'Classification',
                            hintText: 'Injunction / Stay',
                            prefixIcon: const Icon(Icons.category_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Filing Date'),
                          subtitle: Text(
                            filingDate != null
                                ? DateFormat('dd MMM yyyy').format(filingDate!)
                                : 'Select date',
                          ),
                          trailing: const Icon(
                            Icons.calendar_today,
                            color: AppTheme.accent,
                          ),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) setSheetState(() => filingDate = d);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items:
                              ['pending', 'disposed', 'allowed', 'dismissed']
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        s[0].toUpperCase() + s.substring(1),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => status = v ?? 'pending',
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (iaNumberCtrl.text.trim().isEmpty) return;
                              Navigator.pop(ctx);
                              try {
                                await SupabaseService.createCaseIA({
                                  'case_id': widget.caseId,
                                  'ia_number': iaNumberCtrl.text.trim(),
                                  'party':
                                      partyCtrl.text.trim().isNotEmpty
                                          ? partyCtrl.text.trim()
                                          : null,
                                  'classification':
                                      classCtrl.text.trim().isNotEmpty
                                          ? classCtrl.text.trim()
                                          : null,
                                  'filing_date':
                                      filingDate?.toIso8601String().split(
                                        'T',
                                      )[0],
                                  'ia_status': status,
                                });
                                ref.invalidate(caseIAProvider(widget.caseId));
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text(
                              'Add IA',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iaAsync = ref.watch(caseIAProvider(widget.caseId));

    return DossierSection(
      icon: Icons.layers_rounded,
      title: 'IA Applications',
      color: const Color(0xFFF59E0B),
      initiallyExpanded: iaAsync.value?.isNotEmpty == true,
      trailing: DossierHelper.addButton(() => _showAddIADialog()),
      children: [
        iaAsync.when(
          data:
              (ias) =>
                  ias.isEmpty
                      ? DossierHelper.emptyHint(
                        'No Interlocutory Applications. Tap + to add.',
                      )
                      : Column(
                        children:
                            ias.map((ia) {
                              final statusColor =
                                  ia.iaStatus == 'disposed'
                                      ? const Color(0xFF10B981)
                                      : ia.iaStatus == 'pending'
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF3B82F6);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.darkBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ia.iaNumber,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          if (ia.party != null)
                                            Text(
                                              ia.party!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              if (ia.filingDate != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 12,
                                                      ),
                                                  child: Text(
                                                    "FILED: ${DateFormat('dd MMM').format(ia.filingDate!)}",
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  ia.iaStatus.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w900,
                                                    color: statusColor,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _deleteItem(ia.id),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
          loading:
              () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          error: (e, _) => DossierHelper.emptyHint('Error loading IAs'),
        ),
      ],
    );
  }
}
