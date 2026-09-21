import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Which generational row an heir is drawn in.
enum HeirBand { ascendant, spouse, descendant }

/// The band a share belongs to, or null when it carries no `relation`.
///
/// A null band is not an error the user should pay for: those shares are still
/// drawn, in a trailing row, so that adding a new heir to the calculator
/// without tagging it can never make that heir disappear from the tree.
HeirBand? heirBandFor(String? relation) {
  switch (relation) {
    case 'father':
    case 'mother':
      return HeirBand.ascendant;
    case 'spouse':
      return HeirBand.spouse;
    case 'son':
    case 'daughter':
      return HeirBand.descendant;
  }
  return null;
}

/// How many heir boxes fit on one line, capped at four so a box never becomes
/// too narrow to hold a rupee figure.
@visibleForTesting
int partitionTreeColumns(double availableWidth, double minBoxWidth) {
  if (availableWidth <= 0 || minBoxWidth <= 0) return 1;
  final fit = (availableWidth / minBoxWidth).floor();
  if (fit < 1) return 1;
  if (fit > 4) return 4;
  return fit;
}

/// Splits heirs into lines of at most [perRow], preserving order.
@visibleForTesting
List<List<T>> chunkHeirs<T>(List<T> items, int perRow) {
  final size = perRow < 1 ? 1 : perRow;
  final out = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    out.add(items.sublist(i, math.min(i + size, items.length)));
  }
  return out;
}

/// The caption under an heir's amount.
///
/// A residuary child is described in parts rather than as a fraction, because
/// the fraction there is of the remainder and not of the estate — printing
/// "1/6" beside a fixed sharer's "1/6" is what makes the list confusing.
@visibleForTesting
String heirChipLabel(String? relation, String? basis, String? fraction) {
  if (basis == 'residuary') {
    if (relation == 'son') return '2 parts';
    if (relation == 'daughter') return '1 part';
    return 'of remainder';
  }
  if (basis == 'mixed') return '1/6 + remainder';
  final f = fraction?.trim();
  if (f == null || f.isEmpty) return '';
  return f;
}

/// Draws a partition result as a family tree.
///
/// Reads the same `_results` rows the list view renders, and changes no
/// arithmetic — every amount shown here is the amount the list shows.
class PartitionTree extends StatelessWidget {
  const PartitionTree({
    super.key,
    required this.results,
    required this.netEstate,
    required this.deceasedGender,
    required this.currency,
    required this.isDark,
  });

  final List<Map<String, dynamic>> results;
  final double netEstate;
  final String deceasedGender;
  final NumberFormat currency;
  final bool isDark;

  Color get _line => isDark ? Colors.white24 : Colors.grey.shade300;

  List<Map<String, dynamic>> _band(HeirBand band) =>
      results
          .where((r) => heirBandFor(r['relation'] as String?) == band)
          .toList();

