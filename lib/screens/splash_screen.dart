import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  
  String _displayText = '';
  String _fullText = 'Tajify';
  int _textIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Logo zoom-in animation
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    // Text fade-in animation
    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _logoController.forward();
    
    // Start typewriter effect after logo animation
    Timer(const Duration(milliseconds: 800), () {
      _startTypewriter();
    });
    
    // Start text fade-in after typewriter
    Timer(const Duration(milliseconds: 2800), () {
      _textController.forward();
    });
    
    // Navigate after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _checkNavigation();
      }
    });
  }

  Future<void> _checkNavigation() async {
    try {
      // Ensure Flutter bindings are initialized
      WidgetsFlutterBinding.ensureInitialized();
      
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      
      if (mounted) {
        if (!hasSeenOnboarding) {
          context.go('/onboarding');
        } else {
          // Check authentication status
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          
          // Wait for auth initialization to complete
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (mounted) {
            if (authProvider.isAuthenticated) {
              context.go('/home');
            } else {
              context.go('/login');
            }
          }
        }
      }
    } catch (e) {
      // If shared preferences fails, default to showing onboarding
      print('Navigation error: $e');
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  void _startTypewriter() {
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_textIndex < _fullText.length) {
        setState(() {
          _displayText += _fullText[_textIndex];
          _textIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            AnimatedBuilder(
              animation: _logoAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoAnimation.value,
                  child: Image.asset(
                    'assets/tajify_icon.png',
                    width: 120,
                    height: 120,
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // Typewriter text
            AnimatedBuilder(
              animation: _textAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _textAnimation.value,
                  child: Text(
                    _displayText,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: Colors.amber,
                          blurRadius: 15.0,
                          offset: Offset(0, 0),
                        ),
                        Shadow(
                          color: Colors.amber,
                          blurRadius: 25.0,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 