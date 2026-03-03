import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/custom_toast.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? phone;
  final String purpose; // 'registration', 'password_reset', 'login'
  final int? userId;

  const OtpVerificationScreen({
    Key? key,
    required this.email,
    this.phone,
    required this.purpose,
    this.userId,
  }) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        _startResendCountdown();
      }
    });
  }

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_getOtpCode().length == 6) {
      _verifyOtp();
    }
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;

    final otpCode = _getOtpCode();
    if (otpCode.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _authService.verifyOtp(
        email: widget.email,
        phone: widget.phone,
        otp: otpCode,
        purpose: widget.purpose,
        userId: widget.userId,
      );

      if (response['success']) {
        if (response['data'] != null && response['data']['user'] != null) {
          await _storageService.saveUserData(response['data']['user']);
        }
        
        if (mounted) {
          ToastService.showSuccessToast(context, 'Verified successfully!');
          
          if (widget.purpose == 'registration') {
            context.go('/home');
          } else if (widget.purpose == 'password_reset') {
            final userId = response['data']?['user_id'] ?? response['data']?['user']?['id'];
            final type = widget.email.isNotEmpty ? 'email' : 'phone';
            context.go('/reset-password', extra: {
              'email': widget.email,
              'phone': widget.phone,
              'otp': otpCode,
              'userId': userId,
              'type': type,
            });
          } else {
            context.pop();
          }
        }
      } else {
        setState(() {
           _errorMessage = response['message'] ?? 'Verification failed';
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending || _resendCountdown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    try {
      final response = await _authService.resendOtp(
        email: widget.email,
        phone: widget.phone,
      );

      if (response['success']) {
        setState(() => _resendCountdown = 60);
        _startResendCountdown();
        if (mounted) ToastService.showSuccessToast(context, 'Code resent!');
      } else {
        setState(() => _errorMessage = response['message'] ?? 'Failed to resend');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 32),
                  
                  const Text(
                    'Verify Code',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit code to\n${widget.phone ?? widget.email}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // OTP Input Fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _otpControllers[index].text.isNotEmpty 
                                  ? const Color(0xFFF59E0B) 
                                  : Colors.transparent,
                            ),
                          ),
                          child: TextField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            onChanged: (value) => _onOtpChanged(value, index),
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 24),

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
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  const SizedBox(height: 40),

                  // Verify Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'Verify Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Resend OTP
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Didn\'t receive the code?',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _resendCountdown > 0 || _isResending ? null : _resendOtp,
                          child: Text(
                            _isResending
                                ? 'Resending...'
                                : _resendCountdown > 0
                                    ? 'Resend in $_resendCountdown seconds'
                                    : 'Resend Code',
                            style: TextStyle(
                              color: _resendCountdown > 0 || _isResending
                                  ? Colors.white.withOpacity(0.3)
                                  : const Color(0xFFF59E0B),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
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
}