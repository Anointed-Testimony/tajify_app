import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  bool _isAutoScrolling = true;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: "Welcome to Tajify",
      description: "The unified digital ecosystem for African creators—artists, filmmakers, writers, musicians, designers, and influencers. Your journey to creative success starts here.",
      imagePath: "assets/creator_icon.svg",
    ),
    OnboardingStep(
      title: "Build & Monetize",
      description: "Create content, build your community, and unlock new revenue pathways through brand partnerships, tokenized incentives, and creator marketplace.",
      imagePath: "assets/earn_icon.svg",
    ),
    OnboardingStep(
      title: "Unified Platform",
      description: "Everything you need in one place—social networking, content channels, creator marketplace, and financial management tools.",
      imagePath: "assets/unified_icon.svg",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isAutoScrolling && _currentPage < _steps.length - 1) {
        _nextPage();
      } else if (_currentPage >= _steps.length - 1) {
        timer.cancel();
      }
    });
  }

  void _pauseAutoScroll() {
    setState(() {
      _isAutoScrolling = false;
    });
  }

  void _resumeAutoScroll() {
    setState(() {
      _isAutoScrolling = true;
    });
  }

  Future<void> _markOnboardingComplete() async {
    try {
      // Ensure Flutter bindings are initialized
      WidgetsFlutterBinding.ensureInitialized();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', true);
    } catch (e) {
      // If shared preferences fails, continue with navigation anyway
      print('Failed to save onboarding status: $e');
    }
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Mark onboarding as complete and navigate to login screen
      _markOnboardingComplete();
      context.go('/login');
    }
  }

  void _skipOnboarding() {
    // Mark onboarding as complete and navigate to login screen
    _markOnboardingComplete();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (_) => _pauseAutoScroll(),
          onTapUp: (_) => _resumeAutoScroll(),
          onTapCancel: () => _resumeAutoScroll(),
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextButton(
                    onPressed: _skipOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    return _buildOnboardingStep(_steps[index]);
                  },
                ),
              ),
              
              // Bottom section with dots and button
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    // Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _steps.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index 
                                ? Colors.amber 
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Next/Get Started button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          _pauseAutoScroll();
                          _nextPage();
                          _resumeAutoScroll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentPage == _steps.length - 1 
                              ? 'Get Started' 
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _buildOnboardingStep(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image container with gradient background
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF1A1A1A),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: step.imagePath.endsWith('.svg')
                  ? SvgPicture.asset(
                      step.imagePath,
                      width: 160,
                      height: 160,
                    )
                  : Image.asset(
                      step.imagePath,
                      width: 160,
                      height: 160,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.place,
                          size: 120,
                          color: Colors.amber.withOpacity(0.7),
                        );
                      },
                    ),
            ),
          ),
          
          const SizedBox(height: 50),
          
          // Title
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Description
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final String imagePath;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.imagePath,
  });
} 