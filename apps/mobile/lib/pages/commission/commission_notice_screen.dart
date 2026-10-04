import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../components/commission/cm_kit.dart';
import '../../models/commission_models.dart';
import '../../services/commission_service.dart';
import '../../services/repositories/profile_repository.dart';
import '../../theme/app_theme.dart';
import 'commission_data.dart';

/// Notice of the inspection to every party: who was served, how and when,
/// and the notice itself as a PDF to print or share.
class CommissionNoticeScreen extends ConsumerWidget {
  final String commissionId;
  const CommissionNoticeScreen({super.key, required this.commissionId});

  void _refresh(WidgetRef ref) => ref.invalidate(commissionBundleProvider(commissionId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commissionBundleProvider(commissionId));
    final b = async.valueOrNull;
    return CmScaffold(
      title: 'Notice to parties',
      bottom: b == null
          ? null
          : Row(
              children: [
                Expanded(
                  child: CmButton('Preview', icon: Icons.visibility_outlined, outlined: true,
                      onPressed: () => _notice(context, b, share: false)),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: CmButton('Share notice', icon: Icons.ios_share_rounded,
                      onPressed: () => _notice(context, b, share: true)),
                ),
              ],
            ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (b) => RefreshIndicator(
          onRefresh: () async => _refresh(ref),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
            children: [
              CmCard(
                onTap: () => _editInspection(context, ref, b.commission),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: CmLabel('Inspection fixed for')),
                        Icon(Icons.edit_outlined, size: 18.r, color: Cm.faint),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(9.r),
                          decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10.r)),
                          child: Icon(Icons.event_rounded, color: const Color(0xFF1D4ED8), size: 20.r),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.commission.inspectionAt == null ? 'Tap to fix the date and time' : cmDateTime(b.commission.inspectionAt),
                                  style: Cm.title(context)),
                              Text(b.commission.inspectionPlace ?? 'Place not set', style: Cm.body(context)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              if (b.parties.isEmpty)
                CmCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Who must be given notice?', style: Cm.title(context)),
                      SizedBox(height: 4.h),
                      Text('Add every party and their advocate, and anyone who should assist — a surveyor or revenue official.',
                          style: Cm.body(context)),
                      if (b.commission.partyPetitioner != null || b.commission.partyRespondent != null) ...[
                        SizedBox(height: 12.h),
                        CmButton('Add the parties from the warrant', icon: Icons.group_add_rounded, onPressed: () async {
                          final c = b.commission;
                          if (c.partyPetitioner != null) {
                            await CommissionService.saveParty(c.id, {'name': c.partyPetitioner, 'role': 'plaintiff', 'sort_order': 0});
                          }
                          if (c.partyRespondent != null) {
                            await CommissionService.saveParty(c.id, {'name': c.partyRespondent, 'role': 'defendant', 'sort_order': 1});
                          }
                          _refresh(ref);
                        }),
                      ],
                    ],
                  ),
                )
              else
                CmCard(
                  padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: EdgeInsets.only(left: 2.w, bottom: 4.h), child: const CmLabel('Parties and others')),
                      for (final p in b.parties) ...[
                        _PartyRow(p: p, onTap: () => _editParty(context, ref, b, p)),
                        if (p != b.parties.last) Divider(height: 1, color: Cm.border(context)),
                      ],
                    ],
                  ),
                ),
              SizedBox(height: 10.h),
              CmButton('Add a party', icon: Icons.person_add_alt_1_rounded, outlined: true, onPressed: () => _editParty(context, ref, b, null)),
              SizedBox(height: 14.h),
              Text(
                'Parties who were given notice but do not attend can be proceeded against in their absence (O. XXVI r. 18 CPC). '
                'Their absence and the notice given are recorded in the report.',
                style: Cm.body(context, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editInspection(BuildContext context, WidgetRef ref, Commission c) async {
    DateTime? at = c.inspectionAt?.toLocal();
    final place = TextEditingController(text: c.inspectionPlace ?? '');
    final saved = await showCmSheet<bool>(
      context,
      title: 'Date and place',
      builder: (ctx, ss) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CmDateField(label: 'Date and time of inspection', value: at, withTime: true, onPicked: (d) => ss(() => at = d)),
          SizedBox(height: 10.h),
          CmField(place, 'Place', hint: 'At the suit property, Idaikal village', maxLines: 2),
          SizedBox(height: 16.h),
          CmButton('Save', icon: Icons.check_rounded, onPressed: () async {
            await CommissionService.updateCommission(c.id, {
              'inspection_at': at?.toUtc().toIso8601String(),
              'inspection_place': place.text.trim().isEmpty ? null : place.text.trim(),
            });
            if (ctx.mounted) Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (saved == true) _refresh(ref);
  }

  Future<void> _editParty(BuildContext context, WidgetRef ref, CommissionBundle b, CommissionParty? p) async {
    final name = TextEditingController(text: p?.name ?? '');
    final label = TextEditingController(text: p?.roleLabel ?? '');
    final adv = TextEditingController(text: p?.advocate ?? '');
    final phone = TextEditingController(text: p?.phone ?? '');
    final how = TextEditingController(text: p?.servedHow ?? '');
    var role = p?.role ?? 'party';
    var status = p?.noticeStatus ?? NoticeStatus.pending;
    DateTime? on = p?.servedOn;
    String? err;
    const roles = {
      'plaintiff': 'Plaintiff',
      'petitioner': 'Petitioner',
      'defendant': 'Defendant',
      'respondent': 'Respondent',
      'official': 'Official',
      'other': 'Other',
    };
    final saved = await showCmSheet<bool>(
      context,
      title: p == null ? 'Add a party' : p.name,
      builder: (ctx, ss) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CmField(name, 'Name', icon: Icons.person_outline_rounded),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in roles.entries)
                ChoiceChip(label: Text(e.value), selected: role == e.key, onSelected: (_) => ss(() => role = e.key)),
            ],
          ),
          SizedBox(height: 10.h),
          CmField(label, 'Shown as (optional)', hint: '1st Defendant, Revenue Inspector'),
          SizedBox(height: 10.h),
          CmField(adv, 'Advocate', hint: 'Adv. R. Kannan, or party-in-person'),
          SizedBox(height: 10.h),
          CmField(phone, 'Phone (optional)', keyboard: TextInputType.phone),
          SizedBox(height: 16.h),
          const CmLabel('Notice'),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in NoticeStatus.values)
                ChoiceChip(label: Text(s.label), selected: status == s, onSelected: (_) => ss(() => status = s)),
            ],
          ),
          SizedBox(height: 10.h),
          CmDateField(label: 'On', value: on, onPicked: (d) => ss(() => on = d)),
          SizedBox(height: 10.h),
          CmField(how, 'How', hint: 'By hand, signed copy · WhatsApp, acknowledged · Refused at door'),
          if (err != null) ...[SizedBox(height: 10.h), Text(err!, style: Cm.body(ctx, color: AppTheme.error))],
          SizedBox(height: 16.h),
          CmButton('Save', icon: Icons.check_rounded, onPressed: () async {
            if (name.text.trim().isEmpty) return ss(() => err = 'Enter the name');
            String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
            try {
              await CommissionService.saveParty(
                b.commission.id,
                {
                  'name': name.text.trim(),
                  'role': role,
                  'role_label': t(label),
                  'advocate': t(adv),
                  'phone': t(phone),
                  'notice_status': status.dbValue,
                  'served_on': on?.toIso8601String().split('T').first,
                  'served_how': t(how),
                  if (p == null) 'sort_order': b.parties.length,
                },
                id: p?.id,
              );
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              ss(() => err = 'Could not save: $e');
            }
          }),
          if (p != null) ...[
            SizedBox(height: 8.h),
            TextButton.icon(
              onPressed: () async {
                await CommissionService.deleteParty(p.id);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              label: const Text('Remove this party', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        ],
      ),
    );
    if (saved == true) _refresh(ref);
  }

  Future<void> _notice(BuildContext context, CommissionBundle b, {required bool share}) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = b.commission;
    if (c.inspectionAt == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Fix the date and time of inspection first.')));
      return;
    }
    final me = await ProfileRepository.getProfile();
    final name = (me.fullName?.trim().isNotEmpty ?? false) ? me.fullName!.trim() : 'Advocate Commissioner';
    final enrol = me.registrationNumber?.trim();
    final bytes = await buildNoticePdf(c, b.parties, name, enrol);
    final file = 'Notice_${(c.caseNumberRef ?? 'commission').replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf';
    if (share) {
      await Printing.sharePdf(bytes: bytes, filename: file);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: file);
    }
  }
}

