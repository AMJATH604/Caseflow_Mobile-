import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/commission/cm_kit.dart';
import '../../models/commission_models.dart';
import '../../models/models.dart';
import '../../services/commission_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';

/// Create a commission, or edit one ([existing]). Returns the commission's
/// id once saved, or null if the sheet was closed.
Future<String?> showCommissionForm(BuildContext context, WidgetRef ref, {Commission? existing}) {
  final e = existing;
  var type = e?.commissionType ?? CommissionType.localInvestigation;
  final caseNum = TextEditingController(text: e?.caseNumberRef ?? '');
  final court = TextEditingController(text: e?.courtName ?? '');
  final pet = TextEditingController(text: e?.partyPetitioner ?? '');
  final resp = TextEditingController(text: e?.partyRespondent ?? '');
  final scope = TextEditingController(text: e?.scopeOfWork ?? '');
  final prop = TextEditingController(text: e?.propertyDescription ?? '');
  final survey = TextEditingController(text: e?.surveyNumber ?? '');
  final village = TextEditingController(text: e?.village ?? '');
  final taluk = TextEditingController(text: e?.taluk ?? '');
  final district = TextEditingController(text: e?.district ?? '');
  DateTime? warrant = e?.warrantDate;
  DateTime? deadline = e?.deadlineDate;
  String? caseId = e?.caseId;
  String? caseTitle = e?.caseTitle;
  bool busy = false;
  String? error;

  String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  String? d(DateTime? x) => x?.toIso8601String().split('T').first;

  return showCmSheet<String>(
    context,
    title: e == null ? 'New commission' : 'Commission details',
    builder: (ctx, ss) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CmLabel('Kind of commission'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in CommissionType.values)
              ChoiceChip(
                avatar: Icon(cmTypeIcon(t), size: 16),
                label: Text(t.label),
                selected: type == t,
                onSelected: (_) => ss(() => type = t),
                selectedColor: Cm.violet.withValues(alpha: 0.16),
              ),
          ],
        ),
        SizedBox(height: 6.h),
        Text('Issued under ${type.rule} CPC', style: Cm.body(ctx, size: 12)),
        SizedBox(height: 18.h),
        const CmLabel('The suit'),
        SizedBox(height: 8.h),
        CmField(caseNum, 'Case number', hint: 'O.S. 105/2020'),
        SizedBox(height: 10.h),
        CmField(court, 'Court', hint: 'District Munsif Court, Tenkasi'),
        SizedBox(height: 10.h),
        CmField(pet, 'Plaintiff / petitioner'),
        SizedBox(height: 10.h),
        CmField(resp, 'Defendant / respondent'),
        SizedBox(height: 10.h),
        _CaseLink(
          title: caseTitle,
          onPick: (c) => ss(() {
            caseId = c?.id;
            caseTitle = c?.caseTitle;
            if (c != null && caseNum.text.trim().isEmpty) caseNum.text = c.caseNumber ?? '';
            if (c != null && court.text.trim().isEmpty) court.text = c.courtName ?? '';
          }),
        ),
        SizedBox(height: 18.h),
        const CmLabel('Warrant'),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(child: CmDateField(label: 'Warrant dated', value: warrant, onPicked: (x) => ss(() => warrant = x))),
            SizedBox(width: 10.w),
            Expanded(child: CmDateField(label: 'Return date', value: deadline, onPicked: (x) => ss(() => deadline = x))),
          ],
        ),
        SizedBox(height: 10.h),
        CmField(scope, 'What the court asked for', hint: 'Points to be noted, as in the warrant', maxLines: 3),
        SizedBox(height: 18.h),
        const CmLabel('Property'),
        SizedBox(height: 8.h),
        CmField(prop, 'Description', maxLines: 2),
        SizedBox(height: 10.h),
        CmField(survey, 'Survey number'),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(child: CmField(village, 'Village')),
            SizedBox(width: 10.w),
            Expanded(child: CmField(taluk, 'Taluk')),
          ],
        ),
        SizedBox(height: 10.h),
        CmField(district, 'District'),
        if (error != null) ...[
          SizedBox(height: 12.h),
          Text(error!, style: Cm.body(ctx, color: AppTheme.error)),
        ],
        SizedBox(height: 18.h),
        CmButton(
          e == null ? 'Create commission' : 'Save details',
          icon: Icons.check_rounded,
          busy: busy,
          onPressed: () async {
            ss(() {
              busy = true;
              error = null;
            });
            final data = {
              'commission_type': type.dbValue,
              'case_id': caseId,
              'case_number_ref': v(caseNum),
              'court_name': v(court),
              'party_petitioner': v(pet),
              'party_respondent': v(resp),
              'warrant_date': d(warrant),
              'deadline_date': d(deadline),
              'scope_of_work': v(scope),
              'property_description': v(prop),
              'survey_number': v(survey),
              'village': v(village),
              'taluk': v(taluk),
              'district': v(district),
            };
            try {
              String id;
              if (e == null) {
                id = (await CommissionService.createCommission(data)).id;
              } else {
                await CommissionService.updateCommission(e.id, data);
                id = e.id;
              }
              if (ctx.mounted) Navigator.pop(ctx, id);
            } catch (err) {
              ss(() {
                busy = false;
                error = 'Could not save: $err';
              });
            }
          },
        ),
      ],
    ),
  );
}

/// "Linked case" row: opens a searchable list of the user's cases.
class _CaseLink extends ConsumerWidget {
  final String? title;
  final ValueChanged<CaseModel?> onPick;
  const _CaseLink({required this.title, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CmCard(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: CmNavRow(
        icon: Icons.folder_open_rounded,
        color: AppTheme.accent,
        title: title == null ? 'Link to a case in CaseFlow' : 'Linked case',
        subtitle: title ?? 'Optional — opens the case from the commission',
        trailing: title == null
            ? null
            : IconButton(
                tooltip: 'Unlink',
                icon: const Icon(Icons.link_off_rounded, size: 20),
                onPressed: () => onPick(null),
              ),
        onTap: () async {
          final picked = await showModalBottomSheet<CaseModel>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _CasePicker(),
          );
          if (picked != null) onPick(picked);
        },
      ),
    );
  }
}

class _CasePicker extends ConsumerStatefulWidget {
  const _CasePicker();
  @override
  ConsumerState<_CasePicker> createState() => _CasePickerState();
}

class _CasePickerState extends ConsumerState<_CasePicker> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final cases = ref.watch(casesProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
          child: Column(
            children: [
              TextField(
                autofocus: true,
                onChanged: (x) => setState(() => q = x.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search case title or number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  isDense: true,
                ),
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: cases.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Could not load cases: $e')),
                  data: (list) {
                    final rows = list
                        .where((c) =>
                            q.isEmpty ||
                            c.caseTitle.toLowerCase().contains(q) ||
                            (c.caseNumber ?? '').toLowerCase().contains(q))
                        .toList();
                    if (rows.isEmpty) return Center(child: Text('No matching cases', style: Cm.body(context)));
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Cm.border(context)),
                      itemBuilder: (_, i) => ListTile(
                        title: Text(rows[i].caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text([rows[i].caseNumber, rows[i].courtName].whereType<String>().join(' · ')),
                        onTap: () => Navigator.pop(context, rows[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
