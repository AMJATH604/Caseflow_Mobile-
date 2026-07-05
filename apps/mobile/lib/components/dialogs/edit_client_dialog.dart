import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Pre-filled edit dialog for modifying an existing client's details.
/// Supports: name, phone, email, address, state, district.
class EditClientDialog extends ConsumerStatefulWidget {
  final ClientModel client;

  const EditClientDialog({super.key, required this.client});

  @override
  ConsumerState<EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends ConsumerState<EditClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _stateController;
  late final TextEditingController _districtController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client.name);
    _phoneController = TextEditingController(text: widget.client.phone ?? '');
    _emailController = TextEditingController(text: widget.client.email ?? '');
    _addressController = TextEditingController(
      text: widget.client.address ?? '',
    );
    _stateController = TextEditingController(text: widget.client.state ?? '');
    _districtController = TextEditingController(
      text: widget.client.district ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone':
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
        'email':
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        'address':
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        'state':
            _stateController.text.trim().isEmpty
                ? null
                : _stateController.text.trim(),
        'district':
            _districtController.text.trim().isEmpty
                ? null
                : _districtController.text.trim(),
      };

      await SupabaseService.updateClient(widget.client.id, updates);
      ref.invalidate(clientsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 10.w),
                Text('${_nameController.text.trim()} updated successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E2030) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      insetPadding: EdgeInsets.all(20.r),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.r),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Color(0xFF3B82F6),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Client',
                            style: GoogleFonts.outfit(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            "Update ${widget.client.name}'s details",
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            isDark
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Form Fields
                _buildField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_rounded,
                  validator:
                      (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Name is required'
                              : null,
                ),
                _buildField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                _buildField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildField(
                  controller: _addressController,
                  label: 'Address',
                  icon: Icons.location_on_rounded,
                  maxLines: 2,
                ),
                _buildField(
                  controller: _stateController,
                  label: 'State',
                  icon: Icons.map_rounded,
                ),
                _buildField(
                  controller: _districtController,
                  label: 'District',
                  icon: Icons.domain_rounded,
                ),

                SizedBox(height: 8.h),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child:
                        _isSaving
                            ? SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_rounded, size: 18),
                                SizedBox(width: 8.w),
                                Text(
                                  'Save Changes',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: const BorderSide(color: AppTheme.accent, width: 1.5.w),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
