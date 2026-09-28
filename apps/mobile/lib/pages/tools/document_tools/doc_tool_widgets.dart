import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/document_tools/document_files.dart';
import '../../../services/document_tools/pdf_engine.dart';
import '../../../theme/app_theme.dart';
import 'save_to_case_sheet.dart';

bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

Color mutedText(BuildContext context) =>
    _isDark(context) ? const Color(0xFFCBD5E1) : Colors.black54;

/// Shows a tool failure in words the user can act on.
void showToolError(BuildContext context, Object error) {
  final message = error is DocumentToolException
      ? error.message
      : 'Something went wrong. Please try again.\n($error)';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppTheme.error),
  );
}

void showToolMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Scrollable tool body with the main action pinned to the bottom.
class DocToolLayout extends StatelessWidget {
  final List<Widget> children;
  final Widget? action;
  const DocToolLayout({super.key, required this.children, this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
            children: children,
          ),
        ),
        if (action != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: action,
            ),
          ),
      ],
    );
  }
}

/// A short line explaining what the tool does.
class DocToolIntro extends StatelessWidget {
  final String text;
  const DocToolIntro(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 16.h),
    child: Text(
      text,
      style: TextStyle(fontSize: 13.sp, color: mutedText(context), height: 1.4),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 18.h, bottom: 8.h),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: mutedText(context),
      ),
    ),
  );
}

/// The big "choose a file" target shown before anything is picked.
class PickTarget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const PickTarget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.accent),
            SizedBox(height: 12.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: mutedText(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One picked or produced file.
class FileCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final Widget? leading;
  final List<Widget> actions;
  const FileCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: AppTheme.cardDecoration(isDark: _isDark(context)),
      child: Row(
        children: [
          leading ?? const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.error, size: 28),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2.h),
                Text(subtitle, style: TextStyle(fontSize: 11.sp, color: mutedText(context))),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A row of mutually exclusive options.
class ChoiceRow<T> extends StatelessWidget {
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  const ChoiceRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: entry.key == value,
            onSelected: (_) => onChanged(entry.key),
            selectedColor: AppTheme.accent.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              fontSize: 12.sp,
              fontWeight: entry.key == value ? FontWeight.w700 : FontWeight.w500,
              color: entry.key == value ? AppTheme.accent : null,
            ),
          ),
      ],
    );
  }
}

/// The full-width main button; shows a spinner while [busy].
class ToolActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;
  const ToolActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
        label: Text(
          busy ? 'Working…' : label,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Shown when a tool finishes: each output file with Open, Share, Save to
/// phone and Save to case.
class ToolResultView extends StatefulWidget {
  final List<ToolFile> files;
  final String headline;
  final VoidCallback onStartOver;
  final String startOverLabel;
  final IconData startOverIcon;

  /// Save straight into this case instead of asking which one.
  final CaseTarget? caseTarget;

  /// Extra content above the files (e.g. checks) and below them.
  final List<Widget> header;
  final List<Widget> footer;
  const ToolResultView({
    super.key,
    required this.files,
    required this.headline,
    required this.onStartOver,
    this.startOverLabel = 'Start over',
    this.startOverIcon = Icons.refresh_rounded,
    this.caseTarget,
    this.header = const [],
    this.footer = const [],
  });

  @override
  State<ToolResultView> createState() => _ToolResultViewState();
}

class _ToolResultViewState extends State<ToolResultView> {
  late List<ToolFile> _files = widget.files;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showToolError(context, e);
    }
  }

  Future<void> _rename(int index) async {
    final file = _files[index];
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: baseName(file.name)),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() {
      _files = [..._files]..[index] = ToolFile(safeFileName(name), file.bytes);
    });
  }

  Future<void> _saveToDevice(ToolFile file) => _run(() async {
    final saved = await DocumentFiles.saveToDevice(file);
    if (saved && mounted) showToolMessage(context, 'Saved "${file.name}"');
  });

  @override
  Widget build(BuildContext context) {
    final multiple = _files.length > 1;
    return DocToolLayout(
      action: OutlinedButton.icon(
        onPressed: widget.onStartOver,
        icon: Icon(widget.startOverIcon),
        label: Text(widget.startOverLabel),
        style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 46.h)),
      ),
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                widget.headline,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        ...widget.header,
        for (var i = 0; i < _files.length; i++)
          FileCard(
            name: _files[i].name,
            subtitle: _files[i].sizeLabel,
            actions: [
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _rename(i),
              ),
              if (multiple) _FileMenu(file: _files[i], onSave: _saveToDevice, run: _run),
            ],
          ),
        if (!multiple) ...[
          SizedBox(height: 8.h),
          _ResultButtons(
            file: _files.single,
            target: widget.caseTarget,
            onSave: _saveToDevice,
            run: _run,
          ),
        ] else ...[
          SizedBox(height: 8.h),
          SaveToCaseButton(files: _files, target: widget.caseTarget),
        ],
        ...widget.footer,
      ],
    );
  }
}

/// Owns its text controller so it is disposed only after the dialog's
/// closing animation, not while the field is still on screen.
class _RenameDialog extends StatefulWidget {
  final String initial;
  const _RenameDialog({required this.initial});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename file'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(suffixText: '.pdf'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _ResultButtons extends StatelessWidget {
  final ToolFile file;
  final CaseTarget? target;
  final Future<void> Function(ToolFile) onSave;
  final Future<void> Function(Future<void> Function()) run;
  const _ResultButtons({
    required this.file,
    required this.target,
    required this.onSave,
    required this.run,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Padding(
        padding: EdgeInsets.all(4.r),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(minimumSize: Size(0, 46.h)),
        ),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(4.r),
          child: SaveToCaseButton(files: [file], target: target),
        ),
        Row(
          children: [
            if (DocumentFiles.canSaveToDevice) ...[
              button(Icons.visibility_outlined, 'Open', () => run(() => DocumentFiles.open(file))),
              button(Icons.download_rounded, 'Save', () => onSave(file)),
            ],
            button(Icons.share_rounded, 'Share', () => run(() => DocumentFiles.share(file))),
          ],
        ),
      ],
    );
  }
}

class _FileMenu extends StatelessWidget {
  final ToolFile file;
  final Future<void> Function(ToolFile) onSave;
  final Future<void> Function(Future<void> Function()) run;
  const _FileMenu({required this.file, required this.onSave, required this.run});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (value) {
        switch (value) {
          case 'open':
            run(() => DocumentFiles.open(file));
          case 'save':
            onSave(file);
          case 'share':
            run(() => DocumentFiles.share(file));
          case 'case':
            SaveToCaseSheet.show(context, [file]);
        }
      },
      itemBuilder: (_) => [
        if (DocumentFiles.canSaveToDevice) ...[
          const PopupMenuItem(value: 'open', child: Text('Open')),
          const PopupMenuItem(value: 'save', child: Text('Save to phone')),
        ],
        const PopupMenuItem(value: 'share', child: Text('Share')),
        const PopupMenuItem(value: 'case', child: Text('Save to case')),
      ],
    );
  }
}
