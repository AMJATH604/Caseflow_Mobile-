import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/case_dossier_models.dart';
import '../../services/providers.dart';
import '../../services/supabase_service.dart';
import '../../services/storage_links.dart';
import '../../theme/app_theme.dart';
import 'dossier_shared.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InterimOrdersSection extends ConsumerStatefulWidget {
  final String caseId;

  const InterimOrdersSection({super.key, required this.caseId});

  @override
  ConsumerState<InterimOrdersSection> createState() =>
      _InterimOrdersSectionState();
}

class _InterimOrdersSectionState extends ConsumerState<InterimOrdersSection> {
  void _deleteItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete order?'),
            content: const Text(
              'Are you sure you want to remove this order entry?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.deleteInterimOrder(id);
      ref.invalidate(caseInterimOrdersProvider(widget.caseId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddInterimOrderDialog() {
    final summaryCtrl = TextEditingController();
    DateTime orderDate = DateTime.now();
    String orderType = 'deposition';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => Container(
                  padding: EdgeInsets.only(
                    left: 24.w,
                    right: 24.w,
                    top: 24.h,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          'Add Interim Order',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Order Date'),
                          subtitle: Text(
                            DateFormat('dd MMM yyyy').format(orderDate),
                          ),
                          trailing: const Icon(
                            Icons.calendar_today,
                            color: AppTheme.accent,
                          ),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: orderDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) setSheetState(() => orderDate = d);
                          },
                        ),
                        SizedBox(height: 12.h),
                        DropdownButtonFormField<String>(
                          initialValue: orderType,
                          decoration: InputDecoration(
                            labelText: 'Order Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          items:
                              [
                                'deposition',
                                'interim_order',
                                'stay_order',
                              ].map((s) {
                                final label = s.replaceAll('_', ' ');
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    label[0].toUpperCase() + label.substring(1),
                                  ),
                                );
                              }).toList(),
                          onChanged: (v) => orderType = v ?? 'deposition',
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: summaryCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Order Summary / Notes',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                final existing =
                                    ref
                                        .read(
                                          caseInterimOrdersProvider(
                                            widget.caseId,
                                          ),
                                        )
                                        .value ??
                                    [];
                                await SupabaseService.createInterimOrder({
                                  'case_id': widget.caseId,
                                  'order_number': existing.length + 1,
                                  'order_date':
                                      orderDate.toIso8601String().split('T')[0],
                                  'order_type': orderType,
                                  'order_summary':
                                      summaryCtrl.text.trim().isNotEmpty
                                          ? summaryCtrl.text.trim()
                                          : null,
                                });
                                ref.invalidate(
                                  caseInterimOrdersProvider(widget.caseId),
                                );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text(
                              'Add Order',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildInterimOrdersTable(List<CaseInterimOrder> orders) {
    final df = DateFormat('dd-MM-yyyy');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7.r)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'ORDER #',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ORDER DATE',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'DETAILS',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(width: 24.w),
              ],
            ),
          ),
          ...orders.asMap().entries.map((entry) {
            final idx = entry.key;
            final order = entry.value;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${order.orderNumber ?? idx + 1}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      df.format(order.orderDate),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child:
                        order.documentUrl != null
                            ? GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(
                                  await StorageLinks.resolve(
                                    order.documentUrl!,
                                  ),
                                );
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              child: Text(
                                order.orderSummary ??
                                    "Copy Of ${order.orderType == 'deposition' ? 'Deposition' : 'Order'}",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            )
                            : Text(
                              order.orderSummary ??
                                  "Copy Of ${order.orderType == 'deposition' ? 'Deposition' : 'Order'}",
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                  ),
                  GestureDetector(
                    onTap: () => _deleteItem(order.id),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(caseInterimOrdersProvider(widget.caseId));

    return DossierSection(
      icon: Icons.receipt_long_rounded,
      title: 'Interim Orders',
      color: const Color(0xFFDC2626),
      trailing: DossierHelper.addButton(() => _showAddInterimOrderDialog()),
      children: [
        ordersAsync.when(
          data:
              (orders) =>
                  orders.isEmpty
                      ? DossierHelper.emptyHint(
                        'No interim orders recorded. Tap + to add depositions.',
                      )
                      : _buildInterimOrdersTable(orders),
          loading:
              () => Padding(
                padding: EdgeInsets.all(16.r),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          error: (e, _) => DossierHelper.emptyHint('Error loading orders'),
        ),
      ],
    );
  }
}
