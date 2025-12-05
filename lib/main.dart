import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_router.dart';
import 'providers/auth_provider.dart';
import 'services/token_manager.dart';
import 'services/firebase_service.dart';
import 'services/walletconnect_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize token manager
  await TokenManager().initialize();
  
  // Initialize WalletConnect (non-blocking)
  try {
    await WalletConnectService.instance.initialize(
      projectId: '55c52f2768fcff072910c161f3bea96e',
      appName: 'Tajify',
      appUrl: 'https://tajify.com',
      appIcon: 'https://tajify.com/icon.png',
    );
  } catch (e) {
    debugPrint('⚠️ WalletConnect init failed: $e');
  }
  
  // Initialize Firebase (non-blocking - will fail gracefully if not configured)
  FirebaseService.initialize().then((success) {
    if (success) {
      FirebaseService.initializeAuth();
    }
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp.router(
        title: 'Tajify',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8C00)),
          useMaterial3: true,
          fontFamily: 'Ebrima',
          scaffoldBackgroundColor: const Color(0xFF1A1A1A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
          ),
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
