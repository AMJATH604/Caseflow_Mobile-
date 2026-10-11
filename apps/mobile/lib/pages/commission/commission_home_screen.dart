import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/commission/cm_kit.dart';
import '../../models/commission_models.dart';
import '../../services/commission_service.dart';
import '../../theme/app_theme.dart';
import '../commission_detail_screen.dart';
import '../commission_report_screen.dart';
import '../commissions_screen.dart' show commissionsProvider;
import 'commission_data.dart';
import 'commission_fees_screen.dart';
import 'commission_form.dart';
import 'commission_measure_screen.dart';
import 'commission_notice_screen.dart';
import 'commission_site_screen.dart';

/// A commission at a glance: where it stands, the one thing to do next, and
/// every part of it one tap away.
class CommissionHomeScreen extends ConsumerWidget {
  final String commissionId;
  const CommissionHomeScreen({super.key, required this.commissionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commissionBundleProvider(commissionId));
    return async.when(
      loading: () => Scaffold(backgroundColor: Cm.bg(context), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => CmScaffold(
        title: 'Commission',
        body: CmEmpty(
          icon: Icons.cloud_off_rounded,
          title: 'Could not open this commission',
          body: 'Check your connection and try again.\n$e',
          action: SizedBox(
            width: 160.w,
            child: CmButton('Try again', onPressed: () => ref.invalidate(commissionBundleProvider(commissionId))),
          ),
        ),
      ),
      data: (b) => _Home(bundle: b),
    );
  }
}

class _Home extends ConsumerStatefulWidget {
  final CommissionBundle bundle;
  const _Home({required this.bundle});
  @override
  ConsumerState<_Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<_Home> {
  bool _starting = false;

  CommissionBundle get b => widget.bundle;
  Commission get c => b.commission;

  void _refresh() {
    ref.invalidate(commissionBundleProvider(c.id));
    ref.invalidate(commissionsProvider);
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
  }

  Future<void> _visit() async {
    final active = b.activeVisit;
    if (active != null) return _push(CommissionSiteScreen(commissionId: c.id, visitId: active.id));
    setState(() => _starting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final v = await CommissionService.checkIn(c.id);
      messenger.showSnackBar(SnackBar(
        content: Text(v.checkinLat != null
            ? 'Checked in · ${v.checkinLat!.toStringAsFixed(5)}, ${v.checkinLng!.toStringAsFixed(5)}'
            : 'Checked in · GPS unavailable. Turn on location so the visit is placed on the map.'),
      ));
      if (mounted) await _push(CommissionSiteScreen(commissionId: c.id, visitId: v.id));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not check in: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _act(String action) async {
    switch (action) {
      case 'notice':
        return _push(CommissionNoticeScreen(commissionId: c.id));
      case 'visit':
        return _visit();
      case 'measure':
        return _push(CommissionMeasureScreen(commissionId: c.id));
      case 'record':
        return _push(CommissionDetailScreen(commissionId: c.id));
      case 'report':
        await CommissionService.updateCommission(c.id, {'status': CommissionStatus.reportDrafting.dbValue});
        return _push(CommissionReportScreen(commissionId: c.id));
      case 'fees':
        return _push(CommissionFeesScreen(commissionId: c.id));
      case 'submit':
        return _submit();
    }
  }

  Future<void> _submit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark the report as filed?'),
        content: const Text('Do this once the report has been filed in court. You can still add to the record if objections come.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report filed')),
        ],
      ),
    );
    if (ok != true) return;
    await CommissionService.updateCommission(c.id, {
      'status': CommissionStatus.submitted.dbValue,
      'submitted_on': DateTime.now().toIso8601String().split('T').first,
    });
    _refresh();
  }

  Future<void> _menu(String v) async {
    if (v == 'edit') {
      final saved = await showCommissionForm(context, ref, existing: c);
      if (saved != null) _refresh();
    } else if (v == 'status') {
      final s = await showModalBottomSheet<CommissionStatus>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: EdgeInsets.all(16.r), child: Text('Change status', style: Cm.display(ctx, size: 18))),
              for (final s in CommissionStatus.values)
                ListTile(
                  leading: Icon(s == c.status ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: s == c.status ? Cm.violet : Cm.faint),
                  title: Text(s.label),
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      );
      if (s != null && s != c.status) {
        await CommissionService.updateCommission(c.id, {'status': s.dbValue});
        _refresh();
      }
    } else if (v == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this commission?'),
          content: const Text('Visits, photos, notes, witnesses, sketches, parties, measurements and expenses are deleted with it. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await CommissionService.deleteCommission(c.id);
        ref.invalidate(commissionsProvider);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = b.progress;
    final site = c.commissionType.isSiteWork;
    final served = b.parties.where((x) => x.noticeStatus.noticeGiven).length;
    final active = b.activeVisit;

    return CmScaffold(
      title: c.displayRef,
      actions: [
        IconButton(tooltip: 'Edit details', icon: const Icon(Icons.edit_outlined), onPressed: () => _menu('edit')),
        PopupMenuButton<String>(
          onSelected: _menu,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'status', child: Text('Change status')),
            PopupMenuItem(value: 'delete', child: Text('Delete commission', style: TextStyle(color: AppTheme.error))),
          ],
        ),
      ],
      bottom: p.nextAction == 'none'
          ? null
          : CmButton(
              active != null ? 'Continue site visit' : (site ? 'Start site visit' : 'Start sitting'),
              icon: Icons.location_on_rounded,
              color: const Color(0xFF16A34A),
              busy: _starting,
              onPressed: _visit,
            ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
          children: [
            _Hero(c: c, progress: p),
            SizedBox(height: 12.h),
            if (p.nextAction != 'none') ...[
              CmCard(
                color: Cm.dark(context) ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                borderColor: Cm.dark(context) ? const Color(0xFF312E81) : const Color(0xFFC7D2FE),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CmLabel('Next step', color: Cm.dark(context) ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA)),
                    SizedBox(height: 6.h),
                    Text(p.nextTitle, style: Cm.title(context, size: 16)),
                    SizedBox(height: 4.h),
                    Text(p.nextDetail, style: Cm.body(context)),
                    SizedBox(height: 12.h),
                    CmButton(_nextLabel(p.nextAction), icon: _nextIcon(p.nextAction), onPressed: () => _act(p.nextAction)),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
            ],
            CmCard(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              child: Column(
                children: [
                  CmNavRow(
                    icon: Icons.campaign_rounded,
                    color: const Color(0xFF0284C7),
                    title: 'Notice to parties',
                    subtitle: b.parties.isEmpty
                        ? 'No parties yet'
                        : '$served of ${b.parties.length} given notice${c.inspectionAt != null ? ' · ${cmDateTime(c.inspectionAt)}' : ''}',
                    onTap: () => _act('notice'),
                  ),
                  _div(context),
                  CmNavRow(
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFF16A34A),
                    title: 'The record',
                    subtitle: '${b.visits.length} ${b.visits.length == 1 ? 'visit' : 'visits'} · ${b.evidence.length} photos · '
                        '${b.witnesses.length} ${b.witnesses.length == 1 ? 'witness' : 'witnesses'} · ${b.observations.length} notes',
                    onTap: () => _act('record'),
                  ),
                  if (site) ...[
                    _div(context),
                    CmNavRow(
                      icon: Icons.square_foot_rounded,
                      color: const Color(0xFF0F766E),
                      title: 'Boundaries & extent',
                      subtitle: b.measurements.isEmpty
                          ? 'Nothing measured yet'
                          : '${b.measurements.where((m) => m.isComplete).length} of ${b.measurements.length} complete',
                      onTap: () => _act('measure'),
                    ),
                  ],
                  _div(context),
                  CmNavRow(
                    icon: Icons.currency_rupee_rounded,
                    color: const Color(0xFFB45309),
                    title: 'Fee & expenses',
                    subtitle: '${c.feeFixed != null ? '${cmRupees(c.feeFixed)} fixed · ${cmRupees(c.feeReceived ?? 0)} received · ' : 'Fee not entered · '}'
                        '${cmRupees(b.expenseTotal)} spent',
                    onTap: () => _act('fees'),
                  ),
                  _div(context),
                  CmNavRow(
                    icon: Icons.description_rounded,
                    color: const Color(0xFF6D28D9),
                    title: 'Report',
                    subtitle: c.submittedOn != null ? 'Filed on ${cmDate(c.submittedOn)}' : 'Build, preview and share the PDF',
                    onTap: () => _push(CommissionReportScreen(commissionId: c.id)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            CmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CmLabel('Warrant'),
                  SizedBox(height: 8.h),
                  CmFacts([
                    ('Issued under', '${c.commissionType.rule} CPC'),
                    ('Warrant dated', cmDate(c.warrantDate)),
                    ('Return date', cmDate(c.deadlineDate)),
                    if (c.surveyNumber != null) ('Survey No.', c.surveyNumber!),
                    if (c.village != null || c.taluk != null || c.district != null) ('Location', c.locationSummary),
                  ]),
                  if ((c.scopeOfWork ?? '').trim().isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    Text('What the court asked for', style: Cm.title(context, size: 13)),
                    SizedBox(height: 4.h),
                    Text(c.scopeOfWork!, style: Cm.body(context)),
                  ],
                  if (c.caseId != null) ...[
                    SizedBox(height: 6.h),
                    CmNavRow(
                      icon: Icons.folder_open_rounded,
                      color: AppTheme.accent,
                      title: 'Open the case',
                      subtitle: c.caseTitle ?? 'Linked case',
                      onTap: () => context.push('/cases/${c.caseId}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _div(BuildContext context) => Divider(height: 1, color: Cm.border(context), indent: 54.w);

  String _nextLabel(String a) => switch (a) {
        'notice' => 'Open notice to parties',
        'visit' => b.activeVisit != null ? 'Continue the visit' : 'Start the visit',
        'measure' => 'Open boundaries',
        'record' => 'Open the record',
        'report' => 'Prepare the report',
        'submit' => 'Mark report as filed',
        'fees' => 'Open fee & expenses',
        _ => 'Open',
      };

  IconData _nextIcon(String a) => switch (a) {
        'notice' => Icons.campaign_rounded,
        'visit' => Icons.location_on_rounded,
        'measure' => Icons.square_foot_rounded,
        'report' => Icons.description_rounded,
        'submit' => Icons.task_alt_rounded,
        _ => Icons.arrow_forward_rounded,
      };
}

class _Hero extends StatelessWidget {
  final Commission c;
  final CommissionProgress progress;
  const _Hero({required this.c, required this.progress});

  @override
  Widget build(BuildContext context) {
    final days = c.daysRemaining;
    final (dueText, dueTone) = c.status == CommissionStatus.submitted || c.status == CommissionStatus.closed
        ? ('Filed', CmTone.green)
        : days == null
            ? ('No return date', CmTone.gray)
            : days < 0
                ? ('Overdue ${-days} ${-days == 1 ? 'day' : 'days'}', CmTone.red)
                : days <= 7
                    ? ('Due in $days ${days == 1 ? 'day' : 'days'}', CmTone.amber)
                    : ('Due ${cmDate(c.deadlineDate)}', CmTone.blue);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        gradient: const LinearGradient(
          colors: [Cm.violetDeep, Cm.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cmTypeIcon(c.commissionType), size: 14.r, color: Colors.white),
                    SizedBox(width: 5.w),
                    Text(c.commissionType.label, style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
              const Spacer(),
              CmPill(dueText, tone: dueTone),
            ],
          ),
          SizedBox(height: 12.h),
          Text(c.partiesTitle ?? c.displayRef, style: Cm.display(context, size: 19, color: Colors.white)),
          SizedBox(height: 3.h),
          Text(
            [c.courtName, if (c.warrantDate != null) 'Warrant ${cmDate(c.warrantDate)}'].whereType<String>().join(' · '),
            style: GoogleFonts.inter(fontSize: 12.5.sp, color: Colors.white.withValues(alpha: 0.85)),
          ),
          SizedBox(height: 14.h),
          CmStageBar(done: progress.doneCount, onDark: true),
          SizedBox(height: 8.h),
          Text(
            [
              for (final s in CommissionStage.values)
                s.index < progress.doneCount ? '${s.label} ✓' : (s == progress.current ? s.label.toUpperCase() : s.label),
            ].join('  ·  '),
            style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}
