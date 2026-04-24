import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Premium auto-popup dialog shown when a user returns from the ePay portal.
/// Pre-fills the case info and asks for amount + receipt upload.
class PaymentCaptureOverlay extends ConsumerStatefulWidget {
  final String caseId;
  final String caseTitle;
  final String purpose;
  final String? certifiedCopyId;

  const PaymentCaptureOverlay({
    super.key,
    required this.caseId,
    required this.caseTitle,
    this.purpose = 'Court Fee',
    this.certifiedCopyId,
  });

  /// Show this overlay as a full-screen dialog.
  static Future<void> show(
    BuildContext context, {
    required String caseId,
    required String caseTitle,
    String purpose = 'Court Fee',
    String? certifiedCopyId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => PaymentCaptureOverlay(
        caseId: caseId,
        caseTitle: caseTitle,
        purpose: purpose,
        certifiedCopyId: certifiedCopyId,
      ),
    );
  }

  @override
  ConsumerState<PaymentCaptureOverlay> createState() =>
      _PaymentCaptureOverlayState();
}

class _PaymentCaptureOverlayState
    extends ConsumerState<PaymentCaptureOverlay>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _challanController = TextEditingController();
  DateTime _paidDate = DateTime.now();
  String _selectedPurpose = 'Court Fee';
  File? _receiptImage;
  bool _isSaving = false;
  bool _uploadingReceipt = false;

  late AnimationController _entryController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  final _purposes = [
    'Court Fee',
    'Certified Copy Fee',
    'Process Fee',
    'Fine / Penalty',
    'Judicial Deposit',
    'Miscellaneous',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPurpose = widget.purpose;

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _amountController.dispose();
    _challanController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _receiptImage = File(picked.path));
    }
  }

  Future<String?> _uploadReceiptFile() async {
    if (_receiptImage == null) return null;

    setState(() => _uploadingReceipt = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final ext = _receiptImage!.path.split('.').last;
      final fileName =
          '${user.id}/${widget.caseId}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      final bytes = await _receiptImage!.readAsBytes();

      await Supabase.instance.client.storage
          .from('payment-receipts')
          .uploadBinary(fileName, bytes);

      final url = Supabase.instance.client.storage
          .from('payment-receipts')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      debugPrint('Receipt upload failed: $e');
      return null;
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  Future<void> _savePayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter the amount paid",
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Enter a valid amount",
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload receipt if selected
      String? receiptUrl;
      if (_receiptImage != null) {
        receiptUrl = await _uploadReceiptFile();
      }

      // Build the notes with challan info
      final challan = _challanController.text.trim();
      String notes = '$_selectedPurpose (ePay Portal)';
      if (challan.isNotEmpty) notes += ' | Challan: $challan';
      if (receiptUrl != null) notes += ' | Receipt: $receiptUrl';

      // Create the payment entry in the ledger
      await SupabaseService.createPayment({
        'case_id': widget.caseId,
        'paid_amount': amount,
        'total_fee': amount,
        'paid_date': DateFormat('yyyy-MM-dd').format(_paidDate),
        'payment_mode': 'ePay Portal',
        'transaction_type': 'expense',
        'notes': notes,
        'status': 'paid',
      });

      // If linked to a certified copy, update its paid_amount
      if (widget.certifiedCopyId != null) {
        await SupabaseService.updateCertifiedCopy(widget.certifiedCopyId!, {
          'paid_amount': amount,
          'portal_receipt_url': receiptUrl,
        });
      }

      // Refresh providers
      ref.invalidate(paymentsProvider);
      ref.invalidate(certifiedCopiesProvider);
      ref.read(dataRefreshProvider.notifier).state++;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "₹$amountText logged to your ledger!",
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e", style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) => Opacity(
        opacity: _fadeAnim.value,
        child: Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
      ),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildCaseContext(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPurposeSelector(),
                      const SizedBox(height: 20),
                      _buildAmountField(),
                      const SizedBox(height: 20),
                      _buildChallanField(),
                      const SizedBox(height: 20),
                      _buildDatePicker(),
                      const SizedBox(height: 20),
                      _buildReceiptUploader(),
                      const SizedBox(height: 28),
                      _buildActions(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sync_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Payment Detected",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Sync your ePay transaction to the ledger",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // Close button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 22),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseContext() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.06),
            AppTheme.info.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.folder_rounded,
                size: 18, color: AppTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Paying for",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.caseTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Auto-detected",
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF059669),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("PURPOSE",
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
                letterSpacing: 1)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedPurpose,
          isExpanded: true,
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.category_rounded,
                color: AppTheme.accent, size: 20),
            filled: true,
            fillColor: AppTheme.background.withValues(alpha: 0.5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppTheme.accent, width: 1.5)),
          ),
          items: _purposes
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _selectedPurpose = v!),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("AMOUNT PAID",
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
                letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Text(
                "₹",
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF059669),
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            hintText: "0",
            hintStyle: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[300],
            ),
            filled: true,
            fillColor: const Color(0xFFF0FDF4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFBBF7D0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFBBF7D0), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF059669), width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          autofocus: true,
        ),
      ],
    );
  }

  Widget _buildChallanField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("CHALLAN / REFERENCE NO.",
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
                letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: _challanController,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: "Optional — e.g. ECH/123456",
            prefixIcon: const Icon(Icons.receipt_long_rounded,
                color: AppTheme.accent, size: 20),
            filled: true,
            fillColor: AppTheme.background.withValues(alpha: 0.5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppTheme.accent, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("DATE OF PAYMENT",
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
                letterSpacing: 1)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _paidDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _paidDate = picked);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: AppTheme.accent, size: 20),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd MMMM yyyy').format(_paidDate),
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.primary),
                ),
                const Spacer(),
                Icon(Icons.edit_calendar_rounded,
                    size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("E-CHALLAN RECEIPT",
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
                letterSpacing: 1)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickReceipt,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _receiptImage != null
                  ? const Color(0xFFF0FDF4)
                  : AppTheme.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _receiptImage != null
                    ? const Color(0xFF059669).withValues(alpha: 0.4)
                    : AppTheme.border,
                style: _receiptImage != null
                    ? BorderStyle.solid
                    : BorderStyle.solid,
                width: _receiptImage != null ? 1.5 : 1,
              ),
            ),
            child: _receiptImage != null
                ? Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _receiptImage!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Receipt attached ✓",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                            Text(
                              "Tap to change",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _receiptImage = null),
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.grey),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          color: Colors.grey[400], size: 22),
                      const SizedBox(width: 12),
                      Text(
                        "Upload e-Challan photo",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("(Optional)",
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey[400])),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: AppTheme.border),
            ),
            child: Text("Skip",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.grey[600])),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _savePayment,
            icon: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(
              _isSaving ? "Syncing..." : "Sync to Ledger",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
