import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/payment_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_config.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class UpgradePlanDialog extends StatefulWidget {
  final String targetTier; // 'pro' or 'business'
  const UpgradePlanDialog({super.key, this.targetTier = 'pro'});

  @override
  State<UpgradePlanDialog> createState() => _UpgradePlanDialogState();
}

class _UpgradePlanDialogState extends State<UpgradePlanDialog> {
  late PaymentService _paymentService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        await SupabaseService.client
            .from('profiles')
            .update({
              'subscription_tier': widget.targetTier,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Upgrade Successful! Welcome to ${widget.targetTier == 'pro' ? 'Pro' : 'Business'}.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _startCheckout() {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    final isPro = widget.targetTier == 'pro';

    _paymentService.openCheckout(
      amount: isPro ? AppConfig.proPlanPrice : AppConfig.businessPlanPrice,
      name: isPro ? AppConfig.proPlanName : AppConfig.businessPlanName,
      description:
          isPro
              ? 'Unlimited Case Management & Document Tools'
              : 'Law Firm Management, Team Collaboration & Pro Features',
      userEmail: user.email ?? '',
      userContact: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = widget.targetTier == 'pro';
    final planName = isPro ? 'Pro' : 'Business';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 400),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient:
                    isPro
                        ? AppTheme.primaryGradient
                        : const LinearGradient(
                          colors: [Colors.purple, Colors.indigo],
                        ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPro
                    ? Icons.workspace_premium_rounded
                    : Icons.business_center_rounded,
                color: const Color(0xFF1E293B),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Unlock CaseFlow $planName',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPro
                  ? 'Everything you need to run a modern legal practice — all in one powerful app.'
                  : 'Transform your workspace into a collaborative law firm chambers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Features list (scrollable)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children:
                      isPro
                          ? [
                            _buildFeatureRow(
                              Icons.work_rounded,
                              'Unlimited Cases',
                              'No 10-case limit',
                            ),
                            _buildFeatureRow(
                              Icons.picture_as_pdf_rounded,
                              'Document Tools',
                              'PDF, Word, OCR conversions',
                            ),
                            _buildFeatureRow(
                              Icons.notifications_active_rounded,
                              'Smart Notifications',
                              'Hearing reminders',
                            ),
                            _buildFeatureRow(
                              Icons.science_rounded,
                              'Evidence Lab',
                              'Evidence & witness notes',
                            ),
                          ]
                          : [
                            _buildFeatureRow(
                              Icons.business_rounded,
                              'Law Firm Chambers',
                              'Shared workspace for team',
                            ),
                            _buildFeatureRow(
                              Icons.person_add_rounded,
                              'Invite Junior Advocates',
                              'Build your team (Max 5)',
                            ),
                            _buildFeatureRow(
                              Icons.forum_rounded,
                              'Intra-Team Chat',
                              'Chat safely about case files',
                            ),
                            _buildFeatureRow(
                              Icons.assignment_ind_rounded,
                              'Case Assignment',
                              'Delegate work to associates',
                            ),
                            _buildFeatureRow(
                              Icons.all_inclusive_rounded,
                              'All Pro Features',
                              'Includes everything in Pro',
                            ),
                          ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Price
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isPro
                          ? AppTheme.accent.withValues(alpha: 0.3)
                          : Colors.purple.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$planName Plan',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        isPro
                            ? '₹${AppConfig.proMonthlyPrice.toInt()}/mo or ₹${AppConfig.proYearlyPrice.toInt()}/yr'
                            : '₹${AppConfig.businessMonthlyPrice.toInt()}/mo or ₹${AppConfig.businessYearlyPrice.toInt()}/yr',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    isPro
                        ? '₹${AppConfig.proPlanPrice.toInt()}'
                        : '₹${AppConfig.businessPlanPrice.toInt()}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isPro ? AppTheme.primary : Colors.purple,
                    ),
                  ),
                  Text(
                    '/yr',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _startCheckout,
                icon:
                    _isProcessing
                        ? null
                        : const Icon(Icons.bolt_rounded, size: 20),
                label:
                    _isProcessing
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          'Upgrade to $planName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPro ? AppTheme.primary : Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
