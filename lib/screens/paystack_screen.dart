import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';

class PaystackScreen extends StatefulWidget {
  const PaystackScreen({
    super.key, 
    required this.url,
    required this.paymentReference,
  });

  final String url;
  final String paymentReference;

  @override
  State<PaystackScreen> createState() => _PaystackScreenState();
}

class _PaystackScreenState extends State<PaystackScreen> {
  WebViewController? _controller;
  double _progress = 0;
  String? _errorMessage;
  bool _isInitialized = false;
  bool _paymentSuccess = false;
  Timer? _verificationTimer;
  final ApiService _apiService = ApiService();
  bool _userLeftCheckoutPage = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    print('🔵 [PAYSTACK DEBUG] PaystackScreen initialized');
    print('🔵 [PAYSTACK DEBUG] Payment reference: ${widget.paymentReference}');
    print('🔵 [PAYSTACK DEBUG] Checkout URL: ${widget.url}');
    
    // Delay WebView initialization until after the first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _initializeWebView();
    });
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyPaymentWithBackend() async {
    if (_paymentSuccess || !mounted) return;
    
    print('🔵 [PAYSTACK DEBUG] Verifying payment with backend...');
    print('🔵 [PAYSTACK DEBUG] Reference: ${widget.paymentReference}');
    
    try {
      final response = await _apiService.verifyWalletPayment(widget.paymentReference);
      
      print('🔵 [PAYSTACK DEBUG] Verification response status: ${response.statusCode}');
      print('🔵 [PAYSTACK DEBUG] Verification response data: ${response.data}');
      
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final success = data['success'] == true;
        final message = data['message']?.toString() ?? '';
        
        print('🔵 [PAYSTACK DEBUG] Payment verification result:');
        print('   - Success: $success');
        print('   - Message: $message');
        print('   - Full response: $data');
        
        // Check if payment was successful
        // Backend returns success: true with message like "Payment verified and USDT added successfully!"
        if (success && message.toLowerCase().contains('success')) {
          print('✅ [PAYSTACK DEBUG] Payment verified as successful by backend!');
          _handlePaymentSuccess();
        } else if (success && message.toLowerCase().contains('verified')) {
          // Also check for "verified" in message as alternative success indicator
          print('✅ [PAYSTACK DEBUG] Payment verified by backend!');
          _handlePaymentSuccess();
        } else {
          print('🔵 [PAYSTACK DEBUG] Payment not yet successful');
          print('   - Success flag: $success');
          print('   - Message: $message');
        }
      } else {
        print('⚠️ [PAYSTACK DEBUG] Unexpected verification response format');
        print('   - Status code: ${response.statusCode}');
        print('   - Response type: ${response.data.runtimeType}');
      }
    } catch (e) {
      print('❌ [PAYSTACK DEBUG] Error verifying payment: $e');
      print('❌ [PAYSTACK DEBUG] Error type: ${e.runtimeType}');
    }
  }

  void _startVerificationTimer() {
    // Only start checking after user has left checkout page
    if (_verificationTimer != null) return;
    
    print('🔵 [PAYSTACK DEBUG] Starting payment verification timer');
    
    // Ensure verifying screen is shown
    if (mounted && !_isVerifying) {
      setState(() {
        _isVerifying = true;
      });
    }
    
    // Check every 3 seconds for payment completion
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_paymentSuccess || !mounted) {
        timer.cancel();
        return;
      }
      
      if (_userLeftCheckoutPage) {
        _verifyPaymentWithBackend();
      }
    });
  }

  void _handlePaymentSuccess() {
    if (_paymentSuccess || !mounted) return;
    
    print('✅ [PAYSTACK DEBUG] ========================================');
    print('✅ [PAYSTACK DEBUG] PAYMENT SUCCESSFUL - Closing screen');
    print('✅ [PAYSTACK DEBUG] Reference: ${widget.paymentReference}');
    print('✅ [PAYSTACK DEBUG] ========================================');
    
    // Cancel the timer
    _verificationTimer?.cancel();
    
    setState(() {
      _paymentSuccess = true;
    });
    
    // Close the screen and return success
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    });
  }

  bool _hasLeftCheckoutPage(String url) {
    // Check if URL is no longer the Paystack checkout page
    final urlLower = url.toLowerCase();
    final checkoutUrlLower = widget.url.toLowerCase();
    
    // If URL doesn't contain checkout.paystack.com, user has left
    if (!urlLower.contains('checkout.paystack.com')) {
      return true;
    }
    
    // If URL is different from the original checkout URL, user may have navigated
    if (urlLower != checkoutUrlLower && !urlLower.contains(checkoutUrlLower)) {
      return true;
    }
    
    return false;
  }

  void _initializeWebView() {
    if (!mounted) return;
    
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF111111))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (value) {
              if (mounted) {
                setState(() => _progress = value / 100);
              }
            },
            onPageStarted: (url) {
              print('🔵 [PAYSTACK DEBUG] Page started loading: $url');
              
              // Check if user has left the checkout page
              if (_hasLeftCheckoutPage(url) && !_userLeftCheckoutPage) {
                print('🔵 [PAYSTACK DEBUG] User has left checkout page');
                _userLeftCheckoutPage = true;
                // Hide WebView immediately and show verifying screen
                if (mounted) {
                  setState(() {
                    _isVerifying = true;
                  });
                }
                // Start verification timer after a delay to allow redirect to complete
                Future.delayed(const Duration(seconds: 2), () {
                  _startVerificationTimer();
                });
              }
            },
            onPageFinished: (url) async {
              print('🔵 [PAYSTACK DEBUG] Page finished loading: $url');
              
              if (mounted) {
                setState(() => _progress = 1);
              }
              
              // Check if user has left the checkout page
              if (_hasLeftCheckoutPage(url) && !_userLeftCheckoutPage) {
                print('🔵 [PAYSTACK DEBUG] User has left checkout page (onPageFinished)');
                _userLeftCheckoutPage = true;
                // Hide WebView immediately and show verifying screen
                if (mounted) {
                  setState(() {
                    _isVerifying = true;
                  });
                }
                // Start verification after page loads
                Future.delayed(const Duration(seconds: 2), () {
                  _startVerificationTimer();
                });
              }
            },
            onNavigationRequest: (request) {
              print('🔵 [PAYSTACK DEBUG] Navigation request: ${request.url}');
              
              // Allow all navigation - we'll verify payment via backend
              return NavigationDecision.navigate;
            },
            onWebResourceError: (error) {
              // Only log/show errors if we're not verifying (user is still on checkout page)
              if (!_isVerifying && !_userLeftCheckoutPage) {
                print('❌ [PAYSTACK DEBUG] Web resource error: ${error.description}');
                if (mounted) {
                  setState(() {
                    _errorMessage = error.description;
                    _progress = 0;
                  });
                }
              } else {
                // Suppress errors during verification - they're expected when redirecting
                print('🔵 [PAYSTACK DEBUG] Web resource error suppressed (verification in progress)');
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
      
      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ [PAYSTACK DEBUG] Failed to initialize WebView: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize WebView: $e';
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _progress = 0;
    });
    _controller?.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Paystack Checkout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isVerifying
          ? Container(
              color: const Color(0xFF0F0F0F),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.amber),
                    const SizedBox(height: 24),
                    const Text(
                      'Verifying Payment...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait while we confirm your payment',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                // Show WebView only when not verifying
                if (_isInitialized && _controller != null)
                  WebViewWidget(controller: _controller!)
                else if (!_isInitialized)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
          if (_progress < 1 && _errorMessage == null && _isInitialized)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                backgroundColor: Colors.white12,
                color: Colors.amber,
                minHeight: 3,
              ),
            ),
          if (_errorMessage != null)
            Container(
              color: const Color(0xFF0F0F0F),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.amber, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load Paystack checkout.',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
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


