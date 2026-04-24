import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../models/case_dossier_models.dart';
import 'dossier_shared.dart';

class PartyIntelligenceSection extends StatelessWidget {
  final CaseModel caseData;

  const PartyIntelligenceSection({super.key, required this.caseData});

  @override
  Widget build(BuildContext context) {
    final isCriminal = (caseData.caseType ?? '').toLowerCase().contains('criminal');
    final partyALabel = isCriminal ? 'PETITIONER' : 'PLAINTIFF';
    final partyBLabel = isCriminal ? 'ACCUSED' : 'DEFENDANT';
    final isRepPet = caseData.representationType == RepresentationType.petitioner;

    return DossierSection(
      icon: Icons.architecture_rounded,
      title: "Party Intelligence",
      color: const Color(0xFF2563EB),
      initiallyExpanded: true,
      children: [
        // Party A
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partyALabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(
                      isRepPet ? (caseData.clientName ?? 'Unknown') : (caseData.opposingParty ?? 'Not Set'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    if (caseData.petitionerAdvocate?.isNotEmpty == true)
                      Text("Adv. ${caseData.petitionerAdvocate}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isRepPet ? "YOUR CLIENT" : "OPPOSING",
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF2563EB), letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Party B
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_off_rounded, size: 16, color: Color(0xFFDC2626)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partyBLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(
                      isRepPet ? (caseData.opposingParty ?? 'Not Set') : (caseData.clientName ?? 'Unknown'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    if (caseData.opposingAdvocate?.isNotEmpty == true)
                      Text("Adv. ${caseData.opposingAdvocate}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  !isRepPet ? "YOUR CLIENT" : "OPPOSING",
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFDC2626), letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
