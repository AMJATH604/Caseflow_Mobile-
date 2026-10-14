import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'title_search_detail_screen.dart';

class NewTitleSearchSheet extends StatefulWidget {
  const NewTitleSearchSheet({super.key});

  @override
  State<NewTitleSearchSheet> createState() => _NewTitleSearchSheetState();
}

class _NewTitleSearchSheetState extends State<NewTitleSearchSheet> {
  final _formKey = GlobalKey<FormState>();

  final _districtController = TextEditingController(text: 'Tirunelveli');
  final _talukController = TextEditingController(text: 'Kadayanallur');
  final _villageController = TextEditingController();
  final _surveyNoController = TextEditingController();
  final _extentController = TextEditingController();
  final _sellerController = TextEditingController();
  final _buyerController = TextEditingController();
  final _priceController = TextEditingController();

  String _extentUnit = 'acres';
  String _classification = 'wet_land';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _districtController.dispose();
    _talukController.dispose();
    _villageController.dispose();
    _surveyNoController.dispose();
    _extentController.dispose();
    _sellerController.dispose();
    _buyerController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final data = {
        'district': _districtController.text.trim(),
        'taluk': _talukController.text.trim(),
        'village': _villageController.text.trim(),
        'survey_number': _surveyNoController.text.trim(),
        'extent': double.tryParse(_extentController.text.trim()),
        'extent_unit': _extentUnit,
        'classification': _classification,
        'proposed_seller': _sellerController.text.trim().isEmpty ? null : _sellerController.text.trim(),
        'proposed_buyer': _buyerController.text.trim().isEmpty ? null : _buyerController.text.trim(),
        'proposed_price': double.tryParse(_priceController.text.trim()),
      };

      final newSearch = await SupabaseService.createTitleSearch(data);

      if (mounted) {
        Navigator.pop(context); // close sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TitleSearchDetailScreen(searchId: newSearch.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create title search: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    'New Property Due-Diligence',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
              Text(
                'Enter target property details to begin chain of title verification.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              // District & Taluk
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _districtController,
                      label: 'District *',
                      hint: 'e.g. Tirunelveli',
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _talukController,
                      label: 'Taluk *',
                      hint: 'e.g. Kadayanallur',
                      required: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Village & Survey No
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _villageController,
                      label: 'Village / Town *',
                      hint: 'e.g. Meenakshipuram',
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _surveyNoController,
                      label: 'Survey Number *',
                      hint: 'e.g. 145/2A',
                      required: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Extent & Unit
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _extentController,
                      label: 'Extent / Area',
                      hint: 'e.g. 2.5',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _extentUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'acres', child: Text('Acres')),
                        DropdownMenuItem(value: 'cents', child: Text('Cents')),
                        DropdownMenuItem(value: 'sq_feet', child: Text('Sq. Feet')),
                        DropdownMenuItem(value: 'hectares', child: Text('Hectares')),
                      ],
                      onChanged: (val) => setState(() => _extentUnit = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Proposed Parties
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _sellerController,
                      label: 'Current Seller Name',
                      hint: 'Name as in Patta/Deed',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _buyerController,
                      label: 'Proposed Buyer Name',
                      hint: 'Client Name',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Create & Upload Documents',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
