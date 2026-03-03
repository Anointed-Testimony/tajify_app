import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../widgets/custom_toast.dart';

const Color _primary = Color(0xFFEA580C);

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
              ? 'Reset instructions sent to email'
              : 'Reset instructions sent to phone',
          );
          
          final userId = response['data']?['user_id'] ?? response['data']?['user']?['id'];
          final type = _isEmailMode ? 'email' : 'phone';
          
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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/login-bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF111111)),
          ),
          Container(color: Colors.black.withOpacity(0.7)),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () => context.go('/login'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 32),
                    
                    const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your ${_isEmailMode ? 'email' : 'phone number'} to receive reset instructions',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Mode Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isEmailMode = true;
                                _errorMessage = '';
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isEmailMode ? _primary.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isEmailMode ? _primary.withOpacity(0.5) : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  'Email',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isEmailMode ? _primary : Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isEmailMode = false;
                                _errorMessage = '';
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isEmailMode ? _primary.withOpacity(0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !_isEmailMode ? _primary.withOpacity(0.5) : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  'Phone',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !_isEmailMode ? _primary : Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
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
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: _isEmailMode ? TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Email Address',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.white.withOpacity(0.4)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email is required';
                          if (!value.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ) : TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Phone Number',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.phone_outlined, color: Colors.white.withOpacity(0.4)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Phone is required';
                          return null;
                        },
                      ),
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
                          style: TextStyle(color: Colors.red[300], fontSize: 14),
                        ),
                      ),
                    const SizedBox(height: 30),

                    // Submit Button
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
                        onPressed: _isLoading ? null : _sendResetOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Send Instructions',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}