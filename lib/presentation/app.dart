import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'theme/app_theme.dart';
import 'features/splash_screen.dart';
import '../services/notification_service.dart';
import 'providers/di_providers.dart';

// Global navigator key for notification handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SupplyGoApp extends ConsumerStatefulWidget {
  const SupplyGoApp({super.key});

  @override
  ConsumerState<SupplyGoApp> createState() => _SupplyGoAppState();
}

class _SupplyGoAppState extends ConsumerState<SupplyGoApp> {
  bool _firebaseInitialized = false;
  
  @override
  void initState() {
    super.initState();
    
    // Configure status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    // Set navigator key for notification service
    NotificationService.navigatorKey = navigatorKey;
  }

  @override
  Widget build(BuildContext context) {
    // Initialize Firebase with Dio for sending FCM tokens (ref is available in build)
    if (!_firebaseInitialized) {
      _firebaseInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.microtask(() async {
          try {
            final dio = ref.read(dioProvider);
          } catch (e) {
            debugPrint('⚠️ Error initializing Firebase service: $e');
          }
        });
      });
    }
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Basood',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
