import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../components/profile_avatar.dart';
import '../models/geo_data.dart';
import '../models/models.dart';
import '../services/providers.dart';
import '../services/repositories/profile_repository.dart';
import '../theme/app_theme.dart';

/// My Account: edit the professional profile, change the login email or
/// password, and delete the account (30-day grace period).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _registration = TextEditingController();
  final _address = TextEditingController();
  String? _state;
  String? _district;
  UserProfile? _loaded;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _registration.dispose();
    _address.dispose();
    super.dispose();
  }

  void _fill(UserProfile p) {
    if (_loaded?.id == p.id) return;
    _loaded = p;
    _name.text = p.fullName ?? '';
    _mobile.text = p.mobileNumber ?? '';
    _registration.text = p.registrationNumber ?? '';
    _address.text = p.officeAddress ?? '';
    _state = stateDistricts.containsKey(p.practiceState) ? p.practiceState : null;
    _district =
        _state != null && stateDistricts[_state]!.contains(p.practiceDistrict)
            ? p.practiceDistrict
            : null;
  }

  bool get _dirty {
    final p = _loaded;
    if (p == null) return false;
    String n(String? v) => (v ?? '').trim();
    return n(_name.text) != n(p.fullName) ||
        n(_mobile.text) != n(p.mobileNumber) ||
        n(_registration.text) != n(p.registrationNumber) ||
        n(_address.text) != n(p.officeAddress) ||
        (_state ?? '') != n(p.practiceState) ||
        (_district ?? '') != n(p.practiceDistrict);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      String? blank(String v) => v.trim().isEmpty ? null : v.trim();
      await ProfileRepository.updateProfile({
        'full_name': _name.text.trim(),
        'mobile_number': blank(_mobile.text),
        'registration_number': blank(_registration.text),
        'office_address': blank(_address.text),
        'practice_state': _state,
        'practice_district': _district,
      });
      _loaded = null;
      ref.invalidate(userProfileProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile saved'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('My Account', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(child: Text('Could not load your profile: $e')),
        data: (p) {
          _fill(p);
          return Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
              children: [
                _header(p, isDark),
                SizedBox(height: 20.h),
                _section('Professional details', isDark),
                _card(isDark, [
                  _field(_name, 'Full name', Icons.person_outline_rounded,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null),
                  _field(_mobile, 'Mobile number', Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                      validator: (v) {
                        final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (d.isEmpty) return null;
                        return d.length < 10 ? 'Enter a 10-digit mobile number' : null;
                      }),
                  _field(_registration, 'Bar registration number', Icons.badge_outlined,
                      hint: 'e.g. MS/1234/2028'),
                  _dropdown(
                    label: 'Practice state',
                    icon: Icons.location_on_outlined,
                    value: _state,
                    items: stateDistricts.keys.toList(),
                    onChanged: (v) => setState(() {
                      _state = v;
                      _district = null;
                    }),
                  ),
                  _dropdown(
                    label: 'District',
                    icon: Icons.my_location_outlined,
                    value: _district,
                    items: _state == null ? const [] : stateDistricts[_state]!,
                    onChanged: (v) => setState(() => _district = v),
                  ),
                  _field(_address, 'Office address', Icons.home_work_outlined, maxLines: 3),
                ]),
                SizedBox(height: 12.h),
                SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: _dirty && !_saving ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Save changes', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 24.h),
                _section('Login & security', isDark),
                _card(isDark, [
                  _actionRow(
                    isDark,
                    icon: Icons.alternate_email_rounded,
                    title: 'Email',
                    subtitle: p.email ?? '—',
                    action: 'Change',
                    onTap: () => _changeEmail(p),
                  ),
                  _actionRow(
                    isDark,
                    icon: Icons.lock_outline_rounded,
                    title: 'Password',
                    subtitle: 'Change the password you sign in with',
                    action: 'Change',
                    onTap: _changePassword,
                  ),
                ]),
                SizedBox(height: 24.h),
                _section('Danger zone', isDark, color: AppTheme.error),
                _card(isDark, [
                  _actionRow(
                    isDark,
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete my account',
                    subtitle: 'Your login and your data are deleted after 30 days',
                    action: 'Delete',
                    danger: true,
                    onTap: () => _deleteAccount(p),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Email ──────────────────────────────────────────────────
  Future<void> _changeEmail(UserProfile p) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _Sheet(
        title: 'Change email',
        intro: 'We will send a confirmation link to the new address. Your login email changes only after you open it.',
        fields: [
          _sheetField(email, 'New email', keyboard: TextInputType.emailAddress),
          _sheetField(password, 'Current password', obscure: true),
        ],
        actionLabel: 'Send confirmation',
        onAction: () async {
          final e = email.text.trim();
          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'Enter a valid email address';
          if (e.toLowerCase() == (p.email ?? '').toLowerCase()) return 'That is already your email';
          if (!await ProfileRepository.verifyPassword(password.text)) return 'Your current password is wrong';
          try {
            await ProfileRepository.requestEmailChange(e);
          } on AuthException catch (err) {
            return err.message;
          }
          return null;
        },
      ),
    );
    if (result == 'done') {
      messenger.showSnackBar(const SnackBar(
        content: Text('Check your inbox — open the confirmation link to finish changing your email.'),
        duration: Duration(seconds: 6),
      ));
    }
  }

  // ─── Password ───────────────────────────────────────────────
  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final again = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _Sheet(
        title: 'Change password',
        intro: 'Use at least 8 characters, with an uppercase letter and a number.',
        fields: [
          _sheetField(current, 'Current password', obscure: true),
          _sheetField(next, 'New password', obscure: true),
          _sheetField(again, 'Repeat new password', obscure: true),
        ],
        actionLabel: 'Change password',
        onAction: () async {
          final n = next.text;
          if (n.length < 8 || !RegExp(r'[A-Z]').hasMatch(n) || !RegExp(r'\d').hasMatch(n)) {
            return 'Use at least 8 characters, with an uppercase letter and a number';
          }
          if (n != again.text) return 'The new passwords do not match';
          if (!await ProfileRepository.verifyPassword(current.text)) return 'Your current password is wrong';
          try {
            await ProfileRepository.changePassword(n);
          } on AuthException catch (err) {
            return err.message;
          }
          return null;
        },
      ),
    );
    if (result == 'done') {
      messenger.showSnackBar(
        const SnackBar(content: Text('Password changed'), backgroundColor: AppTheme.success),
      );
    }
  }

  // ─── Delete ─────────────────────────────────────────────────
  Future<void> _deleteAccount(UserProfile p) async {
    final confirm = TextEditingController();
    final password = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _Sheet(
        title: 'Delete your account?',
        danger: true,
        intro: p.firmId != null && p.firmId != p.id
            ? 'After 30 days your login and personal data are deleted. Cases, clients and documents you added to your senior\'s firm stay with the firm. Until then you can sign in and cancel.'
            : 'After 30 days your login, cases, clients, hearings, documents, chats and commissions are permanently deleted. Until then you can sign in and cancel.',
        fields: [
          _sheetField(confirm, 'Type DELETE to confirm'),
          _sheetField(password, 'Password', obscure: true),
        ],
        actionLabel: 'Delete my account',
        onAction: () async {
          if (confirm.text.trim().toUpperCase() != 'DELETE') return 'Type DELETE to confirm';
          if (!await ProfileRepository.verifyPassword(password.text)) return 'Your password is wrong';
          try {
            await ProfileRepository.requestAccountDeletion();
          } on TeamExistsException {
            return 'team';
          } catch (e) {
            return 'Could not delete: $e';
          }
          return null;
        },
      ),
    );
    if (result == 'team') {
      messenger.showSnackBar(SnackBar(
        content: const Text('You have juniors or clerks in your team. Remove them first, then delete your account.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Manage team', onPressed: () => router.go('/firm')),
      ));
    } else if (result == 'done') {
      // The profile now carries the deletion date; AppShell shows the
      // "scheduled for deletion" screen in place of the app.
      ref.invalidate(userProfileProvider);
      router.go('/');
    }
  }

  // ─── Pieces ─────────────────────────────────────────────────
  Widget _header(UserProfile p, bool isDark) => Row(
        children: [
          ProfileAvatar(avatarUrl: p.avatarUrl, name: p.fullName, radius: 30.r),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName?.isNotEmpty == true ? p.fullName! : 'Your name',
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  p.email ?? '',
                  style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _section(String title, bool isDark, {Color? color}) => Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: color ?? const Color(0xFF64748B),
          ),
        ),
      );

  Widget _card(bool isDark, List<Widget> children) => Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: 12.h),
              children[i],
            ],
          ],
        ),
      );

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
          isDense: true,
        ),
      );

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        key: ValueKey('$label-$value-${items.length}'),
        isExpanded: true,
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
        onChanged: items.isEmpty ? null : onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
          isDense: true,
        ),
      );

  Widget _actionRow(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppTheme.error : AppTheme.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: danger ? AppTheme.error : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Text(action, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController c,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
  }) =>
      TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
          isDense: true,
        ),
      );
}

