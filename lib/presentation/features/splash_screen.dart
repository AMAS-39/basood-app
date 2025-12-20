import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'auth/auth_controller.dart';
import 'webview_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Use Future.microtask to defer provider state modification until after build completes
    // This prevents Riverpod error: "Tried to modify a provider while the widget tree was building"
    Future.microtask(() {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Load stored tokens and restore auth state
    await ref.read(authControllerProvider.notifier).loadStoredTokens();
    
    // Wait minimum splash time (1 second)
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;
    
    // Check auth state and navigate accordingly
    final authState = ref.read(authControllerProvider);
    
    if (authState.isInitialized) {
      // Navigate to WebViewScreen (it will handle showing login page if not authenticated)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const WebViewScreen(),
          ),
        );
      }
    } else {
      // Still loading, wait a bit more
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const WebViewScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 68, 105),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon
            Image.asset(
              'assets/image/logo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30),
            // App Name
            Text(
              'Basood',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            // Loading Indicator
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}