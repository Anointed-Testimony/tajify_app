import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/custom_toast.dart';
import '../providers/auth_provider.dart';

const Color _primary = Color(0xFFEA580C);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  late AnimationController _formController;
  late Animation<Offset> _formSlideAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  
  bool _isEmailMode = true;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  DateTime? _selectedDate;
  
  // Username availability
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  String _usernameStatus = '';
  Timer? _usernameCheckTimer;
  
  // Phone
  String _phoneNumber = '';
  String _countryCode = 'NG';
  String _dialCode = '+234';

  // Stepper
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    _formController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _formSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic));
    
    _formController.forward();

    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameCheckTimer?.cancel();
    _formController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final username = _usernameController.text.trim();
    _usernameCheckTimer?.cancel();

    if (username.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameStatus = '';
      });
      return;
    }

    if (username.length < 3) {
      setState(() => _usernameStatus = 'Min 3 chars');
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameStatus = 'Checking...';
    });

    _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () => _checkUsernameAvailability(username));
  }

  Future<void> _checkUsernameAvailability(String username) async {
    try {
      final authService = AuthService();
      final response = await authService.checkUsernameAvailability(username);
      if (!mounted) return;

      setState(() {
        _isCheckingUsername = false;
        if (response['success'] == true) {
          _isUsernameAvailable = response['available'] == true;
          _usernameStatus = _isUsernameAvailable ? 'Available' : 'Taken';
        } else {
          _usernameStatus = 'Error';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isCheckingUsername = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentStep == 1) {
      setState(() => _currentStep = 2);
      return;
    }
    
    if (_selectedDate == null) {
      ToastService.showErrorToast(context, 'Please select your Date of Birth');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final registrationData = {
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _isEmailMode ? _emailController.text.trim() : '',
        'phone': !_isEmailMode ? _phoneNumber : '',
        'dateOfBirth': _selectedDate!.toIso8601String().split('T')[0],
        'password': _passwordController.text,
        'passwordConfirmation': _confirmPasswordController.text,
        if (_referralCodeController.text.isNotEmpty) 'ref': _referralCodeController.text.trim(),
      };

      final result = await authProvider.register(registrationData);

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success']) {
          ToastService.showSuccessToast(context, 'Registration successful! Verify to continue.');
          context.go('/otp-verification', extra: {
            'email': _isEmailMode ? _emailController.text.trim() : null,
            'phone': !_isEmailMode ? _phoneNumber : null,
            'purpose': 'registration',
            'userId': result['userId'],
          });
        } else {
          ToastService.showErrorToast(context, authProvider.errorMessage ?? 'Registration failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastService.showErrorToast(context, 'Registration failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/login-bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF111111)),
          ),
          Container(color: Colors.black.withOpacity(0.7)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                   // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_currentStep > 1) {
                            setState(() => _currentStep = 1);
                          } else {
                            context.go('/login');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Step $_currentStep of 2',
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // Form Card
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
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                if (_currentStep == 1) _buildStep1() else _buildStep2(),
                                
                                const SizedBox(height: 32),
                                
                                // Action Button
                                Container(
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
                                    onPressed: _isLoading ? null : _handleSignup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                _currentStep == 1 ? 'Continue' : 'Create Account',
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                                              ),
                                              if (_currentStep == 1) ...[
                                                const SizedBox(width: 8),
                                                const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                                              ],
                                            ],
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
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text("Sign In", style: TextStyle(color: _primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        // Auth Mode
        Row(
          children: [
            _buildAuthModeBtn('Email', true),
            const SizedBox(width: 12),
            _buildAuthModeBtn('Phone', false),
          ],
        ),
        const SizedBox(height: 24),

        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 16),
        
        // Username with status
        Stack(
          children: [
            _buildTextField(
              _usernameController, 
              'Username', 
              Icons.alternate_email,
              onChanged: (_) {}, // Handled by listener
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _isCheckingUsername
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : (_usernameController.text.isNotEmpty && _usernameStatus.isNotEmpty)
                      ? Icon(
                          _isUsernameAvailable ? Icons.check_circle : Icons.error,
                          color: _isUsernameAvailable ? Colors.green : Colors.red,
                          size: 20,
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
        if (_usernameStatus.isNotEmpty && !_isCheckingUsername)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _usernameStatus, 
                style: TextStyle(
                  color: _isUsernameAvailable ? Colors.green : Colors.red, 
                  fontSize: 12
                ),
              ),
            ),
          ),
        
        const SizedBox(height: 16),

        if (_isEmailMode)
          _buildTextField(_emailController, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress)
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.only(left: 16),
            child: InternationalPhoneNumberInput(
              onInputChanged: (PhoneNumber number) {
                _phoneNumber = number.phoneNumber ?? '';
                _countryCode = number.isoCode ?? 'NG';
              },
              selectorConfig: const SelectorConfig(selectorType: PhoneInputSelectorType.BOTTOM_SHEET),
              textStyle: const TextStyle(color: Colors.white),
              initialValue: PhoneNumber(isoCode: _countryCode, dialCode: _dialCode),
              cursorColor: _primary,
              inputDecoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Phone Number',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              ),
            ),
          ),

        const SizedBox(height: 16),
        _buildTextField(_passwordController, 'Password', Icons.lock_outline, isPassword: true),
        const SizedBox(height: 16),
        _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock_outline, isPassword: true),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Personal Details", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Tell us a bit more about you", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        const SizedBox(height: 24),

        InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 yo
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: _primary,
                      surface: Color(0xFF1A1A1A),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 12),
                Text(
                  _selectedDate == null ? 'Date of Birth' : _selectedDate.toString().split(' ')[0],
                  style: TextStyle(
                    color: _selectedDate == null ? Colors.white.withOpacity(0.3) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        _buildTextField(_referralCodeController, 'Referral Code (Optional)', Icons.person_add_outlined),
        
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: true, 
              onChanged: null,
              fillColor: MaterialStateProperty.all(_primary),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to Tajify\'s ',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    children: [
                       TextSpan(text: 'Terms', style: TextStyle(color: _primary)),
                       const TextSpan(text: ' and '),
                       TextSpan(text: 'Privacy Policy', style: TextStyle(color: _primary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthModeBtn(String title, bool isEmail) {
    final bool isSelected = _isEmailMode == isEmail;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isEmailMode = isEmail),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _primary.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _primary.withOpacity(0.5) : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? _primary : Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {
    bool isPassword = false, 
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && ((isPassword == true && controller == _passwordController) ? !_isPasswordVisible : !_isConfirmPasswordVisible),
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        validator: (v) => v!.isEmpty ? '$hint is required' : null,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4)),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(
              (controller == _passwordController ? _isPasswordVisible : _isConfirmPasswordVisible) ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withOpacity(0.4)
            ),
            onPressed: () {
              setState(() {
                if (controller == _passwordController) {
                  _isPasswordVisible = !_isPasswordVisible;
                } else {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                }
              });
            },
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}