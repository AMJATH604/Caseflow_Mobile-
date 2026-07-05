import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'edit_client_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Premium bottom sheet showing detailed client information,
/// linked cases, and edit/delete actions.
class ClientDetailSheet extends ConsumerWidget {
  final ClientModel client;

  const ClientDetailSheet({super.key, required this.client});

  static void show(BuildContext context, ClientModel client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientDetailSheet(client: client),
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF0EA5E9),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _avatarColor(client.name);
    final casesAsync = ref.watch(casesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.all(24.r),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 24.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // ─── Profile Header ──────────────────────
              Row(
                children: [
                  // Gradient avatar
                  Container(
                    width: 64.w,
                    height: 64.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        client.name[0].toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          style: GoogleFonts.outfit(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Container(
                              width: 6.w,
                              height: 6.h,
                              decoration: BoxDecoration(
                                color:
                                    client.hasActiveCases
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              client.hasActiveCases
                                  ? 'Active Client'
                                  : 'No Active Cases',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color:
                                    client.hasActiveCases
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF94A3B8),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            if (client.caseCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  '${client.caseCount} Cases',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // ─── Action Buttons ──────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildAction(
                      context,
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => EditClientDialog(client: client),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 10.w),
                  if (client.phone != null && client.phone!.isNotEmpty)
                    Expanded(
                      child: _buildAction(
                        context,
                        icon: Icons.phone_rounded,
                        label: 'Call',
                        color: const Color(0xFF10B981),
                        onTap: () => _launchPhone(client.phone!),
                      ),
                    ),
                  if (client.phone != null && client.phone!.isNotEmpty)
                    SizedBox(width: 10.w),
                  if (client.email != null && client.email!.isNotEmpty)
                    Expanded(
                      child: _buildAction(
                        context,
                        icon: Icons.email_rounded,
                        label: 'Email',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => _launchEmail(client.email!),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 24.h),

              // ─── Contact Information ─────────────────
              _buildSection('CONTACT INFORMATION', [
                if (client.phone != null && client.phone!.isNotEmpty)
                  _buildInfoRow(
                    Icons.phone_rounded,
                    'Phone',
                    client.phone!,
                    const Color(0xFF10B981),
                    context,
                  ),
                if (client.email != null && client.email!.isNotEmpty)
                  _buildInfoRow(
                    Icons.email_rounded,
                    'Email',
                    client.email!,
                    const Color(0xFF3B82F6),
                    context,
                  ),
                if (client.address != null && client.address!.isNotEmpty)
                  _buildInfoRow(
                    Icons.location_on_rounded,
                    'Address',
                    client.address!,
                    const Color(0xFFF59E0B),
                    context,
                  ),
                if (client.state != null && client.state!.isNotEmpty)
                  _buildInfoRow(
                    Icons.map_rounded,
                    'State',
                    client.state!,
                    const Color(0xFF6366F1),
                    context,
                  ),
                if (client.district != null && client.district!.isNotEmpty)
                  _buildInfoRow(
                    Icons.domain_rounded,
                    'District',
                    client.district!,
                    const Color(0xFF0EA5E9),
                    context,
                  ),
              ]),

              SizedBox(height: 20.h),

              // ─── Linked Cases ────────────────────────
              _buildSectionHeader('LINKED CASES'),
              SizedBox(height: 12.h),
              casesAsync.when(
                data: (cases) {
                  final clientCases =
                      cases.where((c) => c.clientId == client.id).toList();
                  if (clientCases.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E2030)
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color:
                              isDark
                                  ? const Color(0xFF2D3748)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No cases linked to this client',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children:
                        clientCases
                            .map((c) => _buildCaseCard(context, c, isDark))
                            .toList(),
                  );
                },
                loading:
                    () => const Padding(
                      padding: EdgeInsets.all(20.r),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                error: (_, __) => const SizedBox.shrink(),
              ),

              SizedBox(height: 24.h),

              // ─── Metadata Footer ─────────────────────
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1E2030)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Member since ${DateFormat('MMMM d, yyyy').format(client.createdAt)}",
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        SizedBox(height: 12.h),
        ...children,
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF64748B),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color color,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied: $value'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          );
          Clipboard.setData(ClipboardData(text: value));
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2030) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.copy_rounded,
                size: 14,
                color: Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaseCard(
    BuildContext context,
    CaseModel caseModel,
    bool isDark,
  ) {
    final statusColor =
        caseModel.status == CaseStatus.active
            ? const Color(0xFF10B981)
            : const Color(0xFF64748B);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2030) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 32.h,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caseModel.caseTitle,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  "${caseModel.caseNumber ?? 'No Number'} • ${caseModel.status.name.toUpperCase()}",
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

  void _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
