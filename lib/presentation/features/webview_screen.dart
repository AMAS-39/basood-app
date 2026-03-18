import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/config/env.dart';
import '../../core/utils/file_logger.dart';
import 'auth/auth_controller.dart';
import '../../services/notification_service.dart';
import '../../services/firebase_service.dart';
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
  late final FlutterSecureStorage _storage;
  PullToRefreshController? _pullToRefreshController;

  String? _initialUrl;
  String? _currentUrl;
  bool _isLoggingOut = false; // Flag to prevent logout loops
  bool _isBootstrapping =
      true; // Flag to prevent WebView from loading before URL decision
  bool _hasToken =
      false; // Track if we have a token (existence only, not validity)
  static const _cookieSnapshotKey = 'web_cookie_snapshot_json';
  static const _userTypeKey = 'user_type';

  int _loginRescueAttempts = 0;
  static const int _maxLoginRescueAttempts = 1;

  String _resolveHomePathForUserType(String? userType) {
    switch ((userType ?? '').toLowerCase()) {
      case 'supplier':
        return '/supplier-side/main-screen';
      case 'driver':
        return '/driver-side';
      case 'admin':
      default:
        return '/';
    }
  }

  Future<String> _resolveHomeUrl() async {
    final storedUserType = await _storage.read(key: _userTypeKey);
    final homePath = _resolveHomePathForUserType(storedUserType);
    return '${Env.webBaseUrl}$homePath';
  }

  @override
  void initState() {
    super.initState();
    _storage = ref.read(secureStorageProvider);
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

  /// Bootstrap: Read token and determine initial URL before WebView loads.
  /// Order: 1) Restore cookies (snapshot + token/refreshtoken), 2) Set route, 3) Allow load.
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

      // Cold-start verification: log exactly what secure storage contains
      final exists = accessToken != null && accessToken.isNotEmpty;
      debugPrint(
        '🔍 Cold start: secure storage access_token exists=$exists, length=${accessToken?.length ?? 0}',
      );

      if (accessToken != null && accessToken.isNotEmpty) {
        _hasToken = true;
        final refreshToken = await _storage.read(key: 'refresh_token');

        // 1) COOKIES FIRST: Restore full cookie snapshot before any page load
        final snapshotRaw = await _storage.read(key: _cookieSnapshotKey);
        final snapshotExists = snapshotRaw != null && snapshotRaw.isNotEmpty;
        debugPrint(
          '🔍 Bootstrap: cookie snapshot exists=$snapshotExists',
        );

        if (snapshotExists) {
          final restoredCount = await _restoreCookieSnapshotBeforeLoad();
          debugPrint(
            '🔍 Bootstrap: restored $restoredCount cookies from full snapshot',
          );
        } else {
          // No snapshot: minimal fallback - set token/refreshtoken cookies only
          try {
            final cookieManager = CookieManager.instance();
            final cookieUrl = WebUri(Env.webBaseUrl);
            final domain = Uri.parse(Env.webBaseUrl).host;
            const tokenNames = ['token', 'access_token', 'accessToken', 'auth_token'];
            for (final name in tokenNames) {
              await cookieManager.setCookie(
                url: cookieUrl,
                name: name,
                value: accessToken,
                domain: domain,
                path: '/',
                isSecure: false,
                isHttpOnly: false,
                sameSite: HTTPCookieSameSitePolicy.LAX,
              );
              await cookieManager.setCookie(
                url: cookieUrl,
                name: name,
                value: accessToken,
                domain: domain,
                path: '/',
                isSecure: true,
                isHttpOnly: false,
                sameSite: HTTPCookieSameSitePolicy.NONE,
              );
            }
            if (refreshToken != null && refreshToken.isNotEmpty) {
              for (final name in ['refreshtoken', 'refresh_token']) {
                await cookieManager.setCookie(
                  url: cookieUrl,
                  name: name,
                  value: refreshToken,
                  domain: domain,
                  path: '/',
                  isSecure: false,
                  isHttpOnly: false,
                  sameSite: HTTPCookieSameSitePolicy.LAX,
                );
                await cookieManager.setCookie(
                  url: cookieUrl,
                  name: name,
                  value: refreshToken,
                  domain: domain,
                  path: '/',
                  isSecure: true,
                  isHttpOnly: false,
                  sameSite: HTTPCookieSameSitePolicy.NONE,
                );
              }
            }
            debugPrint('🔑 Bootstrap: no snapshot, set token/refreshtoken cookies only');
          } catch (e) {
            debugPrint('⚠️ Bootstrap cookie fallback failed: $e');
          }
        }

        // 2) ROUTE: Resolve home path by role
        final storedUserType = await _storage.read(key: _userTypeKey);
        final homePath = _resolveHomePathForUserType(storedUserType);
        _initialUrl = '${Env.webBaseUrl}$homePath';
        debugPrint(
          '🔍 Bootstrap: stored user_type=$storedUserType, resolved home path=$homePath',
        );
        debugPrint(
          '✅ Token found (len=${accessToken.length}), initializing with home URL=$_initialUrl',
        );

        // Update provider state
        ref.read(accessTokenProvider.notifier).state = accessToken;

        final refreshExists = refreshToken != null && refreshToken.isNotEmpty;
        debugPrint(
          '🔍 Cold start: refresh_token exists=$refreshExists, length=${refreshToken?.length ?? 0}',
        );
        if (refreshExists) {
          ref.read(refreshTokenProvider.notifier).state = refreshToken;
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

    // On resume: only restore if we're on /login while token exists
    if (state == AppLifecycleState.resumed &&
        _webViewController != null &&
        _hasToken) {
      final url = _currentUrl ?? '';
      final u = Uri.tryParse(url);
      final isLogin =
          (u?.path.contains('/login') ?? false) ||
          (u?.fragment.contains('login') ?? false);
      if (isLogin && !_isLoggingOut) {
        debugPrint('🔄 App resumed on /login with token -> restore full cookies and go home');
        _restoreAllCookiesNow().then((_) async {
          final homeUrl = await _resolveHomeUrl();
          _webViewController?.loadUrl(
            urlRequest: URLRequest(url: WebUri(homeUrl)),
          );
        });
      }
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
        function getFromSessionStorage(key) {
          try {
            return sessionStorage.getItem(key);
          } catch (e) {
            return null;
          }
        }
        function getToken(key) {
          return getCookie(key) || getFromLocalStorage(key) || getFromSessionStorage(key);
        }

        function syncTokensToFlutter() {
          if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) return;

          var accessToken = getToken('access_token') ||
            getToken('accessToken') ||
            getToken('token');

          if (!accessToken) {
            try {
              var authHeader = getFromLocalStorage('Authorization') || getFromSessionStorage('Authorization');
              if (authHeader && authHeader.startsWith('Bearer ')) {
                accessToken = authHeader.substring(7);
              }
            } catch (e) {}
          }

          if (!accessToken || accessToken === lastSyncedToken) return;

          var refreshToken =
  getToken('refreshtoken') ||
  getToken('refresh_token') ||
  getToken('refreshToken');

          lastSyncedToken = accessToken;
          window.flutter_inappwebview.callHandler('syncTokens', {
            accessToken: accessToken,
            refreshToken: refreshToken || ''
          });
        }

        var lastUrl = window.location.href;
        // Sync immediately when URL changes from /login (user just logged in)
        setInterval(function() {
          var currentUrl = window.location.href;
          if (lastUrl.includes('/login') && !currentUrl.includes('/login')) {
            lastSyncedToken = null;
            syncTokensToFlutter();
            setTimeout(syncTokensToFlutter, 500);
            setTimeout(syncTokensToFlutter, 1500);
          } else if (!currentUrl.includes('/login')) {
            syncTokensToFlutter();
          }
          lastUrl = currentUrl;
        }, 2000);

        if (!window.location.href.includes('/login')) {
          syncTokensToFlutter();
          setTimeout(syncTokensToFlutter, 1000);
          setTimeout(syncTokensToFlutter, 2000);
        }
      })();
    ''',
    );
  }

  void _handleLogout() {
    // Prevent multiple logout calls
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    _hasToken = false;
    // Ensures shouldOverrideUrlLoading won't block our redirect to /login

    // Defer provider state modification to prevent Riverpod errors
    Future.microtask(() async {
      if (!mounted) return;

      final currentUrl = _currentUrl ?? '';
      final isAlreadyOnLogin = currentUrl.contains('/login');

      // Clear secure storage and provider state
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: _cookieSnapshotKey);
      await _storage.delete(key: _userTypeKey);
      ref.read(accessTokenProvider.notifier).state = null;
      ref.read(refreshTokenProvider.notifier).state = null;

      // Update token flags
      _hasToken = false;

      // Only reload if we're not already on login page
      if (!isAlreadyOnLogin) {
        // Call logout from auth controller
        ref.read(authControllerProvider.notifier).logout();

        // Reload webview to show login page
        _webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri('${Env.webBaseUrl}/login')),
        );

        // Reset flag after a delay
        Future.delayed(const Duration(seconds: 2), () {
          _isLoggingOut = false;
        });
      } else {
        // Already on login page, just clear auth state
        _isLoggingOut = false;
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
          debugPrint(
            '🔄 Syncing tokens from WebView: storing token (len=${accessToken.length}), _hasToken=true',
          );

          // ALWAYS write to secure storage first for persistence (cold start)
          await _storage.write(key: 'access_token', value: accessToken);
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await _storage.write(key: 'refresh_token', value: refreshToken);
          }
          debugPrint(
            '✅ access_token persisted to FlutterSecureStorage (len=${accessToken.length})',
          );
          final verify = await _storage.read(key: 'access_token');
          debugPrint(
            '🔎 Token read-back after sync: exists=${verify != null && verify.isNotEmpty}, len=${verify?.length ?? 0}',
          );

          // Update provider state AFTER saving to storage
          ref
              .read(authControllerProvider.notifier)
              .syncTokensFromWebView(
                accessToken: accessToken,
                refreshToken: refreshToken,
              );

          debugPrint('✅ Tokens synced to provider state');

          // Update token flags
          _hasToken = true;
          if (mounted) setState(() {});

          if (_webViewController != null) {
            await Future.delayed(const Duration(milliseconds: 500));
            await _snapshotWebCookies(_webViewController!);
            await Future.delayed(const Duration(seconds: 1));
            await _snapshotWebCookies(_webViewController!);
            await Future.delayed(const Duration(seconds: 2));
            await _snapshotWebCookies(_webViewController!);
          }

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
        } else if ((name.contains('refresh') && name.contains('token')) ||
            name == 'refreshtoken') {
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
          debugPrint(
            '✅ access_token persisted to FlutterSecureStorage (len=${accessToken.length})',
          );
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

          // Update token flags
          _hasToken = true;
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking cookies: $e');
      // Don't throw - this is a backup method
    }
  }

  /// Serialize HTTPCookieSameSitePolicy to string for JSON storage.
  /// Returns null when policy is null (preserve exact SameSite, no default).
  String? _sameSiteToString(HTTPCookieSameSitePolicy? policy) {
    if (policy == null) return null;
    return policy.toValue();
  }

  /// Parse string back to HTTPCookieSameSitePolicy.
  HTTPCookieSameSitePolicy? _sameSiteFromString(String? s) {
    if (s == null || s.isEmpty) return null;
    return HTTPCookieSameSitePolicy.fromValue(s);
  }

  /// Snapshot ALL cookies with full metadata for browser-equivalent restore.
  Future<void> _snapshotWebCookies(InAppWebViewController controller) async {
    try {
      final cm = CookieManager.instance();
      final url = WebUri(Env.webBaseUrl);
      final cookies = await cm.getCookies(url: url);

      final list = <Map<String, dynamic>>[];
      String? userTypeValue;

      for (final c in cookies) {
        final name = c.name.trim();
        final value = (c.value ?? '').toString().trim();
        if (name.isEmpty || value.isEmpty) continue;

        final map = <String, dynamic>{
          'name': name,
          'value': value,
          'domain': c.domain,
          'path': c.path ?? '/',
          'expiresDate': c.expiresDate,
          'isSecure': c.isSecure ?? false,
          'isHttpOnly': c.isHttpOnly ?? false,
        };
        final sameSiteStr = _sameSiteToString(c.sameSite);
        if (sameSiteStr != null) {
          map['sameSite'] = sameSiteStr;
        }
        list.add(map);

        if (name.toLowerCase() == 'usertype' || name == 'userType') {
          userTypeValue = value;
        }
      }

      await _storage.write(key: _cookieSnapshotKey, value: jsonEncode(list));

      if (userTypeValue != null && userTypeValue.isNotEmpty) {
        await _storage.write(key: _userTypeKey, value: userTypeValue);
      }

      debugPrint('🧠 Saved full cookie snapshot: ${list.length} cookies');
    } catch (e) {
      debugPrint('⚠️ Cookie snapshot failed: $e');
    }
  }

  /// Restore ALL cookies from saved snapshot before first WebView load.
  /// Returns count of cookies restored.
  Future<int> _restoreCookieSnapshotBeforeLoad() async {
    try {
      final raw = await _storage.read(key: _cookieSnapshotKey);
      if (raw == null || raw.isEmpty) {
        debugPrint('🍪 No cookie snapshot to restore');
        return 0;
      }

      final list = jsonDecode(raw) as List<dynamic>;
      final cm = CookieManager.instance();
      final cookieUrl = WebUri(Env.webBaseUrl);
      final domain = Uri.parse(Env.webBaseUrl).host;
      var restored = 0;
      final restoredNames = <String>[];
      final restoredDomains = <String>[];

      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final name = (map['name'] ?? '').toString().trim();
        final value = (map['value'] ?? '').toString().trim();
        if (name.isEmpty || value.isEmpty) continue;

        final path = (map['path'] ?? '/').toString();
        final cookieDomain = map['domain']?.toString() ?? domain;
        final expiresDate = map['expiresDate'] as int?;
        final isSecure = map['isSecure'] as bool? ?? false;
        final isHttpOnly = map['isHttpOnly'] as bool? ?? false;
        final sameSite = _sameSiteFromString(map['sameSite']?.toString());

        await cm.setCookie(
          url: cookieUrl,
          name: name,
          value: value,
          domain: cookieDomain,
          path: path,
          expiresDate: expiresDate,
          isSecure: isSecure,
          isHttpOnly: isHttpOnly,
          sameSite: sameSite,
        );
        restored++;
        restoredNames.add(name);
        restoredDomains.add(cookieDomain);
      }

      debugPrint('🍪 Restored $restored cookies from full snapshot before load');
      debugPrint('🍪 Restored cookie names: $restoredNames');
      debugPrint('🍪 Restored cookie domains: $restoredDomains');
      debugPrint('🍪 Env.webBaseUrl host: ${Uri.parse(Env.webBaseUrl).host}');
      return restored;
    } catch (e) {
      debugPrint('⚠️ Restore cookie snapshot failed: $e');
      return 0;
    }
  }

  /// Restore full cookie jar from saved snapshot (used when blocking /login
  /// or post-load restore). Browser-equivalent: all cookies, not just auth.
  Future<void> _restoreAllCookiesNow() async {
    try {
      final raw = await _storage.read(key: _cookieSnapshotKey);
      if (raw == null || raw.isEmpty) {
        debugPrint('🍪 No snapshot available for immediate restore');
        return;
      }

      final list = jsonDecode(raw) as List<dynamic>;
      final cm = CookieManager.instance();
      final cookieUrl = WebUri(Env.webBaseUrl);
      final domain = Uri.parse(Env.webBaseUrl).host;
      final restoredNames = <String>[];
      final restoredDomains = <String>[];

      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final name = (map['name'] ?? '').toString().trim();
        final value = (map['value'] ?? '').toString().trim();
        if (name.isEmpty || value.isEmpty) continue;

        final path = (map['path'] ?? '/').toString();
        final cookieDomain = map['domain']?.toString() ?? domain;
        final expiresDate = map['expiresDate'] as int?;
        final isSecure = map['isSecure'] as bool? ?? false;
        final isHttpOnly = map['isHttpOnly'] as bool? ?? false;
        final sameSite = _sameSiteFromString(map['sameSite']?.toString());

        await cm.setCookie(
          url: cookieUrl,
          name: name,
          value: value,
          domain: cookieDomain,
          path: path,
          expiresDate: expiresDate,
          isSecure: isSecure,
          isHttpOnly: isHttpOnly,
          sameSite: sameSite,
        );
        restoredNames.add(name);
        restoredDomains.add(cookieDomain);
      }

      debugPrint('🍪 Immediate full cookie restore completed');
      debugPrint('🍪 Restored cookie names: $restoredNames');
      debugPrint('🍪 Restored cookie domains: $restoredDomains');
      debugPrint('🍪 Env.webBaseUrl host: ${Uri.parse(Env.webBaseUrl).host}');
    } catch (e) {
      debugPrint('⚠️ _restoreAllCookiesNow failed: $e');
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

            // ALWAYS write to secure storage first for persistence (cold start)
            await _storage.write(key: 'access_token', value: accessToken);
            debugPrint(
              '✅ access_token persisted to FlutterSecureStorage (len=${accessToken.length})',
            );
            final verify = await _storage.read(key: 'access_token');
            debugPrint(
              '🔎 Token read-back after saveToken(auth): exists=${verify != null && verify.isNotEmpty}, len=${verify?.length ?? 0}',
            );
            // Sync refresh token if provided
            final String? refreshToken = data['refreshToken'] as String?;
            if (refreshToken != null && refreshToken.isNotEmpty) {
              await _storage.write(key: 'refresh_token', value: refreshToken);
              ref.read(refreshTokenProvider.notifier).state = refreshToken;
            }
            // Update provider state
            await ref
                .read(authControllerProvider.notifier)
                .syncTokensFromWebView(
                  accessToken: accessToken,
                  refreshToken: refreshToken,
                );

          // Update token flags
          _hasToken = true;
          if (mounted) setState(() {});

            if (_webViewController != null) {
              await Future.delayed(const Duration(milliseconds: 500));
              await _snapshotWebCookies(_webViewController!);
              await Future.delayed(const Duration(seconds: 1));
              await _snapshotWebCookies(_webViewController!);
              await Future.delayed(const Duration(seconds: 2));
              await _snapshotWebCookies(_webViewController!);
            }

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
              debugPrint(
                '✅ access_token persisted (JWT auto-detect) (len=${token.length})',
              );
              final verify = await _storage.read(key: 'access_token');
              debugPrint(
                '🔎 Token read-back after saveToken(JWT): exists=${verify != null && verify.isNotEmpty}, len=${verify?.length ?? 0}',
              );
              ref.read(accessTokenProvider.notifier).state = token;

              final String? refreshToken = data['refreshToken'] as String?;
              if (refreshToken != null && refreshToken.isNotEmpty) {
                await _storage.write(key: 'refresh_token', value: refreshToken);
                ref.read(refreshTokenProvider.notifier).state = refreshToken;
              }
              _hasToken = true;
              if (mounted) setState(() {});

              if (_webViewController != null) {
                await Future.delayed(const Duration(milliseconds: 500));
                await _snapshotWebCookies(_webViewController!);
                await Future.delayed(const Duration(seconds: 1));
                await _snapshotWebCookies(_webViewController!);
                await Future.delayed(const Duration(seconds: 2));
                await _snapshotWebCookies(_webViewController!);
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
        await _storage.delete(key: _cookieSnapshotKey);
        await _storage.delete(key: _userTypeKey);
        ref.read(accessTokenProvider.notifier).state = null;
        ref.read(refreshTokenProvider.notifier).state = null;

        // Update token flags
        _hasToken = false;
        if (mounted) setState(() {});

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
      if (!window.NativeAndroidBridge) {
        window.NativeAndroidBridge = {};
      }

      // Existing format
      window.NativeAndroidBridge.postMessage = function(message) {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('NativeAndroidBridge', message);
        } else {
          console.warn('NativeAndroidBridge.postMessage: Flutter handler not available');
        }
      };

      // React Android format: NativeAndroidBridge.receiveToken(token)
      window.NativeAndroidBridge.receiveToken = function(token) {
        try {
          var payload = JSON.stringify({
            command: 'saveToken',
            tokenType: 'auth',
            accessToken: token
          });

          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('NativeAndroidBridge', payload);
          } else {
            console.warn('NativeAndroidBridge.receiveToken: Flutter handler not available');
          }
        } catch (e) {
          console.error('NativeAndroidBridge.receiveToken error:', e);
        }
      };

      // React iOS format: window.webkit.messageHandlers.nativeApp.postMessage(...)
      // Only add our fallback if native iOS bridge doesn't already exist (it may be a native object)
      if (!window.webkit) {
        window.webkit = {};
      }
      if (!window.webkit.messageHandlers) {
        window.webkit.messageHandlers = {};
      }
      if (!window.webkit.messageHandlers.nativeApp) {
        window.webkit.messageHandlers.nativeApp = {
          postMessage: function(message) {
            try {
              var payload = message;
              if (typeof payload !== 'string') {
                payload = JSON.stringify(payload);
              }
              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                window.flutter_inappwebview.callHandler('NativeAndroidBridge', payload);
              } else {
                console.warn('nativeApp.postMessage: Flutter handler not available');
              }
            } catch (e) {
              console.error('nativeApp.postMessage error:', e);
            }
          }
        };
      }

      console.log('✅ Native bridges initialized: postMessage, receiveToken, nativeApp.postMessage');
    })();
    ''',
    );
  }

  /// Build UserScript for NativeAndroidBridge at document start (web can call immediately after login)
  UserScript _buildBridgeUserScript() {
    return UserScript(
      source: '''
      (function() {
        if (!window.NativeAndroidBridge) {
          window.NativeAndroidBridge = {};
        }

        window.NativeAndroidBridge.postMessage = function(message) {
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('NativeAndroidBridge', message);
          } else {
            console.warn('NativeAndroidBridge.postMessage: Flutter handler not available');
          }
        };

        window.NativeAndroidBridge.receiveToken = function(token) {
          try {
            var payload = JSON.stringify({
              command: 'saveToken',
              tokenType: 'auth',
              accessToken: token
            });

            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('NativeAndroidBridge', payload);
            } else {
              console.warn('NativeAndroidBridge.receiveToken: Flutter handler not available');
            }
          } catch (e) {
            console.error('NativeAndroidBridge.receiveToken error:', e);
          }
        };

        if (!window.webkit) {
          window.webkit = {};
        }
        if (!window.webkit.messageHandlers) {
          window.webkit.messageHandlers = {};
        }
        if (!window.webkit.messageHandlers.nativeApp) {
          window.webkit.messageHandlers.nativeApp = {
            postMessage: function(message) {
              try {
                var payload = message;
                if (typeof payload !== 'string') {
                  payload = JSON.stringify(payload);
                }
                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                  window.flutter_inappwebview.callHandler('NativeAndroidBridge', payload);
                } else {
                  console.warn('nativeApp.postMessage: Flutter handler not available');
                }
              } catch (e) {
                console.error('nativeApp.postMessage error:', e);
              }
            }
          };
        }
      })();
    ''',
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );
  }

  /// Build UserScripts for document start. No token injection - auth comes from
  /// cookies restored before first load (browser-equivalent).
  UnmodifiableListView<UserScript> _buildInitialUserScripts() {
    return UnmodifiableListView(<UserScript>[
      // PREBOOT: Log document.cookie at document-start (before React)
      UserScript(
        source: '''
          console.log('PREBOOT document.cookie = ' + document.cookie);
        ''',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      // PREBOOT: Log auth cookie completeness at document-start
      UserScript(
        source: '''
          console.log('PREBOOT auth cookie check', {
            token: document.cookie.includes('token='),
            refreshtoken: document.cookie.includes('refreshtoken='),
            expired: document.cookie.includes('expired='),
            permissions: document.cookie.includes('permissions='),
            id: document.cookie.includes('id='),
            fullname: document.cookie.includes('fullname='),
            username: document.cookie.includes('username='),
            email: document.cookie.includes('email='),
            imageurl: document.cookie.includes('imageurl='),
            usertype: document.cookie.includes('usertype=')
          });
        ''',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      _buildBridgeUserScript(),
    ]);
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
      // If on /login with empty storage, web app may use HttpOnly server session cookie
      if (result != null && result.contains('/login')) {
        debugPrint(
          '🔎 On /login: If storage is empty, web may use HttpOnly server cookie. '
          'Consider: A) Accept Authorization from localStorage, B) /auth/restore endpoint, C) Non-HttpOnly cookie.',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error debugging auth state: $e');
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
              // Do NOT use key on token - recreating WebView kills cookie/session persistence
              if (!_isBootstrapping)
                Positioned.fill(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(_initialUrl ?? '${Env.webBaseUrl}/login'),
                    ),
                    initialUserScripts: _buildInitialUserScripts(),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      iframeAllow: "camera; microphone",
                      iframeAllowFullscreen: true,
                      safeBrowsingEnabled: true,
                      domStorageEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      // iOS: share cookies across WebView instances for session persistence
                      sharedCookiesEnabled: true,
                      // iOS: incognito:false => WKWebsiteDataStore.default() (persistent); keep session
                      incognito: false,
                      clearSessionCache: false,
                      useOnLoadResource: false,
                      useShouldOverrideUrlLoading: true,
                      verticalScrollBarEnabled: true,
                      horizontalScrollBarEnabled: true,
                      allowsBackForwardNavigationGestures: true,
                      allowsLinkPreview: false,
                      isFraudulentWebsiteWarningEnabled: false,
                      cacheEnabled: true,
                      clearCache: false,
                      disallowOverScroll: false,
                    ),
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final url = navigationAction.request.url.toString();
                      debugPrint('🔗 Navigation request: $url');

                      final u = Uri.tryParse(url);
                      final isLogin =
                          (u?.path.contains('/login') ?? false) ||
                          (u?.fragment.contains('login') ?? false);

                      // Block /login redirect when we have a token and user didn't log out
                      if (_hasToken &&
                          isLogin &&
                          !_isLoggingOut &&
                          _loginRescueAttempts < _maxLoginRescueAttempts) {
                        debugPrint(
                          '🛡️ Blocking /login while token exists -> restore full cookies and go home (attempt ${_loginRescueAttempts + 1}/$_maxLoginRescueAttempts)',
                        );
                        _loginRescueAttempts++;
                        await _restoreAllCookiesNow();
                        final homeUrl = await _resolveHomeUrl();
                        await controller.loadUrl(
                          urlRequest: URLRequest(url: WebUri(homeUrl)),
                        );
                        return NavigationActionPolicy.CANCEL;
                      }

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
                      // Do NOT call loadUrl here - initialUrlRequest handles initial load.
                      // Double-loading caused /login flash. Fallback is in onReceivedError.
                    },
                    onLoadStart: (controller, url) async {
                      final urlString = url.toString();

                      debugPrint('🌐 WebView loading: $urlString');

                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                        _errorMessage = null;
                        _currentUrl = urlString;
                      });

                      // Do NOT inject token on every navigation - only in initialUserScripts and restore flow
                      // Do NOT auto-logout when navigating to /login - that incorrectly logs
                      // users out on 401 redirects or token expiry. Logout only via explicit
                      // logout click via injected logout handler.
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

                      final urlStr = url.toString();
                      final u = Uri.tryParse(urlStr);
                      final isLogin =
                          (u?.path.contains('/login') ?? false) ||
                          (u?.fragment.contains('login') ?? false);

                      // Reset login rescue attempts on successful non-login load
                      if (!isLogin) {
                        _loginRescueAttempts = 0;
                      }

                      // Debug auth state BEFORE injection (baseline)
                      debugPrint('🔎 Debugging auth state BEFORE injection:');
                      await _debugAuthState(controller);

                      // Post-load restore: token exists but we landed on /login -> restore full cookies and go home
                      if (_hasToken &&
                          isLogin &&
                          !_isLoggingOut &&
                          _loginRescueAttempts < _maxLoginRescueAttempts) {
                        debugPrint(
                          '🛡️ Post-load restore: on /login with token -> restore full cookies and go home (attempt ${_loginRescueAttempts + 1}/$_maxLoginRescueAttempts)',
                        );
                        _loginRescueAttempts++;
                        await _restoreAllCookiesNow();
                        final homeUrl = await _resolveHomeUrl();
                        await controller.loadUrl(
                          urlRequest: URLRequest(url: WebUri(homeUrl)),
                        );
                        return;
                      }

                      // Inject JavaScript to listen for logout
                      await _injectLogoutListener(controller);

                      // Inject JavaScript to sync tokens from WebView login
                      await _injectLoginSyncListener(controller);

                      // Inject NativeAndroidBridge.postMessage API
                      await _injectNativeAndroidBridge(controller);

                      // Hide bug/feedback button
                      await _hideBugButton(controller);

                      // Snapshot and sync cookies when not on login (for cold-start restore)
                      if (!isLogin) {
                        await _snapshotWebCookies(controller);
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
                      final level = consoleMessage.messageLevel.toString();
                      final msg = '[WebView $level] ${consoleMessage.message}';
                      FileLogger.log(msg);
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
