import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../components/commission/cm_kit.dart';
import '../models/commission_models.dart';
import '../services/commission_service.dart';
import '../services/providers.dart';
import 'commission/commission_form.dart';

final commissionsProvider = FutureProvider<List<Commission>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return CommissionService.fetchCommissions();
});

/// Every commission, by what needs attention: active, overdue, done.
class CommissionsScreen extends ConsumerStatefulWidget {
  const CommissionsScreen({super.key});
  @override
  ConsumerState<CommissionsScreen> createState() => _CommissionsScreenState();
}

enum _Tab { active, overdue, done }

class _CommissionsScreenState extends ConsumerState<CommissionsScreen> {
  _Tab _tab = _Tab.active;
  String _q = '';
  bool _searching = false;

  bool _done(Commission c) =>
      c.status == CommissionStatus.submitted || c.status == CommissionStatus.closed;

  List<Commission> _rows(List<Commission> all) {
    final q = _q.trim().toLowerCase();
    return all.where((c) {
      final inTab = switch (_tab) {
        _Tab.active => !_done(c) && !c.isOverdue,
        _Tab.overdue => c.isOverdue,
        _Tab.done => _done(c),
      };
      if (!inTab) return false;
      if (q.isEmpty) return true;
      return [c.caseNumberRef, c.caseTitle, c.courtName, c.partyPetitioner, c.partyRespondent, c.surveyNumber, c.village, c.district]
          .any((v) => (v ?? '').toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => (a.deadlineDate ?? DateTime(2999)).compareTo(b.deadlineDate ?? DateTime(2999)));
  }

  Future<void> _create() async {
    final id = await showCommissionForm(context, ref);
    if (id == null || !mounted) return;
    ref.invalidate(commissionsProvider);
    context.push('/commissions/$id');
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(commissionsProvider);
    final all = data.valueOrNull ?? const <Commission>[];
    final counts = {
      _Tab.active: all.where((c) => !_done(c) && !c.isOverdue).length,
      _Tab.overdue: all.where((c) => c.isOverdue).length,
      _Tab.done: all.where(_done).length,
    };
    return Scaffold(
      backgroundColor: Cm.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 8.w, 6.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commissions', style: Cm.display(context, size: 24)),
                        Text('Advocate Commissioner · Order XXVI CPC', style: Cm.body(context, size: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _searching ? 'Close search' : 'Search',
                    icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _q = '';
                    }),
                  ),
                ],
              ),
            ),
            if (_searching)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Case number, party, court, survey no.',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: Cm.card(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Cm.border(context))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: Cm.border(context))),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 10.h),
              child: Row(
                children: [
                  for (final t in _Tab.values) ...[
                    _TabChip(
                      label: switch (t) { _Tab.active => 'Active', _Tab.overdue => 'Overdue', _Tab.done => 'Done' },
                      count: counts[t]!,
                      selected: _tab == t,
                      alert: t == _Tab.overdue && counts[t]! > 0,
                      onTap: () => setState(() => _tab = t),
                    ),
                    SizedBox(width: 6.w),
                  ],
                ],
              ),
            ),
            Expanded(
              child: data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => CmEmpty(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load commissions',
                  body: '$e',
                  action: SizedBox(width: 160.w, child: CmButton('Try again', onPressed: () => ref.invalidate(commissionsProvider))),
                ),
                data: (_) {
                  final rows = _rows(all);
                  if (rows.isEmpty) {
                    return all.isEmpty
                        ? CmEmpty(
                            icon: Icons.assignment_ind_rounded,
                            title: 'No commissions yet',
                            body: 'When a court appoints you as Advocate Commissioner, add the warrant here. '
                                'CaseFlow walks you from notice to parties to the filed report.',
                            action: SizedBox(width: 220.w, child: CmButton('Add a commission', icon: Icons.add_rounded, onPressed: _create)),
                          )
                        : CmEmpty(
                            icon: Icons.inbox_rounded,
                            title: _q.isNotEmpty ? 'Nothing matches' : 'Nothing here',
                            body: _q.isNotEmpty ? 'Try another search.' : 'Commissions move here as their status changes.',
                          );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(commissionsProvider),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 96.h),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (_, i) => _CommissionCard(c: rows[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: all.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New commission'),
              backgroundColor: Cm.violetDeep,
              foregroundColor: Colors.white,
            ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final bool alert;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.count, required this.selected, required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : (alert ? const Color(0xFFB91C1C) : Cm.sub(context));
    return Material(
      color: selected ? (Cm.dark(context) ? Cm.violet : Cm.ink) : Cm.card(context),
      shape: StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : Cm.border(context))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 8.h),
          child: Text('$label $count', style: Cm.title(context, size: 13).copyWith(color: fg)),
        ),
      ),
    );
  }
}

/// One commission: kind, reference, court, a stage bar and what comes next.
class _CommissionCard extends StatelessWidget {
  final Commission c;
  const _CommissionCard({required this.c});

  // The list has only the commission row, so the stage is read from its status.
  (int, String, String) get _stage => switch (c.status) {
        CommissionStatus.pending => (1, 'Notice to parties', 'Fix the date and serve notice'),
        CommissionStatus.inProgress => (2, 'Site visit', 'Visit the property and record'),
        CommissionStatus.visitCompleted => (3, 'Recording', 'Complete boundaries, notes and photos'),
        CommissionStatus.reportDrafting => (4, 'Preparing report', 'Check each section and file it'),
        CommissionStatus.objections => (5, 'Objections filed', 'Answer the objections'),
        CommissionStatus.submitted => (6, 'Report filed', 'Nothing pending'),
        CommissionStatus.closed => (6, 'Closed', 'Nothing pending'),
      };

  @override
  Widget build(BuildContext context) {
    final (done, stage, next) = _stage;
    final days = c.daysRemaining;
    final finished = c.status == CommissionStatus.submitted || c.status == CommissionStatus.closed;
    final (pill, tone) = finished
        ? (c.submittedOn != null ? 'Filed ${cmDate(c.submittedOn)}' : 'Done', CmTone.green)
        : days == null
            ? ('No return date', CmTone.gray)
            : days < 0
                ? ('Overdue ${-days} ${-days == 1 ? 'day' : 'days'}', CmTone.red)
                : days <= 7
                    ? ('Due in $days ${days == 1 ? 'day' : 'days'}', CmTone.amber)
                    : ('Due ${cmDate(c.deadlineDate)}', CmTone.blue);
    return CmCard(
      onTap: () => context.push('/commissions/${c.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cmTypeIcon(c.commissionType), size: 16.r, color: Cm.violet),
              SizedBox(width: 6.w),
              Flexible(child: CmPill(c.commissionType.label, tone: CmTone.violet)),
              const Spacer(),
              CmPill(pill, tone: tone),
            ],
          ),
          SizedBox(height: 10.h),
          Text(c.partiesTitle ?? c.displayRef, style: Cm.title(context, size: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
          SizedBox(height: 2.h),
          Text([if (c.partiesTitle != null) c.displayRef, c.courtName].whereType<String>().join(' · '),
              style: Cm.body(context, size: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: 12.h),
          CmStageBar(done: done),
          SizedBox(height: 8.h),
          Row(
            children: [
              Text(stage, style: Cm.title(context, size: 12.5).copyWith(color: Cm.sub(context))),
              if (!finished) ...[
                Text('  ·  ', style: Cm.body(context, size: 12.5)),
                Expanded(
                  child: Text(next, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Cm.title(context, size: 12.5).copyWith(color: const Color(0xFF2563EB))),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
