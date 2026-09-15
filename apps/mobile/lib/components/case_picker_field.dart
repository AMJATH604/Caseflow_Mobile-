import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// How a case is named wherever an advocate has to pick one.
///
/// Party names alone are ambiguous — the same parties appear across several
/// suits and appeals — so the case number is shown alongside them.
class CaseLabels {
  CaseLabels._();

  /// Case number, falling back to the CNR; null when the case has neither.
  static String? number(CaseModel c) {
    final number = c.caseNumber?.trim() ?? '';
    if (number.isNotEmpty) return number;
    final cnr = c.cnrNumber?.trim() ?? '';
    return cnr.isNotEmpty ? cnr : null;
  }

  static String title(CaseModel c) {
    final title = c.caseTitle.trim();
    return title.isNotEmpty ? title : 'Untitled case';
  }

  /// "OS/448/2022 · Ramsanabeevi vs Hasinaabeevi"
  static String oneLine(CaseModel c) {
    final n = number(c);
    return n == null ? title(c) : '$n · ${title(c)}';
  }

  static bool matches(CaseModel c, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      c.caseNumber,
      c.cnrNumber,
      c.caseTitle,
      c.clientName,
      c.courtName,
    ].any((field) => (field ?? '').toLowerCase().contains(q));
  }
}

/// A form field for choosing a case: shows the selected case's number and
/// parties, and opens a searchable list rather than a long dropdown.
class CasePickerField extends StatelessWidget {
  final List<CaseModel> cases;
  final String? value;
  final ValueChanged<CaseModel> onSelected;
  final InputDecoration decoration;
  final String? Function(String?)? validator;
  final String sheetTitle;

  const CasePickerField({
    super.key,
    required this.cases,
    required this.value,
    required this.onSelected,
    this.decoration = const InputDecoration(),
    this.validator,
    this.sheetTitle = 'Select a case',
  });

  CaseModel? get _selected {
    for (final c in cases) {
      if (c.id == value) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return FormField<String>(
      initialValue: value,
      validator: validator,
      builder: (field) {
        return InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () async {
            FocusScope.of(context).unfocus();
            final picked = await showCasePickerSheet(
              context,
              cases: cases,
              selectedId: value,
              title: sheetTitle,
            );
            if (picked != null) {
              field.didChange(picked.id);
              onSelected(picked);
            }
          },
          child: InputDecorator(
            isEmpty: selected == null,
            decoration: decoration.copyWith(
              errorText: field.errorText,
              suffixIcon:
                  decoration.suffixIcon ??
                  const Icon(Icons.unfold_more_rounded),
            ),
            child:
                selected == null
                    ? null
                    : _SelectedCaseLabel(caseModel: selected),
          ),
        );
      },
    );
  }
}

class _SelectedCaseLabel extends StatelessWidget {
  final CaseModel caseModel;
  const _SelectedCaseLabel({required this.caseModel});

  @override
  Widget build(BuildContext context) {
    final number = CaseLabels.number(caseModel);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        children: [
          if (number != null)
            TextSpan(
              text: '$number  ·  ',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.accent,
              ),
            ),
          TextSpan(text: CaseLabels.title(caseModel)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppTheme.primary,
      ),
    );
  }
}

/// Opens a searchable list of [cases]; resolves to the one tapped, or null.
Future<CaseModel?> showCasePickerSheet(
  BuildContext context, {
  required List<CaseModel> cases,
  String? selectedId,
  String title = 'Select a case',
}) {
  return showModalBottomSheet<CaseModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder:
        (_) => _CasePickerSheet(
          cases: cases,
          selectedId: selectedId,
          title: title,
        ),
  );
}

class _CasePickerSheet extends StatefulWidget {
  final List<CaseModel> cases;
  final String? selectedId;
  final String title;

  const _CasePickerSheet({
    required this.cases,
    required this.selectedId,
    required this.title,
  });

  @override
  State<_CasePickerSheet> createState() => _CasePickerSheetState();
}

class _CasePickerSheetState extends State<_CasePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results =
        widget.cases.where((c) => CaseLabels.matches(c, _query)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            12.h,
            16.w,
            MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                widget.title,
                style: GoogleFonts.outfit(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.primary,
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by case no., party, client or court',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      _query.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _query.isEmpty
                    ? '${widget.cases.length} cases'
                    : '${results.length} of ${widget.cases.length} cases',
                style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey),
              ),
              SizedBox(height: 6.h),
              Expanded(
                child:
                    results.isEmpty
                        ? Center(
                          child: Text(
                            'No cases match "$_query"',
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        )
                        : ListView.separated(
                          controller: scrollController,
                          itemCount: results.length,
                          separatorBuilder:
                              (_, __) => Divider(
                                height: 1,
                                color: Colors.grey.withValues(alpha: 0.15),
                              ),
                          itemBuilder:
                              (context, index) => _CaseOption(
                                caseModel: results[index],
                                isSelected:
                                    results[index].id == widget.selectedId,
                                onTap:
                                    () => Navigator.of(
                                      context,
                                    ).pop(results[index]),
                              ),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CaseOption extends StatelessWidget {
  final CaseModel caseModel;
  final bool isSelected;
  final VoidCallback onTap;

  const _CaseOption({
    required this.caseModel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final number = CaseLabels.number(caseModel);
    final court = caseModel.courtName?.trim() ?? '';

    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            isSelected
                ? AppTheme.accent.withValues(alpha: 0.08)
                : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number ?? 'No case no.',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      fontStyle:
                          number == null ? FontStyle.italic : FontStyle.normal,
                      color: number == null ? Colors.grey : AppTheme.accent,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    CaseLabels.title(caseModel),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.primary,
                    ),
                  ),
                  if (court.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      court,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Padding(
                padding: EdgeInsets.only(left: 8.w),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
