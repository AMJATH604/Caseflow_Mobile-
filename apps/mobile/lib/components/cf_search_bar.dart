import 'package:flutter/material.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Search Bar
///
/// Premium search bar with filter support, clear button, and
/// optional voice search. Used across cases, hearings, tools, etc.
///
/// Usage:
///   CfSearchBar(
///     hint: 'Search cases...',
///     onChanged: (query) => setState(() => _query = query),
///     onFilterTap: () => showFilterSheet(context),
///   )
/// ══════════════════════════════════════════════════════════════

class CfSearchBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final bool showFilter;
  final TextEditingController? controller;
  final bool autofocus;

  const CfSearchBar({
    super.key,
    this.hint = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.showFilter = false,
    this.controller,
    this.autofocus = false,
  });

  @override
  State<CfSearchBar> createState() => _CfSearchBarState();
}

class _CfSearchBarState extends State<CfSearchBar> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: CfSpacing.borderRadiusFull,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: CfSpacing.base),

          // Search icon
          Icon(
            Icons.search_rounded,
            size: 20,
            color: colors.textTertiary,
          ),

          const SizedBox(width: CfSpacing.sm),

          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: CfTypography.bodyMd.copyWith(
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: CfTypography.bodyMd.copyWith(
                  color: colors.textTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Clear button (animated)
          AnimatedSwitcher(
            duration: CfDecorations.durationFast,
            child: _hasText
                ? GestureDetector(
                    key: const ValueKey('clear'),
                    onTap: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(CfSpacing.sm),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colors.textTertiary.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),

          // Filter button
          if (widget.showFilter) ...[
            Container(
              width: 1,
              height: 24,
              color: colors.border,
            ),
            GestureDetector(
              onTap: widget.onFilterTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CfSpacing.md),
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ] else
            const SizedBox(width: CfSpacing.md),
        ],
      ),
    );
  }
}
