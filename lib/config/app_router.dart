import 'package:go_router/go_router.dart';
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
import '../screens/earning_center_screen.dart';
import '../screens/blog_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/personal_profile_screen.dart';
import '../screens/public_profile_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/create_content_screen.dart';
import '../screens/tube_player_screen.dart';
import '../screens/shorts_player_screen.dart';
import '../screens/saved_posts_screen.dart';
import '../screens/market_screen.dart';
import '../screens/go_live_screen.dart';
import '../screens/live_viewer_screen.dart';
import '../screens/reset_password_screen.dart';

GoRouter createRouter(AuthProvider authProvider) => GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  refreshListenable: authProvider,
  redirect: (context, state) {
    // Define auth routes that should always be accessible
    final isAuthRoute = state.matchedLocation == '/login' || 
                       state.matchedLocation == '/signup' || 
                       state.matchedLocation == '/forgot-password' ||
                       state.matchedLocation == '/otp-verification' ||
                       state.matchedLocation == '/reset-password';
    
    // Allow splash and onboarding to load without auth check
    if (state.matchedLocation == '/' || state.matchedLocation == '/onboarding') {
      return null;
    }
    
    // Always allow auth routes to be accessible (including when there's an error)
    if (isAuthRoute) {
      // Only redirect away from auth routes if user is authenticated
      if (authProvider.isAuthenticated) {
        return '/home';
      }
      // Otherwise, stay on the auth route (even if there's an error)
      return null;
    }
    
    // If still initializing or loading, redirect protected routes to splash
    if (authProvider.status == AuthStatus.initial || authProvider.status == AuthStatus.loading) {
      if (state.matchedLocation != '/') {
        return '/';
      }
      return null;
    }
    
    // If not authenticated and trying to access protected routes, redirect to login
    if (!authProvider.isAuthenticated && state.matchedLocation != '/') {
      return '/login';
    }
    
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
        return ResetPasswordScreen(
          email: args?['email'],
          phone: args?['phone'],
          otp: args?['otp'],
          userId: args?['userId'],
          type: args?['type'],
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
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        return ChannelScreen(
          openCreateModalOnStart: args?['openCreateModalOnStart'] == true,
          initialCategory: args?['initialCategory'] as String?,
          initialAudioTrack: args?['initialAudioTrack'] as Map<String, dynamic>?,
        );
      },
    ),
    GoRoute(
      path: '/earn',
      builder: (context, state) => const EarningCenterScreen(),
    ),
    GoRoute(
      path: '/market',
      builder: (context, state) => const MarketScreen(),
    ),
    GoRoute(
      path: '/blog/:uuid',
      builder: (context, state) {
        final uuid = state.pathParameters['uuid'] ?? '';
        return BlogDetailScreen(blogUuid: uuid);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => const MessagesScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const PersonalProfileScreen(),
    ),
    GoRoute(
      path: '/go-live',
      builder: (context, state) => const GoLiveScreen(),
    ),
    GoRoute(
      path: '/live/:channelName',
      builder: (context, state) {
        final channelName = state.pathParameters['channelName'] ?? '';
        final args = state.extra as Map<String, dynamic>?;
        return LiveViewerScreen(
          channelName: channelName,
          sessionData: args?['sessionData'],
        );
      },
    ),
    GoRoute(
      path: '/user/:username',
      builder: (context, state) {
        final username = state.pathParameters['username'] ?? '';
        return PublicProfileScreen(username: username);
      },
    ),
    GoRoute(
      path: '/community/:uuid',
      builder: (context, state) {
        final uuid = state.pathParameters['uuid'] ?? '';
        return CommunityDetailScreen(communityUuid: uuid);
      },
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        return CreateContentScreen(initialCategory: args?['type']);
      },
    ),
    GoRoute(
      path: '/tube-player',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        if (args == null || args['videos'] == null || args['initialIndex'] == null) {
          // Fallback to home if invalid args
          return const HomeScreen();
        }
        final loadMoreVideos = args['loadMoreVideos'];
        return TubePlayerScreen(
          videos: args['videos'] as List<Map<String, dynamic>>,
          initialIndex: args['initialIndex'] as int,
          loadMoreVideos: loadMoreVideos != null 
              ? loadMoreVideos as Future<List<Map<String, dynamic>>> Function(int)
              : null,
        );
      },
    ),
    GoRoute(
      path: '/shorts-player',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        if (args == null || args['videos'] == null || args['initialIndex'] == null) {
          // Fallback to home if invalid args
          return const HomeScreen();
        }
        return ShortsPlayerScreen(
          videos: args['videos'] as List<Map<String, dynamic>>,
          initialIndex: args['initialIndex'] as int,
        );
      },
    ),
    GoRoute(
      path: '/saved-posts',
      builder: (context, state) => const SavedPostsScreen(),
    ),
  ],
); 