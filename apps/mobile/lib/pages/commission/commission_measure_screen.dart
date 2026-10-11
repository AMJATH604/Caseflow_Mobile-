import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/commission/cm_kit.dart';
import '../../models/commission_models.dart';
import '../../services/commission_service.dart';
import '../../theme/app_theme.dart';
import 'commission_data.dart';

String _num(double v) {
  final s = v.toStringAsFixed(v.abs() >= 100 ? 0 : 2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// Boundaries (N/S/E/W) and the extent found at site, one card per lot or
/// schedule property, compared with the extent in the plaint schedule.
class CommissionMeasureScreen extends ConsumerWidget {
  final String commissionId;
  final String? visitId; // set when opened from a site visit
  const CommissionMeasureScreen({super.key, required this.commissionId, this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commissionBundleProvider(commissionId));
    return CmScaffold(
      title: 'Boundaries & extent',
      bottom: CmButton('Add property or lot', icon: Icons.add_rounded,
          onPressed: async.valueOrNull == null ? null : () => _edit(context, ref, async.value!, null)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (b) {
          if (b.measurements.isEmpty) {
            return CmEmpty(
              icon: Icons.square_foot_rounded,
              title: 'Nothing measured yet',
              body: 'Add the schedule property — or each lot, for a partition — with its four boundaries and the extent you find at site.',
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
            children: [
              for (final m in b.measurements) ...[
                _MeasureCard(m: m, onTap: () => _edit(context, ref, b, m)),
                SizedBox(height: 12.h),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, CommissionBundle b, CommissionMeasurement? m) async {
    final label = TextEditingController(text: m?.label ?? (b.measurements.isEmpty ? 'Schedule property' : 'Lot ${String.fromCharCode(65 + b.measurements.length)}'));
    final sides = {
      'north': (TextEditingController(text: m?.northBy ?? ''), TextEditingController(text: m?.northLen ?? '')),
      'south': (TextEditingController(text: m?.southBy ?? ''), TextEditingController(text: m?.southLen ?? '')),
      'east': (TextEditingController(text: m?.eastBy ?? ''), TextEditingController(text: m?.eastLen ?? '')),
      'west': (TextEditingController(text: m?.westBy ?? ''), TextEditingController(text: m?.westLen ?? '')),
    };
    final extent = TextEditingController(text: m?.extent == null ? '' : _num(m!.extent!));
    final schedule = TextEditingController(text: m?.scheduleExtent == null ? '' : _num(m!.scheduleExtent!));
    final notes = TextEditingController(text: m?.notes ?? '');
    var unit = m?.unit ?? AreaUnit.sqFt;
    String? err;

    final saved = await showCmSheet<bool>(
      context,
      title: m == null ? 'New property or lot' : m.label,
      builder: (ctx, ss) {
        final ex = double.tryParse(extent.text.replaceAll(',', ''));
        final sc = double.tryParse(schedule.text.replaceAll(',', ''));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CmField(label, 'Name', hint: 'Schedule property, Lot A, Item 2'),
            SizedBox(height: 16.h),
            const CmLabel('Boundaries as found at site'),
            SizedBox(height: 8.h),
            for (final e in sides.entries) ...[
              Row(
                children: [
                  SizedBox(
                    width: 32.w,
                    child: Text(e.key[0].toUpperCase(), style: Cm.display(ctx, size: 18, color: Cm.violet)),
                  ),
                  Expanded(flex: 3, child: CmField(e.value.$1, 'Bounded by', hint: e.key == 'north' ? 'Panchayat road' : null)),
                  SizedBox(width: 8.w),
                  Expanded(flex: 2, child: CmField(e.value.$2, 'Length', hint: '42 ft')),
                ],
              ),
              SizedBox(height: 8.h),
            ],
            SizedBox(height: 8.h),
            const CmLabel('Extent'),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6,
              children: [
                for (final u in AreaUnit.values)
                  ChoiceChip(label: Text(u.short), selected: unit == u, onSelected: (_) => ss(() => unit = u)),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(child: CmField(extent, 'Found at site', keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => ss(() {}))),
                SizedBox(width: 8.w),
                Expanded(child: CmField(schedule, 'As per schedule', keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => ss(() {}))),
              ],
            ),
            if (ex != null) ...[
              SizedBox(height: 8.h),
              Text(
                [
                  for (final u in AreaUnit.values)
                    if (u != unit && u != AreaUnit.hectares) '${_num(unit.convert(ex, u))} ${u.short}',
                ].join(' · '),
                style: Cm.body(ctx, size: 12),
              ),
              if (sc != null)
                Text(
                  ex == sc
                      ? 'Matches the schedule.'
                      : 'Differs from the schedule by ${_num((ex - sc).abs())} ${unit.short} (${ex > sc ? 'more' : 'less'}).',
                  style: Cm.body(ctx, size: 12, color: ex == sc ? AppTheme.success : AppTheme.warning),
                ),
            ],
            SizedBox(height: 10.h),
            CmField(notes, 'Notes', hint: 'How it was measured; who assisted', maxLines: 3),
            if (err != null) ...[SizedBox(height: 10.h), Text(err!, style: Cm.body(ctx, color: AppTheme.error))],
            SizedBox(height: 16.h),
            CmButton('Save', icon: Icons.check_rounded, onPressed: () async {
              if (label.text.trim().isEmpty) return ss(() => err = 'Give it a name');
              String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
              try {
                await CommissionService.saveMeasurement(
                  b.commission.id,
                  {
                    'label': label.text.trim(),
                    'north_by': t(sides['north']!.$1), 'north_len': t(sides['north']!.$2),
                    'south_by': t(sides['south']!.$1), 'south_len': t(sides['south']!.$2),
                    'east_by': t(sides['east']!.$1), 'east_len': t(sides['east']!.$2),
                    'west_by': t(sides['west']!.$1), 'west_len': t(sides['west']!.$2),
                    'extent': ex,
                    'extent_unit': unit.dbValue,
                    'schedule_extent': sc,
                    'notes': t(notes),
                    if (m == null) 'visit_id': visitId,
                    if (m == null) 'sort_order': b.measurements.length,
                  },
                  id: m?.id,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                ss(() => err = 'Could not save: $e');
              }
            }),
            if (m != null) ...[
              SizedBox(height: 8.h),
              TextButton.icon(
                onPressed: () async {
                  await CommissionService.deleteMeasurement(m.id);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ],
        );
      },
    );
    if (saved == true) ref.invalidate(commissionBundleProvider(commissionId));
  }
}

class _MeasureCard extends StatelessWidget {
  final CommissionMeasurement m;
  final VoidCallback onTap;
  const _MeasureCard({required this.m, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget side(String d, String? by, String? len) => Padding(
          padding: EdgeInsets.symmetric(vertical: 3.h),
          child: Row(
            children: [
              SizedBox(width: 22.w, child: Text(d, style: Cm.title(context, size: 13).copyWith(color: Cm.violet))),
              Expanded(child: Text(by ?? '—', style: Cm.body(context, color: by == null ? Cm.faint : Cm.text(context)))),
              Text(len ?? '', style: Cm.title(context, size: 13)),
            ],
          ),
        );
    final diff = m.difference;
    return CmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(m.label, style: Cm.title(context, size: 16))),
              CmPill(m.isComplete ? 'Complete' : 'Incomplete', tone: m.isComplete ? CmTone.green : CmTone.amber),
            ],
          ),
          SizedBox(height: 8.h),
          side('N', m.northBy, m.northLen),
          side('S', m.southBy, m.southLen),
          side('E', m.eastBy, m.eastLen),
          side('W', m.westBy, m.westLen),
          if (m.extent != null) ...[
            Divider(height: 18.h, color: Cm.border(context)),
            Text('${_num(m.extent!)} ${m.unit.short}', style: Cm.display(context, size: 22)),
            if (m.unit != AreaUnit.cents)
              Text('${_num(m.unit.convert(m.extent!, AreaUnit.cents))} cents · ${_num(m.unit.convert(m.extent!, AreaUnit.sqFt))} sq ft',
                  style: Cm.body(context, size: 12)),
            if (diff != null && diff != 0)
              Text('Schedule ${_num(m.scheduleExtent!)} ${m.unit.short} — ${_num(diff.abs())} ${diff > 0 ? 'more' : 'less'} at site',
                  style: Cm.body(context, size: 12, color: AppTheme.warning)),
          ],
        ],
      ),
    );
  }
}
