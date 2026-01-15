import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../widgets/custom_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isEmailMode = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendResetOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _authService.forgotPassword(
        email: _isEmailMode ? _emailController.text.trim() : '',
        phone: _isEmailMode ? '' : _phoneController.text.trim(),
      );

      if (response['success']) {
        if (mounted) {
          ToastService.showSuccessToast(
            context, 
            _isEmailMode 
              ? 'Password reset OTP sent to your email'
              : 'Password reset OTP sent to your phone',
          );
          
          // Extract user_id from response if available
          final userId = response['data']?['user_id'] ?? response['data']?['user']?['id'];
          final type = _isEmailMode ? 'email' : 'phone';
          
          // Navigate directly to reset password screen (skip OTP verification)
          // The password reset endpoint will verify the OTP when user submits new password
          context.go('/reset-password', extra: {
            'email': _isEmailMode ? _emailController.text.trim() : null,
            'phone': _isEmailMode ? null : _phoneController.text.trim(),
            'userId': userId,
            'type': type,
          });
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send reset instructions';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Ebrima',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your ${_isEmailMode ? 'email' : 'phone number'} to receive reset instructions',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    fontFamily: 'Ebrima',
                  ),
                ),
                const SizedBox(height: 40),

                // Mode Toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEmailMode = true;
                              _errorMessage = '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isEmailMode ? const Color(0xFFB875FB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Email',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isEmailMode ? Colors.white : Colors.grey[400],
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Ebrima',
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEmailMode = false;
                              _errorMessage = '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isEmailMode ? const Color(0xFFB875FB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Phone',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_isEmailMode ? Colors.white : Colors.grey[400],
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Ebrima',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Input Field
                if (_isEmailMode)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Ebrima',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(
                        color: Colors.grey[400],
                        fontFamily: 'Ebrima',
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
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: Colors.grey[400],
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Ebrima',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(
                        color: Colors.grey[400],
                        fontFamily: 'Ebrima',
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
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                        color: Colors.grey[400],
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid phone number';
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
                    onPressed: _isLoading ? null : _sendResetOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB875FB),
                      foregroundColor: Colors.white,
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
                            'Send Reset Instructions',
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
                    onPressed: () => Navigator.of(context).pop(),
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
} 