import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:convert';
import '../../core/config/env.dart';
import '../../services/notification_service.dart';
import '../../core/utils/file_logger.dart';
import 'auth/auth_controller.dart';

class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({super.key});

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  PullToRefreshController? _pullToRefreshController;

  String? _initialUrl;
  bool _hasCheckedLogin = false; // Track if we've already checked for login

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        enabled: true,
      ),
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
    
    // Defer provider reads until after build completes to prevent Riverpod errors
    Future.microtask(() {
      _requestPermissionsAndInitialize();
    });
  }
  
  @override
  void dispose() {
    // Clear notification callback when screen is disposed
    NotificationService.setNotificationTapCallback(null);
    super.dispose();
  }

  Future<void> _requestPermissionsAndInitialize() async {
    // Request camera and microphone permissions at runtime before loading WebView
    await _requestPermissions();
    // Initialize URL after permissions are requested
    await _initializeUrl();
  }

  Future<void> _requestPermissions() async {
    try {
      // Check current permission status first
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;
      
      // Only request if not already granted
      final Map<Permission, PermissionStatus> permissions = {};
      
      if (!cameraStatus.isGranted) {
        permissions[Permission.camera] = await Permission.camera.request();
      } else {
        permissions[Permission.camera] = cameraStatus;
      }
      
      if (!micStatus.isGranted && !micStatus.isPermanentlyDenied) {
        permissions[Permission.microphone] = await Permission.microphone.request();
      } else {
        permissions[Permission.microphone] = micStatus;
      }
      
      FileLogger.log('📷 Camera permission: ${permissions[Permission.camera]}');
      FileLogger.log('🎤 Microphone permission: ${permissions[Permission.microphone]}');
      
      // If microphone is permanently denied, we'll rely on WebView's native permission handler
      if (permissions[Permission.microphone]?.isPermanentlyDenied == true) {
        FileLogger.log('⚠️ Microphone permission is permanently denied. User needs to enable it in app settings.');
      }
    } catch (e) {
      FileLogger.log('❌ Error requesting permissions: $e');
      // Continue anyway - WebView will handle permission requests natively
    }
  }

  Future<void> _initializeUrl() async {
    if (!mounted) return;
    
    // Use base URL from env configuration
    final baseUrl = Env.webBaseUrl.trim().replaceAll(RegExp(r'/+$'), ''); // Remove trailing slashes
    
    // Let the web app handle auth/redirects itself (like a normal browser).
    // If user is logged in, the web app should show supplier-side/home.
    // If not logged in, the web app should redirect to /login.
    _initialUrl = '$baseUrl/supplier-side/home';
    
    if (mounted) {
      setState(() {});
    }
  }

  /// Check if user is logged in by monitoring URL and extracting token from WebView
  Future<void> _checkLoginStatus(InAppWebViewController controller, WebUri? url) async {
    if (url == null) return;
    
    final urlPath = url.path;
    FileLogger.log('🌐 WebView URL changed: $urlPath');
    
    // Check if user is on authenticated route (logged in)
    final isAuthenticatedRoute = urlPath.contains('/supplier-side') && 
                                 !urlPath.contains('/login') &&
                                 (urlPath.contains('/home') || urlPath.contains('/supplier-side'));
    
    if (isAuthenticatedRoute && !_hasCheckedLogin) {
      FileLogger.log('   ✅ User navigated to authenticated route - checking for login tokens...');
      _hasCheckedLogin = true; // Only check once to avoid multiple checks
      
      // Wait a bit for the page to fully load and set tokens
      await Future.delayed(const Duration(milliseconds: 500));
      
      try {
        // Try to extract access token from localStorage or sessionStorage
        final tokenScript = '''
          (function() {
            try {
              // Try multiple possible token storage keys
              var token = localStorage.getItem('access_token') || 
                         localStorage.getItem('token') ||
                         localStorage.getItem('accessToken') ||
                         sessionStorage.getItem('access_token') ||
                         sessionStorage.getItem('token') ||
                         sessionStorage.getItem('accessToken');
              
              var refreshToken = localStorage.getItem('refresh_token') || 
                                localStorage.getItem('refreshToken') ||
                                sessionStorage.getItem('refresh_token') ||
                                sessionStorage.getItem('refreshToken');
              
              if (token) {
                return JSON.stringify({
                  accessToken: token,
                  refreshToken: refreshToken || null
                });
              }
              return 'NO_TOKEN';
            } catch(e) {
              return 'ERROR: ' + e.message;
            }
          })();
        ''';
        
        final result = await controller.evaluateJavascript(source: tokenScript);
        FileLogger.log('   JavaScript result: $result');
        
        if (result != null && result != 'NO_TOKEN' && !result.startsWith('ERROR')) {
          try {
            final tokenData = jsonDecode(result.toString().replaceAll("'", '"'));
            final accessToken = tokenData['accessToken']?.toString();
            final refreshToken = tokenData['refreshToken']?.toString();
            
            if (accessToken != null && accessToken.isNotEmpty) {
              FileLogger.log('   🔑 Token found in WebView storage - syncing with Flutter...');
              FileLogger.log('   Access token length: ${accessToken.length}');
              
              // Sync tokens with Flutter auth state
              await ref.read(authControllerProvider.notifier).syncTokensFromWebView(
                accessToken: accessToken,
                refreshToken: refreshToken,
              );
              
              FileLogger.log('   ✅ Tokens synced - FCM token should be sent automatically');
            } else {
              FileLogger.log('   ⚠️ Token found but is empty');
            }
          } catch (e) {
            FileLogger.log('   ❌ Error parsing token data: $e');
            FileLogger.log('   Raw result: $result');
          }
        } else {
          FileLogger.log('   ⚠️ No token found in WebView storage');
          FileLogger.log('   This might mean:');
          FileLogger.log('      - User is not logged in yet');
          FileLogger.log('      - Token is stored with different key');
          FileLogger.log('      - Web app uses different storage method');
        }
      } catch (e) {
        FileLogger.log('   ❌ Error checking login status: $e');
      }
    } else if (urlPath.contains('/login')) {
      // User navigated to login page - reset check flag
      _hasCheckedLogin = false;
      FileLogger.log('   🔄 User navigated to login page - reset login check flag');
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
        floatingActionButton: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.blue.withOpacity(0.7),
          onPressed: () async {
            // Show dialog with options
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Debug Logs'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Log entries: ${FileLogger.getLogCount()}'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await FileLogger.shareLogFile();
                      },
                      child: Text('Share Log File'),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final logs = await FileLogger.getAllLogs();
                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Debug Logs (${FileLogger.getLogCount()} entries)'),
                            content: Container(
                              width: double.maxFinite,
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  logs.isEmpty ? 'No logs available yet.' : logs,
                                  style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text('View Logs'),
                    ),
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await FileLogger.clearLogs();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logs cleared')),
                        );
                      },
                      child: Text('Clear Logs', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Icon(Icons.bug_report, size: 20),
        ),
        body: SafeArea(
          top: true,
          bottom: true,
          child: _initialUrl == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Stack(
                  children: [
                    InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(_initialUrl!),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      iframeAllow: "camera; microphone",
                      iframeAllowFullscreen: true,
                      useHybridComposition: true,
                      safeBrowsingEnabled: true,
                      domStorageEnabled: true,
                      // Camera and media access settings
                      thirdPartyCookiesEnabled: true,
                      // Respect system UI insets (status bar, navigation bar)
                      useShouldOverrideUrlLoading: true,
                      verticalScrollBarEnabled: true,
                      horizontalScrollBarEnabled: true,
                    ),
                    pullToRefreshController: _pullToRefreshController,
                    onWebViewCreated: (controller) async {
                      _webViewController = controller;
                    },
                    onLoadStart: (controller, url) async {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                        _errorMessage = null;
                      });
                    },
                    onLoadStop: (controller, url) async {
                      setState(() {
                        _isLoading = false;
                      });
                      _pullToRefreshController?.endRefreshing();
                      
                      // Check if user logged in by monitoring URL
                      await _checkLoginStatus(controller, url);
                    },
                    onReceivedError: (controller, request, error) {
                      FileLogger.log('❌ WebView error: ${error.description}');
                      setState(() {
                        _isLoading = false;
                        _hasError = true;
                        _errorMessage = error.description;
                      });
                    },
                    androidOnPermissionRequest: (controller, origin, resources) async {
                      // Grant camera and microphone permissions automatically on Android
                      FileLogger.log('📱 Android Permission request from $origin: ${resources.join(", ")}');
                      
                      // Check which resources are being requested
                      final needsCamera = resources.contains('android.webkit.resource.VIDEO_CAPTURE');
                      final needsMicrophone = resources.contains('android.webkit.resource.AUDIO_CAPTURE');
                      
                      // Check and request camera permission if needed
                      if (needsCamera) {
                      final cameraStatus = await Permission.camera.status;
                        if (!cameraStatus.isGranted && !cameraStatus.isPermanentlyDenied) {
                        final result = await Permission.camera.request();
                        FileLogger.log('📷 Camera permission requested: $result');
                          if (result.isDenied || result.isPermanentlyDenied) {
                            return PermissionRequestResponse(
                              resources: resources,
                              action: PermissionRequestResponseAction.DENY,
                            );
                          }
                        } else if (cameraStatus.isPermanentlyDenied) {
                          FileLogger.log('⚠️ Camera permission permanently denied');
                          return PermissionRequestResponse(
                            resources: resources,
                            action: PermissionRequestResponseAction.DENY,
                          );
                        }
                      }
                      
                      // Check and request microphone permission if needed
                      if (needsMicrophone) {
                      final micStatus = await Permission.microphone.status;
                        if (!micStatus.isGranted && !micStatus.isPermanentlyDenied) {
                        final result = await Permission.microphone.request();
                        FileLogger.log('🎤 Microphone permission requested: $result');
                          if (result.isDenied || result.isPermanentlyDenied) {
                            return PermissionRequestResponse(
                              resources: resources,
                              action: PermissionRequestResponseAction.DENY,
                            );
                          }
                        } else if (micStatus.isPermanentlyDenied) {
                          FileLogger.log('⚠️ Microphone permission permanently denied');
                          return PermissionRequestResponse(
                            resources: resources,
                            action: PermissionRequestResponseAction.DENY,
                          );
                        }
                      }
                      
                      return PermissionRequestResponse(
                        resources: resources,
                        action: PermissionRequestResponseAction.GRANT,
                      );
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      final msg = consoleMessage.message;
                      if (msg.isEmpty) return;
                      // Ignore common noisy logs from the web app
                      if (msg == '[object Object]' ||
                          msg == 'error [object Object]' ||
                          msg.contains('error [object Object]')) {
                        return;
                      }
                      FileLogger.log('🌐 WebView Console: $msg');
                    },
                    onReceivedServerTrustAuthRequest: (controller, challenge) async {
                      return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                    },
                  ),
                  if (_isLoading)
              Container(
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_hasError && !_isLoading)
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
                          _errorMessage?.contains('ERR_NAME_NOT_RESOLVED') == true
                              ? 'Unable to connect to the server. Please check your internet connection.'
                              : _errorMessage ?? 'An error occurred while loading the page.',
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
