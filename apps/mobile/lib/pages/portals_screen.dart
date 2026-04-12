import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class PortalsScreen extends StatefulWidget {
  const PortalsScreen({super.key});

  @override
  State<PortalsScreen> createState() => _PortalsScreenState();
}

class _PortalsScreenState extends State<PortalsScreen> {
  Map<String, dynamic> _locations = {};
  String? _selectedState;
  String? _selectedDistrict;
  String _selectedType = 'certified_copy'; // 'certified_copy' or 'video_conference'
  bool _isLoading = true;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final String response = await rootBundle.loadString('assets/json/india_locations.json');
      final data = await json.decode(response);
      if (mounted) {
        setState(() {
          _locations = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRedirect() async {
    if (_selectedState == null || _selectedDistrict == null) return;

    setState(() => _isRedirecting = true);

    try {
      final url = await SupabaseService.getDistrictPortalUrl(
        _selectedState!, 
        _selectedDistrict!, 
        _selectedType,
      );
      
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showError("Could not launch $url");
        }
      } else {
        final typeLabel = _selectedType == 'certified_copy' ? 'Certified copy' : 'Video conferencing';
        _showError("$typeLabel portal not available for this district yet.");
      }
    } catch (e) {
      _showError("An error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => _isRedirecting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Court Portals",
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold, 
                      fontFamily: 'Playfair Display',
                      color: AppTheme.primary,
                    ),
                  ),
                  const Text(
                    "Access official district court services directly",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Smart Sync Banner


                  const SizedBox(height: 32),
                  
                  // Selection Section
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("1. Select Location"),
                              const SizedBox(height: 16),
                              _buildLocationDropdowns(),
                              const SizedBox(height: 32),
                              
                              _buildSectionTitle("2. Select Service"),
                              const SizedBox(height: 16),
                              _buildServiceSelector(),
                              const SizedBox(height: 40),
                              
                              _buildActionButton(),
                              const SizedBox(height: 16),
                              const Center(
                                child: Text(
                                  "You will be redirected to the official e-Courts portal",
                                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.primary,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildLocationDropdowns() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedState,
          decoration: _dropdownDecoration("State"),
          items: _locations.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) {
            setState(() {
              _selectedState = val;
              _selectedDistrict = null;
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedDistrict,
          decoration: _dropdownDecoration("District"),
          items: _selectedState == null 
            ? [] 
            : (_locations[_selectedState!] as List).map((d) => DropdownMenuItem(value: d.toString(), child: Text(d.toString()))).toList(),
          onChanged: (val) => setState(() => _selectedDistrict = val),
        ),
      ],
    );
  }

  Widget _buildServiceSelector() {
    return Column(
      children: [
        Row(
          children: [
            _buildServiceCard(
              'certified_copy',
              Icons.file_copy_rounded,
              "Certified Copies",
              "Check CC status",
            ),
            const SizedBox(width: 12),
            _buildServiceCard(
              'video_conference',
              Icons.videocam_rounded,
              "Video Meeting",
              "VC links & info",
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildServiceCard(
              'holiday_list',
              Icons.event_note_rounded,
              "Holiday List",
              "Official court holidays",
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // Spacer for alignment
          ],
        ),
      ],
    );
  }

  Widget _buildServiceCard(String type, IconData icon, String title, String subtitle) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? AppTheme.primary : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final canProceed = _selectedState != null && _selectedDistrict != null && !_isRedirecting;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: Colors.grey[200],
        ),
        onPressed: canProceed ? _handleRedirect : null,
        child: _isRedirecting
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Open Official Portal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.open_in_new_rounded, size: 18),
                ],
              ),
      ),
    );
  }


  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.border)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
