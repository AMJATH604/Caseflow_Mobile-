import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/providers.dart';
import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import '../models/geo_data.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Professional Details for Signup
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _regNoController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedState;
  String? _selectedDistrict;

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _regNoController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    if (_isSignUp) {
      if (_nameController.text.isEmpty || 
          _mobileController.text.isEmpty || 
          _regNoController.text.isEmpty || 
          _addressController.text.isEmpty || 
          _selectedState == null || 
          _selectedDistrict == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in all professional details")),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // Retry up to 3 times with exponential backoff
    int attempt = 0;
    const maxAttempts = 3;

    while (attempt < maxAttempts) {
      try {
        if (_isSignUp) {
          final res = await SupabaseService.client.auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            data: {
              'full_name': _nameController.text.trim(),
              'mobile_number': _mobileController.text.trim(),
              'registration_number': _regNoController.text.trim(),
              'practice_state': _selectedState,
              'practice_district': _selectedDistrict,
              'office_address': _addressController.text.trim(),
              'is_public_directory_enabled': true,
            },
          ).timeout(const Duration(seconds: 15));

          if (res.user != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Sign up successful! Please check your email for verification."), backgroundColor: Colors.green),
            );
            setState(() => _isSignUp = false);
          }
        } else {
          await SupabaseService.signIn(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          ).timeout(const Duration(seconds: 15));
          
          // Refresh profile after login
          ref.invalidate(userProfileProvider);
          
          // Save/refresh FCM token for push notifications
          await FcmService().initialize();
        }
        // Success — exit the retry loop
        if (mounted) setState(() => _isLoading = false);
        return;
      } catch (e) {
        attempt++;
        final errorStr = e.toString().toLowerCase();
        final isTimeout = errorStr.contains('timed out') || 
                          errorStr.contains('socketexception') ||
                          errorStr.contains('connection') ||
                          errorStr.contains('timeout');

        if (attempt < maxAttempts && isTimeout) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }

        if (mounted) {
          String userMessage;
          if (isTimeout) {
            userMessage = "Cannot connect to server. Please check your internet connection.";
          } else if (errorStr.contains('invalid login')) {
            userMessage = "Invalid email or password.";
          } else if (errorStr.contains('email not confirmed')) {
            userMessage = "Please verify your email before signing in.";
          } else if (errorStr.contains('already registered')) {
            userMessage = "This email is already registered. Please sign in.";
          } else {
            userMessage = "Authentication failed: ${e.toString()}";
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userMessage),
              backgroundColor: isTimeout ? Colors.orange : Colors.red,
            ),
          );
        }
        break;
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.gavel_rounded, color: Color(0xFF1E293B), size: 36),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isSignUp ? "Join CaseFlow" : "Welcome Back",
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 24),

                      // Basic Auth Fields
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400]),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400]),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                      ),

                      if (_isSignUp) ...[
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text("Advocate Professional Details", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Mobile Number",
                            prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey[400]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _regNoController,
                          decoration: InputDecoration(
                            labelText: "Bar Council Reg No.",
                            hintText: "e.g. MS/1234/2020",
                            prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey[400]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // State/District Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedState,
                                decoration: const InputDecoration(labelText: "State", contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                                items: stateDistricts.keys.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) => setState(() { _selectedState = val; _selectedDistrict = null; }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedDistrict,
                                decoration: const InputDecoration(labelText: "District", contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                                items: (_selectedState != null ? stateDistricts[_selectedState]! : <String>[]).map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) => setState(() => _selectedDistrict = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: "Office Address",
                            prefixIcon: Icon(Icons.business_outlined, color: Colors.grey[400]),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isSignUp ? "Create Advocate Account" : "Sign In", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up",
                          style: TextStyle(color: AppTheme.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
