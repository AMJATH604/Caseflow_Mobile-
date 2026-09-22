import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/firm_service.dart';
import '../theme/app_theme.dart';
import 'profile_avatar.dart';

/// Who is in the Digital Chambers room, opened by tapping the chat header.
///
/// Names, avatars and role only. Emails and phone numbers are not shown
/// because `profiles` stopped exposing them to other members in the Phase B
/// lockdown — see [FirmService.fetchChambersTeam].
Future<void> showChambersMembersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChambersMembersSheet(),
  );
}

class _ChambersMembersSheet extends StatefulWidget {
  const _ChambersMembersSheet();

  @override
  State<_ChambersMembersSheet> createState() => _ChambersMembersSheetState();
}

class _ChambersMembersSheetState extends State<_ChambersMembersSheet> {
  late Future<List<ChambersMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirmService.fetchChambersTeam();
  }

  void _retry() {
    setState(() => _future = FirmService.fetchChambersTeam());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              // Grab handle
              Container(
                margin: EdgeInsets.symmetric(vertical: 10.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 20.sp,
                      color: AppTheme.accent,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Chambers Members',
                        style: GoogleFonts.outfit(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20.sp,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              Expanded(
                child: FutureBuilder<List<ChambersMember>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accent,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _buildMessage(
                        isDark,
                        icon: Icons.error_outline_rounded,
                        title: "Couldn't load the team",
                        body: 'Check your connection and try again.',
                        action: TextButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      );
                    }

                    final members = snapshot.data ?? const <ChambersMember>[];
                    if (members.isEmpty) {
                      return _buildMessage(
                        isDark,
                        icon: Icons.person_off_outlined,
                        title: 'No team yet',
                        body:
                            'Recruit an associate, or accept an invitation to '
                            'join a senior, and they will appear here.',
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 12.h,
                      ),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => SizedBox(height: 4.h),
                      itemBuilder: (context, i) =>
                          _buildMemberTile(members[i], isDark),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberTile(ChambersMember m, bool isDark) {
    final roleColor = m.isSenior ? AppTheme.accent : const Color(0xFF64748B);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          ProfileAvatar(
            avatarUrl: m.avatarUrl,
            name: m.name,
            radius: 20.r,
            showBorder: false,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (m.isMe) ...[
                      SizedBox(width: 6.w),
                      Text(
                        '(You)',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  m.roleLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: roleColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    bool isDark, {
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40.sp, color: const Color(0xFF94A3B8)),
            SizedBox(height: 12.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                height: 1.5,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            if (action != null) ...[SizedBox(height: 8.h), action],
          ],
        ),
      ),
    );
  }
}
