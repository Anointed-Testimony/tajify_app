import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/otp_verification_screen.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/connect_screen.dart';
import '../screens/channel_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    print('=== ROUTER DEBUG ===');
    print('Current location: ${state.matchedLocation}');
    print('Auth status: ${authProvider.status}');
    print('Is authenticated: ${authProvider.isAuthenticated}');
    print('User: ${authProvider.user?.name}');
    
    // If still initializing, stay on splash
    if (authProvider.status == AuthStatus.initial) {
      print('Still initializing, staying on current route');
      return null;
    }
    
    // If loading, stay on current route
    if (authProvider.status == AuthStatus.loading) {
      print('Loading, staying on current route');
      return null;
    }
    
    final isAuthenticated = authProvider.isAuthenticated;
    final isAuthRoute = state.matchedLocation == '/login' || 
                       state.matchedLocation == '/signup' || 
                       state.matchedLocation == '/forgot-password';
    
    print('Is auth route: $isAuthRoute');
    
    // If authenticated and trying to access auth routes, redirect to home
    if (isAuthenticated && isAuthRoute) {
      print('Authenticated user on auth route, redirecting to /home');
      return '/home';
    }
    
    // If not authenticated and trying to access protected routes, redirect to login
    if (!isAuthenticated && !isAuthRoute && state.matchedLocation != '/') {
      print('Not authenticated on protected route, redirecting to /login');
      return '/login';
    }
    
    print('No redirect needed');
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/otp-verification',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        return OtpVerificationScreen(
          email: args?['email'] ?? '',
          phone: args?['phone'],
          purpose: args?['purpose'] ?? 'registration',
          userId: args?['userId'],
        );
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
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
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Ebrima',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Email: ${args?['email'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  Text(
                    'Phone: ${args?['phone'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  Text(
                    'OTP: ${args?['otp'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Reset Password Screen - To be implemented',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/connect',
      builder: (context, state) => const ConnectScreen(),
    ),
    GoRoute(
      path: '/channel',
      builder: (context, state) => const ChannelScreen(),
    ),
  ],
); 