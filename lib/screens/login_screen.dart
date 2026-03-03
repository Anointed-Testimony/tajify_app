import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/custom_toast.dart';
import '../providers/auth_provider.dart';

const Color _primary = Color(0xFFEA580C);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _buttonController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isEmailMode = true;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  
  // Phone number variables
  String _phoneNumber = '';
  String _countryCode = 'NG'; // Nigeria default
  String _dialCode = '+234';
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    
    // Check if already authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        context.go('/home');
      }
    });
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() {
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _formController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _buttonController.forward();
    });
  }

  Future<void> _handleGoogleSignIn() async {
    if (!mounted) return;
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (!mounted) return;
      if (account == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      final String email = account.email;
      if (email.isEmpty) {
        ToastService.showErrorToast(context, 'Could not get email from Google');
        setState(() => _isGoogleLoading = false);
        return;
      }
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.socialLogin({
        'google_id': account.id,
        'email': email,
        'name': account.displayName ?? email.split('@').first,
        'profile_picture': account.photoUrl,
      });
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      if (success) {
        ToastService.showSuccessToast(context, 'Signed in with Google');
        context.go('/home');
      } else {
        ToastService.showErrorToast(context, authProvider.errorMessage ?? 'Google sign in failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        final isConnectionError = msg.contains('sign_in_failed') ||
            msg.contains('network') ||
            msg.contains('connection') ||
            msg.contains('Could not reach');
        ToastService.showErrorToast(
          context,
          isConnectionError
              ? 'Could not reach the server. Check your internet connection or try again.'
              : (msg.length > 80 ? 'Sign in failed' : msg),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      bool success = false;

      if (_isEmailMode) {
        success = await authProvider.loginWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        success = await authProvider.loginWithPhone(
          _phoneNumber,
          _passwordController.text,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          ToastService.showSuccessToast(context, 'Welcome back!');
          context.go('/home');
        } else {
          ToastService.showErrorToast(
            context, 
            authProvider.errorMessage ?? 'Login failed'
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastService.showErrorToast(context, 'Login failed: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _formController.dispose();
    _buttonController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/login-bg.png', // Assuming user added this or uses existing fallback
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, Color(0xFF1A1A1A)],
                ),
              ),
            ),
          ),
          
          // Dark Overlay
          Container(color: Colors.black.withOpacity(0.6)),
          
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                   const SizedBox(height: 40),
                  
                  // Clean Logo Area similar to web
                  ScaleTransition(
                    scale: _logoScaleAnimation,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _primary.withOpacity(0.4), width: 1),
                          ),
                          child: Image.asset(
                            'assets/tajify_icon.png',
                            width: 60,
                            height: 60,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Glassmorphism Form Card
                  SlideTransition(
                    position: _formSlideAnimation,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Mode Switcher
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _isEmailMode = true),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _isEmailMode 
                                                  ? Colors.white.withOpacity(0.1) 
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Email',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: _isEmailMode ? Colors.white : Colors.white54,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _isEmailMode = false),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            decoration: BoxDecoration(
                                              color: !_isEmailMode 
                                                  ? Colors.white.withOpacity(0.1) 
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Phone',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: !_isEmailMode ? Colors.white : Colors.white54,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Input Fields
                                if (_isEmailMode)
                                  _buildTextField(
                                    controller: _emailController,
                                    hint: 'Email address',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) => v!.isEmpty ? 'Email is required' : null,
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    padding: const EdgeInsets.only(left: 16, right: 8),
                                    child: InternationalPhoneNumberInput(
                                      onInputChanged: (PhoneNumber number) {
                                        _phoneNumber = number.phoneNumber ?? '';
                                        _countryCode = number.isoCode ?? 'NG';
                                        _dialCode = number.dialCode ?? '+234';
                                      },
                                      selectorConfig: const SelectorConfig(
                                        selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                                        setSelectorButtonAsPrefixIcon: true,
                                        leadingPadding: 10,
                                        trailingSpace: false,
                                      ),
                                      ignoreBlank: false,
                                      autoValidateMode: AutovalidateMode.disabled,
                                      selectorTextStyle: const TextStyle(color: Colors.white),
                                      initialValue: PhoneNumber(isoCode: _countryCode, dialCode: _dialCode),
                                      textFieldController: TextEditingController(), 
                                      formatInput: true, // changed to true for better UX
                                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                      cursorColor: const Color(0xFFF59E0B),
                                      inputDecoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Phone number',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                                      ),
                                      textStyle: const TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                  ),

                                const SizedBox(height: 16),

                                _buildTextField(
                                  controller: _passwordController,
                                  hint: 'Password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  validator: (v) => v!.isEmpty ? 'Password is required' : null,
                                ),

                                const SizedBox(height: 24),

                                // Remember Me & Forgot Password
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        // Simple checkbox placeholder logic if needed later
                                        // For clean UI standard check
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push('/forgot-password'),
                                      child: Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          color: _primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 32),

                                // Submit Button
                                ScaleTransition(
                                  scale: _buttonScaleAnimation,
                                  child: Container(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: _primary,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _primary.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24, 
                                              height: 24, 
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: _isGoogleLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                                        )
                                      : SvgPicture.asset(
                                          'assets/icons/google_logo.svg',
                                          width: 20,
                                          height: 20,
                                        ),
                                  label: Text(_isGoogleLoading ? 'Signing in...' : 'Continue with Google', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ),

                                const SizedBox(height: 24),

                                // Sign Up Link
                                Center(
                                  child: GestureDetector(
                                    onTap: () => context.go('/signup'),
                                    child: RichText(
                                      text: TextSpan(
                                        text: 'New to Tajify? ',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Create an account',
                                            style: TextStyle(
                                              color: _primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withOpacity(0.4),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}