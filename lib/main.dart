import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'config/app_router.dart';
import 'providers/auth_provider.dart';
import 'services/token_manager.dart';
import 'services/firebase_service.dart';
import 'services/walletconnect_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Run app immediately, initialize services in background
  runApp(const MyApp());
  
  // Initialize services asynchronously after app starts
  _initializeServices();
}

Future<void> _initializeServices() async {
  // Initialize token manager
  try {
    await TokenManager().initialize();
  } catch (e) {
    debugPrint('⚠️ TokenManager init failed: $e');
  }
  
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
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _router = createRouter(_authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
      ],
      child: MaterialApp.router(
        title: 'Tajify',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'),
        ],
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
        routerConfig: _router,
      ),
    );
  }
}
