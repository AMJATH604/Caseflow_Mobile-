import 'package:flutter/material.dart';
import '../../models/models.dart';
import 'dossier_shared.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PartyIntelligenceSection extends StatelessWidget {
  final CaseModel caseData;

  const PartyIntelligenceSection({super.key, required this.caseData});

  @override
  Widget build(BuildContext context) {
    final isCriminal = (caseData.caseType ?? '').toLowerCase().contains(
      'criminal',
    );
    final partyALabel = isCriminal ? 'PETITIONER' : 'PLAINTIFF';
    final partyBLabel = isCriminal ? 'ACCUSED' : 'DEFENDANT';
    final isRepPet =
        caseData.representationType == RepresentationType.petitioner;

    return DossierSection(
      icon: Icons.architecture_rounded,
      title: 'Party Intelligence',
      color: const Color(0xFF2563EB),
      initiallyExpanded: true,
      children: [
        // Party A
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partyALabel,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      isRepPet
                          ? (caseData.clientName ?? 'Unknown')
                          : (caseData.opposingParty ?? 'Not Set'),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (caseData.petitionerAdvocate?.isNotEmpty == true)
                      Text(
                        'Adv. ${caseData.petitionerAdvocate}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  isRepPet ? 'YOUR CLIENT' : 'OPPOSING',
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2563EB),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        // Party B
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Icon(
                  Icons.person_off_rounded,
                  size: 16,
                  color: Color(0xFFDC2626),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partyBLabel,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      isRepPet
                          ? (caseData.opposingParty ?? 'Not Set')
                          : (caseData.clientName ?? 'Unknown'),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (caseData.opposingAdvocate?.isNotEmpty == true)
                      Text(
                        'Adv. ${caseData.opposingAdvocate}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  !isRepPet ? 'YOUR CLIENT' : 'OPPOSING',
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFDC2626),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
