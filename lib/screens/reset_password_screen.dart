import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../widgets/custom_toast.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  final String? phone;
  final String? otp;
  final int? userId;
  final String? type;

  const ResetPasswordScreen({
    Key? key,
    this.email,
    this.phone,
    this.otp,
    this.userId,
    this.type,
  }) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Validate required fields
      if (widget.userId == null) {
        setState(() {
          _errorMessage = 'User ID is required. Please try the password reset process again.';
          _isLoading = false;
        });
        return;
      }

      if (widget.type == null) {
        setState(() {
          _errorMessage = 'Type is required. Please try the password reset process again.';
          _isLoading = false;
        });
        return;
      }

      // Get OTP from input field (prefer user input, fallback to passed OTP)
      final otpCode = _otpController.text.trim();
      if (otpCode.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter the OTP code sent to your ${widget.type ?? 'email/phone'}';
          _isLoading = false;
        });
        return;
      }

      if (otpCode.length != 6) {
        setState(() {
          _errorMessage = 'OTP must be 6 digits';
          _isLoading = false;
        });
        return;
      }

      final response = await _authService.resetPassword(
        userId: widget.userId!,
        code: otpCode,
        type: widget.type!,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response['success']) {
          ToastService.showSuccessToast(
            context,
            'Password reset successfully! Please login with your new password.',
          );
          
          // Navigate to login screen
          context.go('/login');
        } else {
          // Extract error message from response
          String errorMessage = 'Password reset failed';
          if (response['errors'] != null && response['errors'] is Map) {
            final errors = response['errors'] as Map;
            if (errors.isNotEmpty) {
              final firstError = errors.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                errorMessage = firstError.first.toString();
              } else if (firstError is String) {
                errorMessage = firstError;
              }
            }
          } else {
            errorMessage = response['message'] ?? 'Password reset failed';
          }
          setState(() {
            _errorMessage = errorMessage;
          });
        }
      }
    } catch (e) {
      print('Reset password error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Extract the actual error message from the exception
        String errorMessage = 'Password reset failed';
        if (e is Exception) {
          final message = e.toString();
          // Remove "Exception: " prefix if present
          if (message.startsWith('Exception: ')) {
            errorMessage = message.substring(11);
          } else {
            errorMessage = message;
          }
        } else {
          errorMessage = e.toString();
        }
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Ebrima',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your new password below',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    fontFamily: 'Ebrima',
                  ),
                ),
                const SizedBox(height: 40),

                // OTP Field
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Ebrima',
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Enter OTP Code',
                    labelStyle: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'Ebrima',
                    ),
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFB875FB), width: 2),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the OTP code';
                    }
                    if (value.length != 6) {
                      return 'OTP must be 6 digits';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),

                // Password Field
                _buildPasswordField(
                  controller: _passwordController,
                  hintText: 'New Password',
                  isVisible: _isPasswordVisible,
                  onToggleVisibility: _togglePasswordVisibility,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                      return 'Password must contain uppercase, lowercase, and number';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Confirm Password Field
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirm New Password',
                  isVisible: _isConfirmPasswordVisible,
                  onToggleVisibility: _toggleConfirmPasswordVisibility,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Colors.red[300],
                        fontSize: 14,
                        fontFamily: 'Ebrima',
                      ),
                    ),
                  ),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB875FB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFB875FB).withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Ebrima',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Back to Login
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'Back to Login',
                      style: TextStyle(
                        color: const Color(0xFFB875FB),
                        fontSize: 14,
                        fontFamily: 'Ebrima',
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'Ebrima',
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white54),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white54,
            ),
            onPressed: onToggleVisibility,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }
}

