import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/case_dossier_models.dart';
import '../../services/providers.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'dossier_shared.dart';

class ActsSection extends ConsumerWidget {
  final String caseId;

  const ActsSection({super.key, required this.caseId});

  void _deleteItem(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Delete act?"),
            content: const Text(
              "Are you sure you want to remove this act entry?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Delete"),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.deleteCaseAct(id);
      ref.invalidate(caseActsProvider(caseId));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showAddActDialog(BuildContext context, WidgetRef ref) {
    final actCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
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
                  "Add Applicable Act",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "e.g., Code of Civil Procedure — Or.7.R.1",
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: actCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Act Name",
                    hintText: "Code of Civil Procedure",
                    prefixIcon: const Icon(Icons.menu_book_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  decoration: InputDecoration(
                    labelText: "Section / Order / Rule",
                    hintText: "Or.7.R.1",
                    prefixIcon: const Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (actCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        await SupabaseService.createCaseAct({
                          'case_id': caseId,
                          'act_name': actCtrl.text.trim(),
                          'section_number':
                              sectionCtrl.text.trim().isNotEmpty
                                  ? sectionCtrl.text.trim()
                                  : null,
                        });
                        ref.invalidate(caseActsProvider(caseId));
                      } catch (e) {
                        if (context.mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      "Add Act",
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actsAsync = ref.watch(caseActsProvider(caseId));

    return DossierSection(
      icon: Icons.gavel_rounded,
      title: "Statutory Acts",
      color: const Color(0xFF6366F1),
      initiallyExpanded: actsAsync.value?.isNotEmpty == true,
      trailing: DossierHelper.addButton(() => _showAddActDialog(context, ref)),
      children: [
        actsAsync.when(
          data:
              (acts) =>
                  acts.isEmpty
                      ? DossierHelper.emptyHint(
                        "No acts added yet. Tap + to add applicable acts.",
                      )
                      : Column(
                        children:
                            acts
                                .map(
                                  (act) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF6366F1,
                                        ).withValues(alpha: 0.1),
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
                                                act.actName,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              if (act.sectionNumber != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                  child: Text(
                                                    "SECTION ${act.sectionNumber}",
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Color(0xFF6366F1),
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap:
                                              () => _deleteItem(
                                                context,
                                                ref,
                                                act.id,
                                              ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.05,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
          loading:
              () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          error: (e, _) => DossierHelper.emptyHint("Error loading acts"),
        ),
      ],
    );
  }
}
