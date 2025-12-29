import 'dart:async';
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
    try {
      // Load stored tokens and restore auth state with timeout
      debugPrint('🔄 Loading stored tokens...');
      await ref
          .read(authControllerProvider.notifier)
          .loadStoredTokens()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠️ Token loading timed out, continuing anyway');
            },
          );
      debugPrint('✅ Token loading completed');
    } catch (e) {
      debugPrint('❌ Error loading tokens: $e');
      // Continue anyway - WebView will handle authentication
    }

    // Wait minimum splash time (1 second)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Always navigate to WebViewScreen, even if initialization failed
    // WebViewScreen will handle showing the appropriate page
    try {
      final authState = ref.read(authControllerProvider);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WebViewScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ Error reading auth state: $e');
      // Navigate anyway - WebView will show login page
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WebViewScreen()),
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
              errorBuilder: (context, error, stackTrace) {
                // If image fails to load, show a placeholder
                debugPrint('⚠️ Error loading logo: $error');
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.shopping_bag,
                    size: 100,
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // App Name
            Text(
              'Basood Post',
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