/// A bottom sheet with a short explanation, a few fields and one action.
/// [onAction] returns an error message to show, 'team' as a special signal,
/// or null on success (the sheet then closes with 'done').
class _Sheet extends StatefulWidget {
  final String title;
  final String intro;
  final List<Widget> fields;
  final String actionLabel;
  final Future<String?> Function() onAction;
  final bool danger;

  const _Sheet({
    required this.title,
    required this.intro,
    required this.fields,
    required this.actionLabel,
    required this.onAction,
    this.danger = false,
  });

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onAction();
    if (!mounted) return;
    if (result == null) {
      Navigator.pop(context, 'done');
    } else if (result == 'team') {
      Navigator.pop(context, 'team');
    } else {
      setState(() {
        _busy = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? AppTheme.error : AppTheme.accent;
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: GoogleFonts.outfit(fontSize: 20.sp, fontWeight: FontWeight.w700, color: widget.danger ? AppTheme.error : null)),
          SizedBox(height: 8.h),
          Text(widget.intro, style: GoogleFonts.inter(fontSize: 13.sp, height: 1.45, color: const Color(0xFF64748B))),
          SizedBox(height: 16.h),
          for (final f in widget.fields) ...[f, SizedBox(height: 12.h)],
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Text(_error!, style: GoogleFonts.inter(fontSize: 13.sp, color: AppTheme.error)),
            ),
          SizedBox(
            height: 48.h,
            child: ElevatedButton(
              onPressed: _busy ? null : _run,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.actionLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
