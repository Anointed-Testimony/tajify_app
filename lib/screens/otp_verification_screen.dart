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

    // Check if all OTP digits are entered
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
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Debug: Print OTP verification data
      print('=== OTP VERIFICATION DEBUG ===');
      print('Email: ${widget.email}');
      print('Phone: ${widget.phone}');
      print('OTP Code: $otpCode');
      print('Purpose: ${widget.purpose}');
      print('User ID: ${widget.userId}');
      print('OTP Length: ${otpCode.length}');
      print('============================');

      final response = await _authService.verifyOtp(
        email: widget.email,
        phone: widget.phone,
        otp: otpCode,
        purpose: widget.purpose,
        userId: widget.userId,
      );

      print('OTP Verification Response: $response');

              if (response['success']) {
          print('OTP verification successful!');
          
          // Save user data if available
          if (response['data'] != null && response['data']['user'] != null) {
            await _storageService.saveUserData(response['data']['user']);
            print('User data saved after OTP verification');
          }
          
          if (widget.purpose == 'registration') {
            // Navigate to home screen after successful registration
            if (mounted) {
              context.go('/home');
            }
          } else if (widget.purpose == 'password_reset') {
            // Navigate to reset password screen
            // Extract user_id from response if available
            final userId = response['data']?['user_id'] ?? response['data']?['user']?['id'];
            final type = widget.email.isNotEmpty ? 'email' : 'phone';
            if (mounted) {
              context.go('/reset-password', extra: {
                'email': widget.email,
                'phone': widget.phone,
                'otp': otpCode,
                'userId': userId,
                'type': type,
              });
            }
          } else {
            // For login verification, just show success
            if (mounted) {
              ToastService.showSuccessToast(context, 'OTP verified successfully!');
              context.pop();
            }
          }
        } else {
        print('OTP verification failed: ${response['message']}');
        // Extract error message from response, checking for errors object first
        String errorMessage = 'OTP verification failed';
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
          errorMessage = response['message'] ?? 'OTP verification failed';
        }
        if (mounted) {
          setState(() {
            _errorMessage = errorMessage;
          });
        }
      }
    } catch (e) {
      print('OTP verification error: $e');
      // Extract the actual error message from the exception
      String errorMessage = 'OTP verification failed';
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
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        setState(() {
          _resendCountdown = 60;
        });
        _startResendCountdown();
        
        if (mounted) {
          ToastService.showSuccessToast(context, 'OTP resent successfully!');
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to resend OTP';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Header
              Text(
                'Verify Your Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Ebrima',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ve sent a 6-digit code to ${widget.phone ?? widget.email}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                  fontFamily: 'Ebrima',
                ),
              ),
              const SizedBox(height: 40),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Ebrima',
                      ),
                      decoration: InputDecoration(
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      onChanged: (value) => _onOtpChanged(value, index),
                    ),
                  );
                }),
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
              const SizedBox(height: 20),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
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
                          'Verify OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Ebrima',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),

              // Resend OTP
              Center(
                child: Column(
                  children: [
                    Text(
                      'Didn\'t receive the code?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontFamily: 'Ebrima',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resendCountdown > 0 || _isResending ? null : _resendOtp,
                      child: Text(
                        _isResending
                            ? 'Resending...'
                            : _resendCountdown > 0
                                ? 'Resend in $_resendCountdown seconds'
                                : 'Resend OTP',
                        style: TextStyle(
                          color: _resendCountdown > 0 || _isResending
                              ? Colors.grey[600]
                              : const Color(0xFFB875FB),
                          fontSize: 14,
                          fontFamily: 'Ebrima',
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
    );
  }
} 