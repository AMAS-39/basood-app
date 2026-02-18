import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/config/env.dart';
import 'auth/auth_controller.dart';
import '../../services/notification_service.dart';
import '../../services/firebase_service.dart';
import '../../core/utils/jwt_utils.dart';
import '../providers/di_providers.dart';

class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({super.key});

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen>
    with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  final _storage = const FlutterSecureStorage();
  PullToRefreshController? _pullToRefreshController;

  String? _initialUrl;
  String? _currentUrl;
  bool _isLoggingOut = false; // Flag to prevent logout loops
  bool _isBootstrapping =
      true; // Flag to prevent WebView from loading before URL decision
  bool _hasToken = false; // Track if we have a valid token

  @override
  void initState() {
    super.initState();
    // Register lifecycle observer to handle app resume
    WidgetsBinding.instance.addObserver(this);

    // Initialize pull-to-refresh controller
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(enabled: true),
      onRefresh: () async {
        if (_webViewController != null) {
          await _webViewController!.reload();
        }
      },
    );

    // Register callback for notification taps to refresh WebView
    NotificationService.setNotificationTapCallback(() {
      if (mounted && _webViewController != null) {
        _webViewController!.reload();
      }
    });

    // CRITICAL: Determine initial URL BEFORE WebView builds
    // This prevents the /login flash for authenticated users
    _bootstrapInitialUrl();
  }

  /// Bootstrap: Read token and determine initial URL before WebView loads
  Future<void> _bootstrapInitialUrl() async {
    try {
      debugPrint('🔍 Bootstrapping: Checking for stored token...');

      // Read access token from secure storage
      final accessToken = await _storage
          .read(key: 'access_token')
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('⚠️ Token read timed out, using login URL');
              return null;
            },
          );

      if (accessToken != null && accessToken.isNotEmpty) {
        // Optional: Check if token is expired
        final isExpired = JwtUtils.isTokenExpired(accessToken);

        if (isExpired) {
          debugPrint(
            '⚠️ Stored token is expired, clearing and using login URL',
          );
          // Clear expired token
          await _storage.delete(key: 'access_token');
          await _storage.delete(key: 'refresh_token');
          ref.read(accessTokenProvider.notifier).state = null;
          ref.read(refreshTokenProvider.notifier).state = null;

          _initialUrl = '${Env.webBaseUrl}/login';
          _hasToken = false;
        } else {
          debugPrint(
            '✅ Valid token found, initializing with authenticated URL',
          );
          // Token exists and is valid → go to home, not login
          _initialUrl = '${Env.webBaseUrl}/';
          _hasToken = true;

          // Update provider state
          ref.read(accessTokenProvider.notifier).state = accessToken;

          // Also restore refresh token if available
          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken != null && refreshToken.isNotEmpty) {
            ref.read(refreshTokenProvider.notifier).state = refreshToken;
          }
        }
      } else {
        debugPrint('ℹ️ No token found, using login URL');
        _initialUrl = '${Env.webBaseUrl}/login';
        _hasToken = false;
      }

      // Ensure URL is never null
      _initialUrl ??= '${Env.webBaseUrl}/login';
      debugPrint('🌐 Bootstrap complete: Initial URL = $_initialUrl');

      // Bootstrap complete - allow WebView to render
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }

      // Request permissions (non-blocking)
      _requestPermissions();
    } catch (e) {
      debugPrint('❌ Error during bootstrap: $e');
      // Fallback to login on error
      _initialUrl = '${Env.webBaseUrl}/login';
      _hasToken = false;

      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    // Clear notification callback when screen is disposed
    NotificationService.setNotificationTapCallback(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes, re-inject token to restore session (only if token exists)
    if (state == AppLifecycleState.resumed &&
        _webViewController != null &&
        _hasToken) {
      debugPrint('🔄 App resumed, re-injecting token...');
      _injectTokenIfAny(_webViewController!);
    }
  }

  // Removed _requestPermissionsAndInitialize - bootstrap handles URL now

  Future<void> _requestPermissions() async {
    if (!mounted) return;

    try {
      // Check camera and microphone permissions separately and clearly
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;

      bool shouldShowDialog = false;

      // Check camera permission - handle all states properly for WebRTC
      if (cameraStatus.isPermanentlyDenied) {
        debugPrint('⚠️ Camera permission permanently denied');
        shouldShowDialog = true;
      } else if (cameraStatus.isRestricted) {
        debugPrint('⚠️ Camera permission restricted (Screen Time/MDM)');
        shouldShowDialog = true;
      } else if (cameraStatus.isLimited) {
        // Limited permissions may not work for WebRTC - treat as denied
        debugPrint('⚠️ Camera permission limited - requesting full access');
        final result = await Permission.camera.request();
        debugPrint('Camera permission requested: $result');
      } else if (cameraStatus.isDenied) {
        // Request permission if just denied (not permanent)
        final result = await Permission.camera.request();
        debugPrint('Camera permission requested: $result');
      } else {
        debugPrint('Camera permission already granted: $cameraStatus');
      }

      // Check microphone permission - handle all states properly for WebRTC
      if (micStatus.isPermanentlyDenied) {
        debugPrint('⚠️ Microphone permission permanently denied');
        shouldShowDialog = true;
      } else if (micStatus.isRestricted) {
        debugPrint('⚠️ Microphone permission restricted (Screen Time/MDM)');
        shouldShowDialog = true;
      } else if (micStatus.isLimited) {
        // Limited permissions may not work for WebRTC - treat as denied
        debugPrint('⚠️ Microphone permission limited - requesting full access');
        final result = await Permission.microphone.request();
        debugPrint('Microphone permission requested: $result');
      } else if (micStatus.isDenied) {
        // Request permission if just denied (not permanent)
        final result = await Permission.microphone.request();
        debugPrint('Microphone permission requested: $result');
      } else {
        debugPrint('Microphone permission already granted: $micStatus');
      }

      // Show dialog if any permission is permanently denied (iOS-safe UX)
      if (shouldShowDialog && mounted) {
        _showPermissionDialog();
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      // Continue anyway - WebView will handle permission requests natively
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'Camera and microphone access are required for this feature. '
          'Please enable them in Settings. If restricted by Screen Time or MDM, contact your administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Removed _initializeUrl - bootstrap handles this now

  Future<void> _injectLogoutListener(InAppWebViewController controller) async {
    // Inject JavaScript to listen for logout button clicks ONLY
    // DO NOT automatically detect /login URL - that causes infinite loops
    await controller.evaluateJavascript(
      source: '''
      (function() {
        // Only listen for logout button clicks - don't auto-detect /login URL
        document.addEventListener('click', function(e) {
          var target = e.target;
          // Check if clicked element or parent contains logout text
          while (target) {
            var text = target.textContent || target.innerText || '';
            var href = target.href || '';
            var className = target.className || '';
            
            if (text.toLowerCase().includes('logout') || 
                text.toLowerCase().includes('خروج') ||
                href.toLowerCase().includes('logout') ||
                className.toLowerCase().includes('logout')) {
              // Notify Flutter app only when user clicks logout button
              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                window.flutter_inappwebview.callHandler('logout');
              }
              break;
            }
            target = target.parentElement;
          }
        });
      })();
    ''',
    );
  }

  Future<void> _hideBugButton(InAppWebViewController controller) async {
    // Inject JavaScript to hide bug/feedback buttons
    await controller.evaluateJavascript(
      source: '''
      (function() {
        // Function to hide bug button by various selectors
        function hideBugButton() {
          // Common selectors for bug/feedback buttons
          var selectors = [
            '[class*="bug"]',
            '[id*="bug"]',
            '[class*="feedback"]',
            '[id*="feedback"]',
            '[class*="report"]',
            '[id*="report"]',
            '[class*="error"]',
            '[id*="error"]',
            'button[aria-label*="bug"]',
            'button[aria-label*="feedback"]',
            'button[aria-label*="report"]',
            'a[href*="bug"]',
            'a[href*="feedback"]',
            'a[href*="report"]'
          ];
          
          selectors.forEach(function(selector) {
            try {
              var elements = document.querySelectorAll(selector);
              elements.forEach(function(el) {
                var text = (el.textContent || el.innerText || '').toLowerCase();
                // Check if element text contains bug-related keywords
                if (text.includes('bug') || 
                    text.includes('feedback') || 
                    text.includes('report') ||
                    text.includes('error')) {
                  el.style.display = 'none';
                  el.style.visibility = 'hidden';
                  el.style.opacity = '0';
                  el.style.pointerEvents = 'none';
                }
              });
            } catch (e) {}
          });
          
          // Also check for floating action buttons or fixed position elements
          var allButtons = document.querySelectorAll('button, a, div[role="button"]');
          allButtons.forEach(function(btn) {
            var text = (btn.textContent || btn.innerText || '').toLowerCase();
            var className = (btn.className || '').toLowerCase();
            var id = (btn.id || '').toLowerCase();
            
            if ((text.includes('bug') || text.includes('feedback') || text.includes('report')) ||
                (className.includes('bug') || className.includes('feedback')) ||
                (id.includes('bug') || id.includes('feedback'))) {
              var style = window.getComputedStyle(btn);
              // Check if it's a floating/fixed button
              if (style.position === 'fixed' || style.position === 'absolute') {
                btn.style.display = 'none';
                btn.style.visibility = 'hidden';
                btn.style.opacity = '0';
                btn.style.pointerEvents = 'none';
              }
            }
          });
        }
        
        // Hide immediately
        hideBugButton();
        
        // Also hide after a short delay (in case button is added dynamically)
        setTimeout(hideBugButton, 500);
        setTimeout(hideBugButton, 1000);
        setTimeout(hideBugButton, 2000);
        
        // Use MutationObserver to hide button if it appears later
        var observer = new MutationObserver(function(mutations) {
          hideBugButton();
        });
        
        observer.observe(document.body, {
          childList: true,
          subtree: true,
          attributes: true
        });
      })();
    ''',
    );
  }

  Future<void> _injectLoginSyncListener(
    InAppWebViewController controller,
  ) async {
    // Inject JavaScript to detect login and sync tokens (iOS + Android)
    // Syncs only when token changes - avoids excessive polling that breaks iOS
    await controller.evaluateJavascript(
      source: '''
      (function() {
        var lastSyncedToken = null;

        function getCookie(name) {
          var value = "; " + document.cookie;
          var parts = value.split("; " + name + "=");
          if (parts.length == 2) return parts.pop().split(";").shift();
          return null;
        }

        function getFromLocalStorage(key) {
          try {
            return localStorage.getItem(key);
          } catch (e) {
            return null;
          }
        }

        function syncTokensToFlutter() {
          if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) return;

          var accessToken = getCookie('access_token') ||
            getCookie('accessToken') ||
            getCookie('token') ||
            getFromLocalStorage('access_token') ||
            getFromLocalStorage('accessToken') ||
            getFromLocalStorage('token');

          if (!accessToken) {
            try {
              var authHeader = getFromLocalStorage('Authorization');
              if (authHeader && authHeader.startsWith('Bearer ')) {
                accessToken = authHeader.substring(7);
              }
            } catch (e) {}
          }

          if (!accessToken || accessToken === lastSyncedToken) return;

          var refreshToken = getCookie('refresh_token') ||
            getCookie('refreshToken') ||
            getFromLocalStorage('refresh_token') ||
            getFromLocalStorage('refreshToken');

          lastSyncedToken = accessToken;
          window.flutter_inappwebview.callHandler('syncTokens', {
            accessToken: accessToken,
            refreshToken: refreshToken || ''
          });
        }

        var lastUrl = window.location.href;
        setInterval(function() {
          var currentUrl = window.location.href;
          if (lastUrl.includes('/login') && !currentUrl.includes('/login')) {
            lastSyncedToken = null;
            setTimeout(syncTokensToFlutter, 1000);
          } else if (!currentUrl.includes('/login')) {
            syncTokensToFlutter();
          }
          lastUrl = currentUrl;
        }, 10000);

        if (!window.location.href.includes('/login')) {
          setTimeout(syncTokensToFlutter, 2000);
        }
      })();
    ''',
    );
  }

  void _handleLogout() {
    // Prevent multiple logout calls
    if (_isLoggingOut) return;

    // Defer provider state modification to prevent Riverpod errors
    Future.microtask(() {
      if (!mounted || _isLoggingOut) return;

      final currentUrl = _currentUrl ?? '';
      final isAlreadyOnLogin = currentUrl.contains('/login');

      // Update token flag
      _hasToken = false;

      // Only reload if we're not already on login page
      if (!isAlreadyOnLogin) {
        _isLoggingOut = true;

        // Call logout from auth controller
        ref.read(authControllerProvider.notifier).logout();

        // Reload webview to show login page
        _webViewController?.loadUrl(
          urlRequest: URLRequest(
            url: WebUri(
              '${Env.webBaseUrl}/login',
            ),
          ),
        );

        // Reset flag after a delay
        Future.delayed(const Duration(seconds: 2), () {
          _isLoggingOut = false;
        });
      } else {
        // Already on login page, just clear auth state
        ref.read(authControllerProvider.notifier).logout();
      }
    });
  }

  void _handleTokenSync(List<dynamic> args) {
    // Handle token sync from WebView login
    if (args.isEmpty) return;

    try {
      final data = args[0] as Map<String, dynamic>?;
      if (data == null) return;

      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;

      if (accessToken == null || accessToken.isEmpty) return;

      // Defer to avoid Riverpod errors
      Future.microtask(() async {
        if (!mounted) return;

        try {
          debugPrint('🔄 Syncing tokens from WebView login...');

          // Trust backend/frontend - they will handle token expiration
          // Store tokens in secure storage FIRST to ensure persistence
          await _storage.write(key: 'access_token', value: accessToken);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await _storage.write(key: 'refresh_token', value: refreshToken);
          }

          debugPrint('✅ Tokens saved to secure storage');

          // Update provider state AFTER saving to storage
          ref
              .read(authControllerProvider.notifier)
              .syncTokensFromWebView(
                accessToken: accessToken,
                refreshToken: refreshToken,
              );

          debugPrint('✅ Tokens synced to provider state');

          debugPrint('✅ Tokens synced successfully from WebView');
        } catch (e) {
          debugPrint('❌ Error syncing tokens: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ Error handling token sync: $e');
    }
  }

  Future<void> _checkCookiesForTokens(InAppWebViewController controller) async {
    // Backup method: Check cookies directly from Flutter side
    try {
      final cookieManager = CookieManager.instance();
      final url = WebUri(Env.webBaseUrl);

      // Get all cookies for the domain
      final cookies = await cookieManager.getCookies(url: url);

      String? accessToken;
      String? refreshToken;

      // Look for common token cookie names
      for (final cookie in cookies) {
        final name = cookie.name.toLowerCase();
        final value = cookie.value;

        if (name.contains('access') && name.contains('token')) {
          accessToken = value;
        } else if (name.contains('refresh') && name.contains('token')) {
          refreshToken = value;
        } else if (name == 'token' && accessToken == null) {
          accessToken = value;
        }
      }

      // If we found tokens in cookies, sync them
      if (accessToken != null && accessToken.isNotEmpty) {
        // Check if we already have this token stored (trust backend/frontend for expiration)
        final storedToken = await _storage.read(key: 'access_token');
        if (storedToken != accessToken) {
          debugPrint('🔄 Found tokens in cookies, syncing...');
          await _storage.write(key: 'access_token', value: accessToken);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await _storage.write(key: 'refresh_token', value: refreshToken);
          }

          // Update provider state
          ref
              .read(authControllerProvider.notifier)
              .syncTokensFromWebView(
                accessToken: accessToken,
                refreshToken: refreshToken,
              );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking cookies: $e');
      // Don't throw - this is a backup method
    }
  }

  /// Handle messages from web app via NativeAndroidBridge.postMessage()
  ///
  /// MANDATORY FOR WEB TEAM: The web app MUST send auth tokens using this format:
  ///
  /// ```javascript
  /// NativeAndroidBridge.postMessage(JSON.stringify({
  ///   command: "saveToken",
  ///   tokenType: "auth",
  ///   accessToken: "<JWT_TOKEN>",
  ///   refreshToken: "<REFRESH_TOKEN>" // Optional
  /// }));
  /// ```
  ///
  /// Expected formats:
  /// - Auth token (MANDATORY for stay logged in):
  ///   { "command": "saveToken", "tokenType": "auth", "accessToken": "...", "refreshToken": "..." }
  /// - FCM token:
  ///   { "command": "saveToken", "tokenType": "fcm", "token": "..." }
  /// - Logout:
  ///   { "command": "clearToken" }
  ///
  /// See WEB_INTEGRATION_GUIDE.md for complete integration instructions.
  Future<void> _handleWebMessage(String message) async {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      final String command = data['command'] as String? ?? '';

      debugPrint(
        '📨 Flutter received web message: command=$command, data=${data.keys}',
      );

      if (command == 'saveToken') {
        // Use explicit tokenType field to avoid ambiguity
        final String? tokenType = data['tokenType'] as String?;

        if (tokenType == 'auth') {
          // This is an authentication token from web login
          final String? accessToken =
              data['accessToken'] as String? ?? data['token'] as String?;

          if (accessToken != null && accessToken.isNotEmpty) {
            debugPrint(
              '💾 Saving auth token from web: ${accessToken.substring(0, 20)}...',
            );

            // Save auth token to secure storage
            await _storage.write(key: 'access_token', value: accessToken);

            // Update provider state
            ref.read(accessTokenProvider.notifier).state = accessToken;

            // Sync refresh token if provided
            final String? refreshToken = data['refreshToken'] as String?;
            if (refreshToken != null && refreshToken.isNotEmpty) {
              await _storage.write(key: 'refresh_token', value: refreshToken);
              ref.read(refreshTokenProvider.notifier).state = refreshToken;
            }

            // Update token flag
            _hasToken = true;

            debugPrint('✅ Auth token saved successfully');
          } else {
            debugPrint(
              '⚠️ saveToken (auth) received but accessToken is null or empty',
            );
          }
        } else if (tokenType == 'fcm') {
          // This is an FCM/push notification token
          final String? token = data['token'] as String?;

          if (token != null && token.isNotEmpty) {
            debugPrint('💾 Saving FCM token from web: $token');

            // Save token to NotificationService
            await NotificationService.instance.saveFcmToken(token);

            // Send token to backend
            try {
              final dio = ref.read(dioProvider);
              FirebaseService.initialize(dio: dio);
              await FirebaseService.sendTokenToBackend(token);
              debugPrint('✅ FCM token sent to backend successfully');
            } catch (e) {
              debugPrint('⚠️ Error sending FCM token to backend: $e');
            }
          } else {
            debugPrint(
              '⚠️ saveToken (fcm) received but token is null or empty',
            );
          }
        } else {
          // Fallback: if no tokenType specified, try to detect
          // This maintains backward compatibility
          final String? token = data['token'] as String?;
          if (token != null && token.isNotEmpty) {
            // Check if this looks like a JWT (has 3 parts separated by dots)
            final isAuthToken =
                token.contains('.') && token.split('.').length == 3;

            if (isAuthToken) {
              debugPrint(
                '💾 Saving auth token (auto-detected JWT): ${token.substring(0, 20)}...',
              );
              await _storage.write(key: 'access_token', value: token);
              ref.read(accessTokenProvider.notifier).state = token;

              final String? refreshToken = data['refreshToken'] as String?;
              if (refreshToken != null && refreshToken.isNotEmpty) {
                await _storage.write(key: 'refresh_token', value: refreshToken);
                ref.read(refreshTokenProvider.notifier).state = refreshToken;
              }
            } else {
              debugPrint('💾 Saving FCM token (auto-detected): $token');
              await NotificationService.instance.saveFcmToken(token);
              try {
                final dio = ref.read(dioProvider);
                FirebaseService.initialize(dio: dio);
                await FirebaseService.sendTokenToBackend(token);
              } catch (e) {
                debugPrint('⚠️ Error sending FCM token: $e');
              }
            }
          }
        }
      } else if (command == 'clearToken') {
        debugPrint('🗑️ Clearing tokens and session');
        // Clear auth tokens
        await _storage.delete(key: 'access_token');
        await _storage.delete(key: 'refresh_token');
        ref.read(accessTokenProvider.notifier).state = null;
        ref.read(refreshTokenProvider.notifier).state = null;

        // Update token flag
        _hasToken = false;

        // Clear FCM token from NotificationService
        await NotificationService.instance.saveFcmToken('');

        // Clear auth state
        ref.read(authControllerProvider.notifier).logout();
      } else {
        debugPrint('⚠️ Unknown command received: $command');
      }
    } catch (e) {
      debugPrint('❌ Error parsing web message: $e');
    }
  }

  /// Inject JavaScript to create NativeAndroidBridge.postMessage API
  ///
  /// WEB TEAM: Use this API to send auth tokens after login:
  ///
  /// NativeAndroidBridge.postMessage(JSON.stringify({
  ///   command: "saveToken",
  ///   tokenType: "auth",
  ///   accessToken: "<JWT>",
  ///   refreshToken: "<REFRESH>" // Optional
  /// }));
  ///
  /// See WEB_INTEGRATION_GUIDE.md for complete documentation.
  Future<void> _injectNativeAndroidBridge(
    InAppWebViewController controller,
  ) async {
    await controller.evaluateJavascript(
      source: '''
      (function() {
        if (window.NativeAndroidBridge) {
          return; // Already exists
        }
        
        window.NativeAndroidBridge = {
          postMessage: function(message) {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('NativeAndroidBridge', message);
            } else {
              console.warn('NativeAndroidBridge: Flutter handler not available');
            }
          }
        };
        
        console.log('NativeAndroidBridge.postMessage API initialized');
        console.log('WEB TEAM: Send auth tokens after login using:');
        console.log('NativeAndroidBridge.postMessage(JSON.stringify({command:"saveToken",tokenType:"auth",accessToken:"<JWT>",refreshToken:"<REFRESH>"}));');
      })();
      ''',
    );
  }

  /// Debug method to check what auth state exists in WebView
  /// This helps identify what storage mechanism the web app actually uses
  Future<void> _debugAuthState(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(
        source: '''
        (function() {
          const ls = {
            access_token: localStorage.getItem('access_token'),
            token: localStorage.getItem('token'),
            auth_token: localStorage.getItem('auth_token'),
            accessToken: localStorage.getItem('accessToken'),
            Authorization: localStorage.getItem('Authorization'),
          };
          const ss = {
            access_token: sessionStorage.getItem('access_token'),
            token: sessionStorage.getItem('token'),
            auth_token: sessionStorage.getItem('auth_token'),
            accessToken: sessionStorage.getItem('accessToken'),
          };
          return JSON.stringify({
            href: location.href,
            path: location.pathname,
            hostname: location.hostname,
            localStorage: ls,
            sessionStorage: ss,
            cookies: document.cookie
          });
        })();
        ''',
      );
      debugPrint('🔎 Web auth debug: $result');
    } catch (e) {
      debugPrint('⚠️ Error debugging auth state: $e');
    }
  }

  /// Inject stored authentication token into WebView localStorage/cookies
  /// This allows the web app to auto-authenticate without requiring login
  Future<void> _injectTokenIfAny(InAppWebViewController controller) async {
    try {
      // Read stored access token
      final accessToken = await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('🔑 No stored token found, skipping injection');
        // Still debug to see what's in storage
        await _debugAuthState(controller);
        return;
      }

      debugPrint('🔑 Injecting stored token into WebView...');

      // Get current URL to determine correct domain
      final currentUrl = await controller.getUrl();
      final domain =
          currentUrl?.host ?? Uri.parse(Env.webBaseUrl).host;
      debugPrint('🌐 Using domain: $domain');

      // Method 1: Set cookies via CookieManager (more reliable for cookie-based auth)
      try {
        final cookieManager = CookieManager.instance();
        final cookieUrl = WebUri('https://$domain');

        // Set cookies with common names - use exact domain from current URL
        final cookieNames = [
          'access_token',
          'accessToken',
          'token',
          'auth_token',
        ];
        for (final cookieName in cookieNames) {
          await cookieManager.setCookie(
            url: cookieUrl,
            name: cookieName,
            value: accessToken,
            domain: domain,
            path: '/',
            isSecure: true,
            isHttpOnly: false,
            sameSite: HTTPCookieSameSitePolicy.NONE,
          );
        }
        debugPrint('✅ Token set as cookies via CookieManager');
      } catch (e) {
        debugPrint('⚠️ Error setting cookies via CookieManager: $e');
      }

      // Method 2: Inject token into localStorage and sessionStorage via JavaScript
      // NOTE: We inject into both localStorage AND sessionStorage because many SPAs use sessionStorage
      await controller.evaluateJavascript(
        source:
            '''
        (function() {
          try {
            var token = ${jsonEncode(accessToken)};
            var domain = window.location.hostname;
            
            // Inject into localStorage (try common keys)
            localStorage.setItem('access_token', token);
            localStorage.setItem('accessToken', token);
            localStorage.setItem('token', token);
            localStorage.setItem('auth_token', token);
            localStorage.setItem('Authorization', 'Bearer ' + token);
            
            // ALSO inject into sessionStorage (many SPAs use this)
            sessionStorage.setItem('access_token', token);
            sessionStorage.setItem('accessToken', token);
            sessionStorage.setItem('token', token);
            sessionStorage.setItem('auth_token', token);
            
            // Set cookie via JavaScript as backup
            var expires = new Date();
            expires.setTime(expires.getTime() + (365 * 24 * 60 * 60 * 1000)); // 1 year
            
            // Try common cookie names with proper SameSite and Secure flags
            document.cookie = 'access_token=' + token + '; expires=' + expires.toUTCString() + '; path=/; domain=' + domain + '; SameSite=None; Secure';
            document.cookie = 'accessToken=' + token + '; expires=' + expires.toUTCString() + '; path=/; domain=' + domain + '; SameSite=None; Secure';
            document.cookie = 'token=' + token + '; expires=' + expires.toUTCString() + '; path=/; domain=' + domain + '; SameSite=None; Secure';
            document.cookie = 'auth_token=' + token + '; expires=' + expires.toUTCString() + '; path=/; domain=' + domain + '; SameSite=None; Secure';
            
            console.log('✅ Token injected into localStorage, sessionStorage, and cookies');
            
            // Trigger auth rehydrate events (many SPAs listen for these)
            window.dispatchEvent(new Event('storage'));
            window.dispatchEvent(new Event('auth:updated'));
            document.dispatchEvent(new Event('auth:updated'));
            
            // If web app has known auth restore functions, try calling them
            if (window.setAuthToken && typeof window.setAuthToken === 'function') {
              window.setAuthToken(token);
            }
            if (window.__APP__ && window.__APP__.auth && typeof window.__APP__.auth.restore === 'function') {
              window.__APP__.auth.restore(token);
            }
            
            // If we're on login page, redirect to home to trigger auto-auth
            if (window.location.pathname.includes('/login')) {
              setTimeout(function() {
                window.location.href = '/';
              }, 500);
            }
          } catch (e) {
            console.error('❌ Error injecting token: ' + e);
          }
        })();
        ''',
      );

      debugPrint('✅ Token injected successfully via JavaScript');

      // Debug after injection to verify it worked
      await Future.delayed(const Duration(milliseconds: 300));
      await _debugAuthState(controller);
    } catch (e) {
      debugPrint('❌ Error injecting token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_webViewController != null) {
            final canGoBack = await _webViewController!.canGoBack();
            if (canGoBack) {
              _webViewController!.goBack();
            } else {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          } else {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          top: true,
          bottom: true,
          child: Stack(
            children: [
              // Show loading screen while bootstrapping (checking token)
              if (_isBootstrapping)
                Container(
                  color: Colors.white,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading...',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              // WebView - only render after bootstrap completes
              if (!_isBootstrapping)
                Positioned.fill(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(
                        _initialUrl ??
                            '${Env.webBaseUrl}/login',
                      ),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      iframeAllow: "camera; microphone",
                      iframeAllowFullscreen: true,
                      // useHybridComposition is Android-only, remove for iOS compatibility
                      // useHybridComposition: true,
                      safeBrowsingEnabled: true,
                      domStorageEnabled: true,
                      // Camera and media access settings
                      thirdPartyCookiesEnabled: true,
                      // Respect system UI insets (status bar, navigation bar)
                      useShouldOverrideUrlLoading: true,
                      verticalScrollBarEnabled: true,
                      horizontalScrollBarEnabled: true,
                      // iOS-specific settings
                      allowsBackForwardNavigationGestures: true,
                      allowsLinkPreview: false,
                      isFraudulentWebsiteWarningEnabled: false,
                      // Ensure WebView can load content
                      cacheEnabled: true,
                      clearCache: false,
                    ),
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final url = navigationAction.request.url.toString();
                      debugPrint('🔗 Navigation request: $url');

                      // CRITICAL: Prevent navigation to /login if user has a valid token
                      if (url.contains('/login') && _hasToken) {
                        debugPrint(
                          '🚫 Blocked navigation to /login (user has valid token)',
                        );
                        // Cancel navigation and redirect to home
                        Future.microtask(() async {
                          await controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri(
                                '${Env.webBaseUrl}/',
                              ),
                            ),
                          );
                        });
                        return NavigationActionPolicy.CANCEL;
                      }

                      // Allow all other navigation
                      return NavigationActionPolicy.ALLOW;
                    },
                    pullToRefreshController: _pullToRefreshController,
                    onWebViewCreated: (controller) async {
                      debugPrint('✅ WebView created successfully');
                      _webViewController = controller;

                      // Add JavaScript handler for logout
                      controller.addJavaScriptHandler(
                        handlerName: 'logout',
                        callback: (args) {
                          _handleLogout();
                        },
                      );
                      // Add JavaScript handler to sync tokens from WebView login
                      controller.addJavaScriptHandler(
                        handlerName: 'syncTokens',
                        callback: (args) {
                          _handleTokenSync(args);
                        },
                      );
                      // Add JavaScript handler for NativeAndroidBridge messages
                      controller.addJavaScriptHandler(
                        handlerName: 'NativeAndroidBridge',
                        callback: (args) {
                          if (args.isNotEmpty && args[0] is String) {
                            _handleWebMessage(args[0] as String);
                          }
                        },
                      );

                      // Explicitly load the URL if initialUrlRequest didn't work
                      final urlToLoad =
                          _initialUrl ??
                          '${Env.webBaseUrl}/login';
                      debugPrint('🔄 Explicitly loading URL: $urlToLoad');
                      try {
                        await controller.loadUrl(
                          urlRequest: URLRequest(url: WebUri(urlToLoad)),
                        );
                      } catch (e) {
                        debugPrint('❌ Error loading URL: $e');
                        // Try loading login page as fallback
                        try {
                          await controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri(
                                '${Env.webBaseUrl}/login',
                              ),
                            ),
                          );
                        } catch (e2) {
                          debugPrint('❌ Error loading fallback URL: $e2');
                        }
                      }
                    },
                    onLoadStart: (controller, url) async {
                      final urlString = url.toString();
                      final previousUrl = _currentUrl ?? '';

                      debugPrint('🌐 WebView loading: $urlString');

                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                        _errorMessage = null;
                        _currentUrl = urlString;
                      });

                      // CRITICAL: Inject token early (onLoadStart) before SPA bootstraps
                      // Only inject if we have a token
                      if (_hasToken) {
                        await _injectTokenIfAny(controller);
                      }

                      // Only logout if user navigated FROM authenticated page TO login page
                      // Don't logout if already on login page or if we're logging out
                      if (urlString.contains('/login') &&
                          previousUrl.isNotEmpty &&
                          !previousUrl.contains('/login') &&
                          !_isLoggingOut) {
                        // User navigated to login page from authenticated area, logout
                        Future.microtask(() {
                          _handleLogout();
                        });
                      }
                    },
                    onLoadStop: (controller, url) async {
                      debugPrint('✅ WebView loaded: ${url.toString()}');

                      setState(() {
                        _isLoading = false;
                        _currentUrl = url.toString();
                      });
                      _pullToRefreshController?.endRefreshing();

                      // Reset logout flag when page loads successfully
                      _isLoggingOut = false;

                      // Debug auth state BEFORE injection (baseline)
                      debugPrint('🔎 Debugging auth state BEFORE injection:');
                      await _debugAuthState(controller);

                      // CRITICAL: Inject stored token into WebView BEFORE other scripts
                      // Only inject if we have a token
                      if (_hasToken) {
                        await _injectTokenIfAny(controller);
                      }

                      // Inject JavaScript to listen for logout
                      await _injectLogoutListener(controller);

                      // Inject JavaScript to sync tokens from WebView login
                      await _injectLoginSyncListener(controller);

                      // Inject NativeAndroidBridge.postMessage API
                      await _injectNativeAndroidBridge(controller);

                      // Hide bug/feedback button
                      await _hideBugButton(controller);

                      // Also check cookies directly as backup (if not on login page)
                      if (!url.toString().contains('/login')) {
                        _checkCookiesForTokens(controller);
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      debugPrint('❌ WebView error: ${error.description}');
                      debugPrint('❌ Failed URL: ${request.url}');
                      setState(() {
                        _isLoading = false;
                        _hasError = true;
                        _errorMessage = error.description;
                      });
                    },
                    onReceivedHttpError: (controller, request, response) {
                      debugPrint(
                        '❌ WebView HTTP error: ${response.statusCode}',
                      );
                      debugPrint('❌ Failed URL: ${request.url}');
                      final statusCode = response.statusCode;
                      if (statusCode != null && statusCode >= 400) {
                        setState(() {
                          _isLoading = false;
                          _hasError = true;
                          _errorMessage = 'HTTP Error $statusCode';
                        });
                      }
                    },
                    androidOnPermissionRequest: (controller, origin, resources) async {
                      // Grant camera and microphone permissions automatically on Android
                      final resourceStrings = resources
                          .map((r) => r.toString())
                          .join(", ");
                      debugPrint(
                        'Android Permission request from $origin: $resourceStrings',
                      );

                      // Check if camera permission is already granted
                      final cameraStatus = await Permission.camera.status;
                      if (!cameraStatus.isGranted) {
                        final result = await Permission.camera.request();
                        debugPrint('Camera permission requested: $result');
                      }

                      // Check if microphone permission is already granted
                      final micStatus = await Permission.microphone.status;
                      if (!micStatus.isGranted) {
                        final result = await Permission.microphone.request();
                        debugPrint('Microphone permission requested: $result');
                      }

                      return PermissionRequestResponse(
                        resources: resources,
                        action: PermissionRequestResponseAction.GRANT,
                      );
                    },
                    // CRITICAL: iOS WebView permission handler - grants camera/mic to WebView
                    // This is required even if app-level permissions are granted
                    // Without this, WebRTC will fail with NotAllowedError
                    onPermissionRequest: (controller, request) async {
                      final resourceStrings = request.resources
                          .map((r) => r.toString())
                          .join(", ");
                      debugPrint(
                        '📹 WebView permission request: $resourceStrings',
                      );
                      // Grant all permission requests (camera, microphone)
                      // App-level permissions are already checked in _requestPermissions()
                      return PermissionResponse(
                        resources: request.resources,
                        action: PermissionResponseAction.GRANT,
                      );
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      debugPrint('WebView Console: ${consoleMessage.message}');
                    },
                    onReceivedServerTrustAuthRequest:
                        (controller, challenge) async {
                          return ServerTrustAuthResponse(
                            action: ServerTrustAuthResponseAction.PROCEED,
                          );
                        },
                    // JavaScript handler for logout from webview
                    onJsAlert: (controller, jsAlertRequest) async {
                      // Check if it's a logout message
                      final message =
                          jsAlertRequest.message?.toLowerCase() ?? '';
                      if (message.contains('logout')) {
                        _handleLogout();
                        return JsAlertResponse(handledByClient: true);
                      }
                      return JsAlertResponse(handledByClient: false);
                    },
                  ),
                ),
              if (!_isBootstrapping && _isLoading)
                Container(
                  color: Colors.white,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              if (!_isBootstrapping && _hasError && !_isLoading)
                Container(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Network Error',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage?.contains('ERR_NAME_NOT_RESOLVED') ==
                                    true
                                ? 'Unable to connect to the server. Please check your internet connection.'
                                : _errorMessage ??
                                      'An error occurred while loading the page.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              _webViewController?.reload();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
