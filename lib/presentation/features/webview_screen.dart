import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/config/env.dart';
import '../../core/utils/file_logger.dart';
import '../../services/notification_service.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _refresh;

  bool _loading = true;
  bool _error = false;
  String? _errorMsg;

  late final String _loginUrl;

  @override
  void initState() {
    super.initState();
    _loginUrl = '${Env.webBaseUrl}/login';

    _refresh = PullToRefreshController(
      onRefresh: () => _controller?.reload(),
    );

    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  // ================= LOGIN INTERCEPTOR =================
  Future<void> _injectLoginInterceptorJS() async {
    const js = """
    (function () {

      function sendToFlutter(json) {
        if (json && json.token) {
          window.flutter_inappwebview.callHandler('loginData', {
            token: json.token,
            fcmToken: json.user && json.user.fcmToken ? json.user.fcmToken : null
          });
        }
      }

      // FETCH
      const oldFetch = window.fetch;
      window.fetch = function(input, init) {
        const url = typeof input === 'string' ? input : input.url;
        return oldFetch(input, init).then(res => {
          if (url.includes('/user/login')) {
            res.clone().text().then(body => {
              try { sendToFlutter(JSON.parse(body)); } catch(e){}
            });
          }
          return res;
        });
      };

      // XHR
      const OldXHR = window.XMLHttpRequest;
      function NewXHR() {
        const xhr = new OldXHR();
        xhr.addEventListener('load', function() {
          if (this.responseURL.includes('/user/login')) {
            try { sendToFlutter(JSON.parse(this.responseText)); } catch(e){}
          }
        });
        return xhr;
      }
      window.XMLHttpRequest = NewXHR;
    })();
    """;

    await _controller?.evaluateJavascript(source: js);
    FileLogger.log('✅ Login interceptor injected');
  }

  // ================= SEND FCM TO API =================
  Future<void> _sendFcmToApi(String jwtToken) async {
    final deviceFcm = await "Token FCM here ahmed";

    if (deviceFcm == null) {
      FileLogger.log('❌ Device FCM token is NULL');
      return;
    }

    FileLogger.log('📡 Sending FCM to API');
    FileLogger.log('JWT: $jwtToken');
    FileLogger.log('FCM: $deviceFcm');

    // TODO: replace with your real API call
    /*
    await dio.post(
      '/user/FcmToken',
      data: {'fcmToken': deviceFcm},
      options: Options(headers: {
        'Authorization': 'Bearer $jwtToken'
      }),
    );
    */

    FileLogger.log('✅ FCM sent to backend');
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _debugButton(),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_loginUrl)),
              pullToRefreshController: _refresh,
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                thirdPartyCookiesEnabled: true,
                useHybridComposition: true,
              ),
              onWebViewCreated: (c) {
                _controller = c;

                c.addJavaScriptHandler(
                  handlerName: 'loginData',
                  callback: (args) async {
                    if (args.isEmpty) return;

                    final data = Map<String, dynamic>.from(args[0]);

                    final token = data['token'];
                    final fcm = data['fcmToken'];

                    FileLogger.log('🔑 LOGIN TOKEN: $token');
                    FileLogger.log('📱 SERVER FCM: $fcm');

                    if (token != null) {
                      await _sendFcmToApi(token);
                    }
                  },
                );
              },
              onLoadStart: (_, __) {
                setState(() {
                  _loading = true;
                  _error = false;
                });
              },
              onLoadStop: (_, url) async {
                _refresh?.endRefreshing();
                setState(() => _loading = false);

                if (url != null && url.path.contains('/login')) {
                  await _injectLoginInterceptorJS();
                }
              },
              onReceivedError: (_, __, err) {
                FileLogger.log('❌ WebView error: ${err.description}');
                setState(() {
                  _loading = false;
                  _error = true;
                  _errorMsg = err.description;
                });
              },
              androidOnPermissionRequest: (_, __, res) async =>
                  PermissionRequestResponse(
                    resources: res,
                    action: PermissionRequestResponseAction.GRANT,
                  ),
              onReceivedServerTrustAuthRequest: (_, __) async =>
                  ServerTrustAuthResponse(
                    action: ServerTrustAuthResponseAction.PROCEED,
                  ),
            ),

            if (_loading)
              const Center(child: CircularProgressIndicator()),

            if (_error)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 64),
                    const SizedBox(height: 12),
                    Text(_errorMsg ?? 'Network error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _controller?.reload(),
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================= DEBUG BUTTON =================
  Widget _debugButton() {
    return FloatingActionButton(
      mini: true,
      child: const Icon(Icons.bug_report),
      onPressed: () async {
        final logs = await FileLogger.getAllLogs();
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Debug Logs'),
            content: SingleChildScrollView(
              child: SelectableText(
                logs.isEmpty ? 'No logs' : logs,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              )
            ],
          ),
        );
      },
    );
  }
}