  double _amountOf(Map<String, dynamic> row) =>
      (row['amount'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    final ascendants = _band(HeirBand.ascendant);
    final spouses = _band(HeirBand.spouse);
    final descendants = _band(HeirBand.descendant);
    final unplaced =
        results
            .where((r) => heirBandFor(r['relation'] as String?) == null)
            .toList();

    // The rail is drawn only when children are paid out of the remainder.
    // Summing just those rows keeps the figure on the rail exactly equal to
    // the boxes beneath it, whatever else the estate did.
    final residuaryChildren =
        descendants.where((r) => r['basis'] == 'residuary').toList();
    final residue = residuaryChildren.fold<double>(
      0,
      (sum, r) => sum + _amountOf(r),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ascendants.isNotEmpty) ...[
          _bandLabel('ELDER GENERATION'),
          SizedBox(height: 6.h),
          _heirRows(ascendants),
          _spine(),
        ],
        _deceasedCard(),
        if (spouses.isNotEmpty) ...[_spine(), _heirRows(spouses)],
        if (descendants.isNotEmpty) ...[
          _spine(),
          if (residuaryChildren.isNotEmpty) ...[
            _residueRail(residue),
            SizedBox(height: 10.h),
          ],
          _bandLabel('YOUNGER GENERATION'),
          SizedBox(height: 6.h),
          _heirRows(descendants),
        ],
        if (unplaced.isNotEmpty) ...[
          SizedBox(height: 14.h),
          _bandLabel('OTHER HEIRS'),
          SizedBox(height: 6.h),
          _heirRows(unplaced),
        ],
      ],
    );
  }

  Widget _bandLabel(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 9.sp,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: Colors.grey[500],
    ),
  );

  Widget _spine() =>
      Center(child: Container(width: 2, height: 14.h, color: _line));

  Widget _deceasedCard() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: isDark ? 0.18 : 0.06),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              'DECEASED ($deceasedGender)',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              currency.format(netEstate),
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The band where the denominator changes — the one thing the flat list
  /// cannot show.
  Widget _residueRail(double residue) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REMAINDER (ASABA)',
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                currency.format(residue),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Shared below after the fixed shares are paid. '
            'A son takes 2 parts, a daughter 1.',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _heirRows(List<Map<String, dynamic>> heirs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = partitionTreeColumns(constraints.maxWidth, 104.w);
        final rows = chunkHeirs(heirs, cols);
        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: 10.h),
              _connectors(rows[i].length, cols, constraints.maxWidth),
              _boxRow(rows[i], cols),
            ],
          ],
        );
      },
    );
  }

  /// A rail spanning the row, with a stub dropping onto each box. Drawn from
  /// the measured slot width so the stubs land on the box centres exactly.
  Widget _connectors(int count, int cols, double maxWidth) {
    final slot = maxWidth / cols;
    final lead = (cols - count) ~/ 2;
    final left = (lead + 0.5) * slot;
    final right = maxWidth - (lead + count - 0.5) * slot;

    return Column(
      children: [
        Container(
          height: 1,
          margin: EdgeInsets.only(left: left, right: right < 0 ? 0 : right),
          color: _line,
        ),
        Row(
          children: [
            for (var i = 0; i < cols; i++)
              Expanded(
                child: Center(
                  child: Container(
                    width: 2,
                    height: 10.h,
                    color:
                        (i >= lead && i < lead + count)
                            ? _line
                            : Colors.transparent,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Equal-width slots so a short row stays centred and every box on the page
  /// is the same size — a wider box must never read as a larger share.
  Widget _boxRow(List<Map<String, dynamic>> heirs, int cols) {
    final lead = (cols - heirs.length) ~/ 2;
    // IntrinsicHeight rather than a fixed box height: the boxes still match
    // each other, but a long name or a large accessibility text size grows
    // the row instead of overflowing it.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cols; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                child:
                    (i >= lead && i < lead + heirs.length)
                        ? _heirBox(heirs[i - lead])
                        : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heirBox(Map<String, dynamic> row) {
    final relation = row['relation'] as String?;
    final colour = _relationColour(relation);
    final chip = heirChipLabel(
      relation,
      row['basis'] as String?,
      row['fraction']?.toString(),
    );

    return Container(
      constraints: BoxConstraints(minHeight: 88.h),
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_relationIcon(relation), size: 16, color: colour),
          SizedBox(height: 3.h),
          Text(
            row['heir']?.toString() ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 2.h),
          Text(
            currency.format(_amountOf(row)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
          if (chip.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              chip,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.sp, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Color _relationColour(String? relation) {
    switch (relation) {
      case 'father':
      case 'mother':
        return AppTheme.accentViolet;
      case 'spouse':
        return AppTheme.accent;
      case 'son':
      case 'daughter':
        return AppTheme.success;
    }
    return Colors.grey;
  }

  IconData _relationIcon(String? relation) {
    switch (relation) {
      case 'father':
      case 'son':
        return Icons.man_rounded;
      case 'mother':
      case 'daughter':
        return Icons.woman_rounded;
      case 'spouse':
        return Icons.favorite_rounded;
    }
    return Icons.person_rounded;
  }
}
