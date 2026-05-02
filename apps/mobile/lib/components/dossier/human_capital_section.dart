import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';

import '../../services/collaborator_service.dart';
import '../../services/firm_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'dossier_shared.dart';

class HumanCapitalSection extends ConsumerStatefulWidget {
  final String caseId;
  final CaseModel caseData;

  const HumanCapitalSection({
    super.key,
    required this.caseId,
    required this.caseData,
  });

  @override
  ConsumerState<HumanCapitalSection> createState() => _HumanCapitalSectionState();
}

class _HumanCapitalSectionState extends ConsumerState<HumanCapitalSection> {
  void _showShareDialog() {
    String email = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Share with Colleague"),
        content: TextField(
          decoration: const InputDecoration(labelText: "Colleague Email"),
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => email = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (email.isEmpty) return;
              Navigator.pop(context);
              try {
                await CollaboratorService.inviteCollaborator(widget.caseId, email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invitation sent!")));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Send Invite"),
          ),
        ],
      ),
    );
  }

  void _showReassignDialog(CaseModel caseData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Transfer Ownership"),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<FirmMember>>(
            future: FirmService.fetchFirmMembers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("No firm members found to transfer to.");
              
              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final member = snapshot.data![index];
                  return ListTile(
                    title: Text(member.memberName ?? member.memberEmail),
                    subtitle: Text(member.memberEmail),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await FirmService.assignCase(widget.caseId, member.memberId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case reassigned!")));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCollaboratorsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: CollaboratorService.fetchCaseCollaborators(widget.caseId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
        final profile = ref.watch(userProfileProvider).value;
        final isOwner = profile != null && (profile.id == widget.caseData.createdBy);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("COLLABORATORS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1)),
            const SizedBox(height: 8),
            ...snapshot.data!.map((c) {
              final collaboratorName = c['profiles']?['full_name'] ?? c['collaborator_email'];
              final ownerName = c['owner']?['full_name'] ?? 'Unknown';
              final createdAt = c['created_at'] != null
                  ? DateTime.tryParse(c['created_at'])
                  : null;
              final dateStr = createdAt != null
                  ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                  : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(collaboratorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                          Text(
                            "Shared by $ownerName${dateStr.isNotEmpty ? ' · $dateStr' : ''}",
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (c['status'] == 'accepted' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (c['status'] ?? 'pending').toString().toUpperCase(),
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: c['status'] == 'accepted' ? Colors.green : Colors.orange),
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Revoke Access?"),
                              content: Text("Remove $collaboratorName from this case?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("Revoke", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await CollaboratorService.deleteCollaboration(c['id']);
                            if (mounted) {
                              setState(() {}); // Rebuild to refresh list
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Access revoked")),
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 16, color: Colors.red.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final caseData = widget.caseData;

    return DossierSection(
      icon: Icons.hub_rounded,
      title: "Human Capital Assignment",
      color: const Color(0xFF64748B),
      children: [
        DossierHelper.dossierRow("SUPERVISING LAWYER", caseData.createdBy == caseData.firmId ? "SENIOR PARTNER" : "FIRM ARCHITECT"),
        DossierHelper.dossierRow("ACTIVE ADVOCATE", caseData.assignedTo == null ? "CASE OWNER (YOU)" : "FIRM ASSOCIATE"),
        if ((profile?.isFirmOwner ?? false) && (profile?.id == caseData.firmId || profile?.id == caseData.createdBy)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showReassignDialog(caseData),
              icon: const Icon(Icons.sync_alt_rounded, size: 16),
              label: const Text("TRANSFER OWNERSHIP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
                foregroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showShareDialog(),
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text("SHARE WITH COLLEAGUE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accent,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildCollaboratorsList(),
      ],
    );
  }
}