class _PartyRow extends StatelessWidget {
  final CommissionParty p;
  final VoidCallback onTap;
  const _PartyRow({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = switch (p.noticeStatus) {
      NoticeStatus.served => CmTone.green,
      NoticeStatus.informed => CmTone.blue,
      NoticeStatus.refused => CmTone.amber,
      NoticeStatus.notServed => CmTone.red,
      NoticeStatus.pending => CmTone.gray,
    };
    final detail = [
      if (p.servedHow != null) p.servedHow!,
      if (p.servedOn != null) cmDate(p.servedOn),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 2.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: Cm.violet.withValues(alpha: 0.12),
              child: Text(p.name.characters.first.toUpperCase(), style: Cm.title(context, size: 14).copyWith(color: Cm.violet)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(p.name, style: Cm.title(context, size: 14))),
                      CmPill(p.noticeStatus.label, tone: tone),
                    ],
                  ),
                  Text('${p.roleText}${p.advocate != null ? ' · ${p.advocate}' : ''}', style: Cm.body(context, size: 12)),
                  if (detail.isNotEmpty) Text(detail, style: Cm.body(context, size: 12, color: Cm.faint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The notice of inspection as a one-page A4 PDF.
Future<Uint8List> buildNoticePdf(Commission c, List<CommissionParty> parties, String commissioner, String? enrolment) async {
  final doc = pw.Document();
  final at = c.inspectionAt!.toLocal();
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final time = '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'AM' : 'PM'}';
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final date = '${at.day} ${months[at.month - 1]} ${at.year}';
  final today = DateTime.now();
  final todayText = '${today.day} ${months[today.month - 1]} ${today.year}';
  final body = pw.TextStyle(fontSize: 11.5, lineSpacing: 3);
  final bold = pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Text('IN THE COURT OF ${(c.courtName ?? '').toUpperCase()}', style: bold)),
          pw.SizedBox(height: 4),
          if (c.caseNumberRef != null) pw.Center(child: pw.Text(c.caseNumberRef!, style: body)),
          pw.SizedBox(height: 14),
          if (c.partyPetitioner != null)
            pw.Row(children: [pw.Expanded(child: pw.Text(c.partyPetitioner!, style: bold)), pw.Text('... Plaintiff / Petitioner', style: body)]),
          pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text('Vs.', style: body))),
          if (c.partyRespondent != null)
            pw.Row(children: [pw.Expanded(child: pw.Text(c.partyRespondent!, style: bold)), pw.Text('... Defendant / Respondent', style: body)]),
          pw.SizedBox(height: 22),
          pw.Center(child: pw.Text('NOTICE OF INSPECTION', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1))),
          pw.SizedBox(height: 16),
          pw.Text(
            'Take notice that I, the undersigned, appointed as Advocate Commissioner by the Court in the above matter'
            '${c.warrantDate != null ? ' by warrant dated ${c.warrantDate!.day} ${months[c.warrantDate!.month - 1]} ${c.warrantDate!.year}' : ''}'
            ' for ${c.commissionType.label.toLowerCase()}, will execute the commission on $date at $time'
            '${c.inspectionPlace != null ? ' at ${c.inspectionPlace}' : ''}.',
            style: body,
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'You are requested to be present, in person or through your counsel, with any documents you wish to rely on. '
            'If you do not attend, the commission will be executed in your absence.',
            style: body,
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Date: $todayText', style: body),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.SizedBox(height: 30),
                  pw.Text(commissioner, style: bold),
                  pw.Text('Advocate Commissioner', style: body),
                  if (enrolment != null && enrolment.isNotEmpty) pw.Text('Enrolment No. $enrolment', style: body),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 26),
          if (parties.isNotEmpty) ...[
            pw.Text('To', style: bold),
            pw.SizedBox(height: 4),
            for (var i = 0; i < parties.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  '${i + 1}. ${parties[i].name}, ${parties[i].roleText}${parties[i].advocate != null ? ' — through ${parties[i].advocate}' : ''}',
                  style: body,
                ),
              ),
          ],
        ],
      ),
    ),
  );
  return doc.save();
}
