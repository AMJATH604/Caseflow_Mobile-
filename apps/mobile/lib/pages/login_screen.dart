import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/providers.dart';
import '../services/fcm_service.dart';
import '../models/geo_data.dart';
import '../utils/responsive.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String initialRole;
  const LoginScreen({super.key, this.initialRole = 'advocate'});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _regNoController = TextEditingController();
  final _addressController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _authTab = 0; // 0 = Sign In, 1 = Register
  int _signupStep = 0; // 0 = Credentials, 1 = Professional, 2 = Location
  String? _selectedState;
  String? _selectedDistrict;
  late String _userRole; // 'advocate' or 'citizen'
  Uint8List? _selectedPhoto; // Optional profile photo for signup

  // Animations
  late AnimationController _bgController;
  late AnimationController _cardController;
  late Animation<double> _cardSlide;
  late Animation<double> _cardOpacity;
  late AnimationController _headerController;

  // Form keys
  final _signInFormKey = GlobalKey<FormState>();
  final _step0FormKey = GlobalKey<FormState>();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  // Password strength state
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _userRole = widget.initialRole;

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // FIX: Stop infinite animations after 12 seconds to prevent memory leak
    // that caused the app to crash/close after 1-3 minutes on low-end devices.
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted) {
        _bgController.stop();
        _headerController.stop();
      }
    });

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cardSlide = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );
    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _cardController.forward();
  }

  void _updatePasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;

    String label;
    Color color;
    if (strength <= 0.25) {
      label = 'Weak';
      color = const Color(0xFFEF4444);
    } else if (strength <= 0.5) {
      label = 'Fair';
      color = const Color(0xFFF59E0B);
    } else if (strength <= 0.75) {
      label = 'Good';
      color = const Color(0xFF3B82F6);
    } else {
      label = 'Strong';
      color = const Color(0xFF059669);
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    _headerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _regNoController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ─── Auth Logic ─────────────────────────────────────
  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    int attempt = 0;
    const maxAttempts = 3;

    while (attempt < maxAttempts) {
      try {
        await SupabaseService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        ).timeout(const Duration(seconds: 15));

        // Fetch user profile immediately to perform strict role check
        final profile = await SupabaseService.fetchProfile();
        if (profile.userRole != _userRole) {
          await SupabaseService.signOut();
          if (mounted) {
            setState(() => _isLoading = false);
            final capitalizedDbRole =
                profile.userRole == 'advocate' ? 'an Advocate' : 'a Citizen';
            _showError(
              'This account is registered as $capitalizedDbRole. Please go back and sign in through the correct portal.',
            );
          }
          return;
        }

        ref.invalidate(userProfileProvider);
        await FcmService().initialize();
        if (mounted) setState(() => _isLoading = false);
        return;
      } catch (e) {
        attempt++;
        final errorStr = e.toString().toLowerCase();
        final isTimeout =
            errorStr.contains('timed out') ||
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
            userMessage = 'Cannot connect to server. Check your internet.';
          } else if (errorStr.contains('invalid login')) {
            userMessage = 'Invalid email or password.';
          } else if (errorStr.contains('email not confirmed')) {
            userMessage = 'Please verify your email first.';
          } else {
            userMessage = 'Authentication failed. Please try again.';
          }
          _showError(userMessage, isWarning: isTimeout);
        }
        break;
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleSignUp() async {
    setState(() => _isLoading = true);

    int attempt = 0;
    const maxAttempts = 3;

    while (attempt < maxAttempts) {
      try {
        final res = await SupabaseService.client.auth
            .signUp(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              data: {
                'full_name': _nameController.text.trim(),
                'mobile_number': _mobileController.text.trim(),
                'registration_number':
                    _userRole == 'advocate' ? _regNoController.text.trim() : '',
                'practice_state': _selectedState,
                'practice_district': _selectedDistrict,
                'office_address':
                    _userRole == 'advocate'
                        ? _addressController.text.trim()
                        : '',
                'is_public_directory_enabled': _userRole == 'advocate',
                'user_role': _userRole,
              },
            )
            .timeout(const Duration(seconds: 15));

        if (res.user != null && mounted) {
          // Best-effort photo upload — don't block signup on failure
          if (_selectedPhoto != null) {
            try {
              await SupabaseService.updateProfilePhoto(
                res.user!.id,
                _selectedPhoto!,
              );
            } catch (_) {
              // Photo upload failed — user can add it later from dashboard
            }
          }

          _showSuccess('Account created! Please verify your email to sign in.');
          setState(() {
            _authTab = 0;
            _signupStep = 0;
            _selectedPhoto = null;
          });
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      } catch (e) {
        attempt++;
        final errorStr = e.toString().toLowerCase();
        final isTimeout =
            errorStr.contains('timed out') ||
            errorStr.contains('socketexception') ||
            errorStr.contains('connection') ||
            errorStr.contains('timeout');

        if (attempt < maxAttempts && isTimeout) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }

        if (mounted) {
          if (errorStr.contains('already registered')) {
            _showError(
              'This email is already registered. Tap Sign In to login.',
            );
            // Auto-switch to sign-in tab for convenience
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _authTab = 0;
                  _signupStep = 0;
                });
              }
            });
          } else if (isTimeout) {
            _showError('Cannot connect. Check your internet.', isWarning: true);
          } else {
            _showError('Registration failed. Please try again.');
          }
        }
        break;
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Photo Picker ─────────────────────────────────────

  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24.r),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Add Profile Photo',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'This is optional — you can always add it later',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF94A3B8),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _buildPhotoOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.pop(ctx);
                      _capturePhoto(ImageSource.camera);
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildPhotoOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF059669),
                    onTap: () {
                      Navigator.pop(ctx);
                      _capturePhoto(ImageSource.gallery);
                    },
                  ),
                ),
                if (_selectedPhoto != null) ...[
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildPhotoOption(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove',
                      color: const Color(0xFFEF4444),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedPhoto = null);
                      },
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _selectedPhoto = bytes);
      }
    } catch (e) {
      if (mounted) _showError('Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}.');
    }
  }

  Widget _buildPhotoPicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 88.w,
                  height: 88.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _selectedPhoto != null
                        ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: _selectedPhoto == null
                        ? Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 2.w,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          )
                        : null,
                  ),
                  padding: EdgeInsets.all(3.r),
                  child: CircleAvatar(
                    radius: 41,
                    backgroundColor: const Color(0xFFF8FAFC),
                    backgroundImage: _selectedPhoto != null
                        ? MemoryImage(_selectedPhoto!)
                        : null,
                    child: _selectedPhoto == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 36,
                            color: Color(0xFFCBD5E1),
                          )
                        : null,
                  ),
                ),
                // Camera badge
                Positioned(
                  bottom: 0.h,
                  right: 0.w,
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.w),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              _selectedPhoto != null ? 'Change Photo' : 'Add Photo (Optional)',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _selectedPhoto != null
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$').hasMatch(email)) {
      _showError(
        'Enter your email address above first, then tap Forgot Password.',
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        _showSuccess('Password reset link sent to $email. Check your inbox.');
      }
    } catch (e) {
      if (mounted) _showError('Failed to send reset email. Try again.');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String msg, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isWarning ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 10.w),
            Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 13.sp))),
          ],
        ),
        backgroundColor:
            isWarning ? const Color(0xFFD97706) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }

  void _showSuccess(String msg) {
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
            Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 13.sp))),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(),

          // Decorative pattern overlay
          _buildPatternOverlay(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top header section (40%)
                _buildHeaderSection(),

                // White card section (60%)
                Expanded(child: _buildCardSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder:
          (context, _) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF0A0E27),
                  Color(0xFF141B3D),
                  Color(0xFF1A237E),
                  Color(0xFF0D1B3E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  0.0,
                  0.3 + 0.05 * sin(_bgController.value * pi),
                  0.6 + 0.05 * cos(_bgController.value * pi),
                  1.0,
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildPatternOverlay() {
    return AnimatedBuilder(
      animation: _headerController,
      builder:
          (context, _) => Positioned(
            top: -50 + 20 * sin(_headerController.value * pi),
            right: -80 + 15 * cos(_headerController.value * pi),
            child: Container(
              width: 300.w,
              height: 300.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4AF37).withValues(alpha: 0.08),
                    const Color(0xFF2563EB).withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: EdgeInsets.fromLTRB(R.w(32), R.h(24), R.w(32), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo row
          Row(
            children: [
              Container(
                width: R.w(48),
                height: R.w(48),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(R.r(14)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(R.r(14)),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              R.gapW(14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CASEFLOW',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: R.sp(22),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    'Your Practice, Perfected',
                    style: GoogleFonts.inter(
                      fontSize: R.sp(11),
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                      letterSpacing: 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),

          R.gapH(28),

          // Welcome text
          Text(
            _authTab == 0 ? 'Welcome\nBack' : 'Join the\nProfession',
            style: GoogleFonts.playfairDisplay(
              fontSize: R.sp(36),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15.h,
              letterSpacing: -0.5,
            ),
          ),

          SizedBox(height: 10.h),

          // Ornamental line
          Row(
            children: [
              Container(
                width: 40.w,
                height: 2.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1.r),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFF2563EB)],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 6.w,
                height: 6.h,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          Text(
            _authTab == 0
                ? 'Sign in to access your legal workspace'
                : 'Create your advocate account in 3 simple steps',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.3,
            ),
          ),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    return AnimatedBuilder(
      animation: _cardController,
      builder:
          (context, _) => Transform.translate(
            offset: Offset(0, _cardSlide.value),
            child: Opacity(
              opacity: _cardOpacity.value,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 30,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Column(
                    children: [
                      SizedBox(height: 6.h),
                      // Drag handle
                      Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Tab bar
                      _buildTabBar(),
                      SizedBox(height: 24.h),

                      // Content
                      _authTab == 0 ? _buildSignInForm() : _buildSignUpWizard(),

                      SizedBox(height: 20.h),

                      // Social proof
                      _buildSocialProof(),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(children: [_buildTab('Sign In', 0), _buildTab('Register', 1)]),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _authTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _authTab = index;
            _signupStep = 0;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11.r),
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color:
                    isActive
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sign In Form ──────────────────────────────────

  Widget _buildSignInForm() {
    return Form(
      key: _signInFormKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'advocate@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your email';
              if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$').hasMatch(v.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              return null;
            },
          ),

          SizedBox(height: 10.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
          ),

          SizedBox(height: 8.h),
          _buildPrimaryButton(
            label: 'Sign In',
            icon: Icons.login_rounded,
            onPressed: _handleSignIn,
          ),
        ],
      ),
    );
  }

  // ─── Sign Up Wizard ────────────────────────────────

  Widget _buildSignUpWizard() {
    return Column(
      children: [
        // Step indicator
        _buildStepIndicator(),
        SizedBox(height: 24.h),

        // Step content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child:
              _signupStep == 0
                  ? _buildStep0()
                  : (_userRole == 'citizen')
                  ? _buildCitizenStep1()
                  : _signupStep == 1
                  ? _buildStep1()
                  : _buildStep2(),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final steps =
        _userRole == 'citizen'
            ? ['Account', 'Location']
            : ['Account', 'Professional', 'Location'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = _signupStep == i;
        final isComplete = _signupStep > i;

        return Expanded(
          child: Row(
            children: [
              // Step circle
              Container(
                width: 28.w,
                height: 28.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isComplete
                          ? const Color(0xFF059669)
                          : isActive
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE2E8F0),
                  boxShadow:
                      isActive
                          ? [
                            BoxShadow(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                          : null,
                ),
                child: Center(
                  child:
                      isComplete
                          ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                          : Text(
                            '${i + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color:
                                  isActive
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                            ),
                          ),
                ),
              ),
              SizedBox(width: 6.w),
              // Label
              Expanded(
                child: Text(
                  steps[i],
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isActive
                            ? const Color(0xFF0F172A)
                            : isComplete
                            ? const Color(0xFF059669)
                            : const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Connector line
              if (i < steps.length - 1)
                Container(
                  width: 16.w,
                  height: 2.h,
                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.r),
                    color:
                        isComplete
                            ? const Color(0xFF059669)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // Step 0 - Account Credentials
  Widget _buildStep0() {
    return Form(
      key: _step0FormKey,
      child: Column(
        key: const ValueKey('step0'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle(
            'Create Your Account',
            'Set up your login credentials',
          ),
          SizedBox(height: 20.h),
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'advocate@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your email';
              if (!RegExp(
                r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$',
              ).hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Min 8 chars, 1 uppercase, 1 digit',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            onChanged: _updatePasswordStrength,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 8) return 'Minimum 8 characters required';
              if (!v.contains(RegExp(r'[A-Z]'))) {
                return 'Must contain at least 1 uppercase letter';
              }
              if (!v.contains(RegExp(r'[0-9]'))) {
                return 'Must contain at least 1 digit';
              }
              return null;
            },
          ),
          // Password Strength Indicator
          if (_passwordController.text.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: _passwordStrength,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(
                        _passwordStrengthColor,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  _passwordStrengthLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: _passwordStrengthColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildRequirement(
                  '8+ chars',
                  _passwordController.text.length >= 8,
                ),
                _buildRequirement(
                  'Uppercase',
                  _passwordController.text.contains(RegExp(r'[A-Z]')),
                ),
                _buildRequirement(
                  'Number',
                  _passwordController.text.contains(RegExp(r'[0-9]')),
                ),
              ],
            ),
          ],
          SizedBox(height: 24.h),
          _buildPrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              if (_step0FormKey.currentState!.validate()) {
                setState(() => _signupStep = 1);
              }
            },
          ),
        ],
      ),
    );
  }

  // Step 1 - Professional Details
  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: Column(
        key: const ValueKey('step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle(
            'Professional Details',
            'Your Bar Council information',
          ),
          SizedBox(height: 16.h),
          _buildPhotoPicker(),
          SizedBox(height: 20.h),
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Adv. Full Name',
            icon: Icons.person_outline_rounded,
            validator:
                (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
          ),
          SizedBox(height: 16.h),
          _buildTextField(
            controller: _mobileController,
            label: 'Mobile Number',
            hint: '+91 98765 43210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator:
                (v) => (v == null || v.isEmpty) ? 'Enter mobile number' : null,
          ),
          SizedBox(height: 16.h),
          _buildTextField(
            controller: _regNoController,
            label: 'Bar Council Registration No.',
            hint: 'e.g. MS/1234/2020',
            icon: Icons.badge_outlined,
            validator:
                (v) =>
                    (v == null || v.isEmpty)
                        ? 'Enter registration number'
                        : null,
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  label: 'Back',
                  onPressed: () => setState(() => _signupStep = 0),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (_step1FormKey.currentState!.validate()) {
                      setState(() => _signupStep = 2);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Citizen Step 1 - Simplified: Name, Mobile, State, District → Submit
  Widget _buildCitizenStep1() {
    return Form(
      key: _step2FormKey, // reuse step2 form key
      child: Column(
        key: const ValueKey('citizen_step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Your Details', 'Tell us about yourself'),
          SizedBox(height: 16.h),
          _buildPhotoPicker(),
          SizedBox(height: 20.h),

          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outlined,
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          SizedBox(height: 16.h),

          _buildTextField(
            controller: _mobileController,
            label: 'Mobile Number',
            hint: '10-digit mobile number',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter mobile number';
              if (v.trim().length != 10) return 'Enter a valid 10-digit number';
              return null;
            },
          ),
          SizedBox(height: 16.h),

          // State dropdown
          _buildDropdown(
            label: 'State',
            value: _selectedState,
            icon: Icons.location_on_outlined,
            items: stateDistricts.keys.toList(),
            onChanged: (val) {
              setState(() {
                _selectedState = val;
                _selectedDistrict = null;
              });
            },
          ),
          SizedBox(height: 16.h),

          // District dropdown
          _buildDropdown(
            label: 'District',
            value: _selectedDistrict,
            icon: Icons.my_location_outlined,
            items:
                _selectedState != null
                    ? stateDistricts[_selectedState]!
                    : <String>[],
            onChanged: (val) => setState(() => _selectedDistrict = val),
          ),

          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  label: 'Back',
                  onPressed: () => setState(() => _signupStep = 0),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  label: 'Create Account',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    if (_step2FormKey.currentState!.validate() &&
                        _selectedState != null &&
                        _selectedDistrict != null) {
                      _handleSignUp();
                    } else if (_selectedState == null ||
                        _selectedDistrict == null) {
                      _showError('Please select your state and district.');
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 2 - Location & Address
  Widget _buildStep2() {
    return Form(
      key: _step2FormKey,
      child: Column(
        key: const ValueKey('step2'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Practice Location', 'Where you practice law'),
          SizedBox(height: 20.h),

          // State dropdown
          _buildDropdown(
            label: 'Practice State',
            value: _selectedState,
            icon: Icons.location_on_outlined,
            items: stateDistricts.keys.toList(),
            onChanged: (val) {
              setState(() {
                _selectedState = val;
                _selectedDistrict = null;
              });
            },
          ),
          SizedBox(height: 16.h),

          // District dropdown
          _buildDropdown(
            label: 'Practice District',
            value: _selectedDistrict,
            icon: Icons.my_location_outlined,
            items:
                _selectedState != null
                    ? stateDistricts[_selectedState]!
                    : <String>[],
            onChanged: (val) => setState(() => _selectedDistrict = val),
          ),
          SizedBox(height: 16.h),

          _buildTextField(
            controller: _addressController,
            label: 'Office Address',
            hint: 'Your chamber / office address',
            icon: Icons.business_outlined,
            maxLines: 2,
            validator:
                (v) => (v == null || v.isEmpty) ? 'Enter office address' : null,
          ),

          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  label: 'Back',
                  onPressed: () => setState(() => _signupStep = 1),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  label: 'Create Account',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    if (_step2FormKey.currentState!.validate() &&
                        _selectedState != null &&
                        _selectedDistrict != null) {
                      _handleSignUp();
                    } else if (_selectedState == null ||
                        _selectedDistrict == null) {
                      _showError('Please select your state and district.');
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ────────────────────────────────

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 14,
          color: met ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
        ),
        SizedBox(width: 4.w),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: met ? const Color(0xFF059669) : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          keyboardType: keyboardType,
          maxLines: isPassword ? 1 : maxLines,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 14.sp,
              color: const Color(0xFFCBD5E1),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
            suffixIcon:
                isPassword
                    ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    )
                    : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5.w,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          style: GoogleFonts.inter(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
            hintText: 'Select...',
            hintStyle: GoogleFonts.inter(
              fontSize: 14.sp,
              color: const Color(0xFFCBD5E1),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5.w,
              ),
            ),
          ),
          items:
              items
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    IconData? icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          disabledBackgroundColor: const Color(0xFF94A3B8),
        ),
        child:
            _isLoading
                ? SizedBox(
                  height: 22.h,
                  width: 22.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (icon != null) ...[
                      SizedBox(width: 8.w),
                      Icon(icon, size: 18),
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 54.h,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          foregroundColor: const Color(0xFF64748B),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSocialProof() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stacked avatars
          SizedBox(
            width: 60.w,
            height: 28.h,
            child: Stack(
              children: List.generate(3, (i) {
                return Positioned(
                  left: i * 18.0,
                  child: Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          [
                            const Color(0xFF2563EB),
                            const Color(0xFF059669),
                            const Color(0xFFD97706),
                          ][i],
                      border: Border.all(color: Colors.white, width: 2.w),
                    ),
                    child: Center(
                      child: Text(
                        ['A', 'S', 'K'][i],
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trusted by advocates across India',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  ...List.generate(
                    5,
                    (_) => const Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '5.0 rating',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
