import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/env.dart';
import '../../core/config/api_endpoints.dart';
import '../../services/notification_service.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _refresh;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  late final Dio _dio;

  bool _loading = true;
  bool _fcmSent = false;
  StreamSubscription<String>? _fcmRefreshSub;

  late final String _loginUrl;

  @override
  void initState() {
    super.initState();

    _loginUrl = '${Env.webBaseUrl}/login';

    _dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    _refresh = PullToRefreshController(
      onRefresh: () => _controller?.reload(),
    );

    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await _fcm.requestPermission();
  }

  // ================= LOGIN INTERCEPTOR =================
  Future<void> _injectLoginInterceptorJS() async {
    const js = """
    (function () {
      function send(token) {
        if (token) {
          window.flutter_inappwebview.callHandler('loginData', token);
        }
      }

      const oldFetch = window.fetch;
      window.fetch = function(input, init) {
        const url = typeof input === 'string' ? input : input.url;
        return oldFetch(input, init).then(res => {
          if (url.includes('/user/login')) {
            res.clone().json().then(d => send(d.token)).catch(()=>{});
          }
          return res;
        });
      };

      const OldXHR = window.XMLHttpRequest;
      window.XMLHttpRequest = function() {
        const xhr = new OldXHR();
        xhr.addEventListener('load', function() {
          if (this.responseURL.includes('/user/login')) {
            try {
              const d = JSON.parse(this.responseText);
              send(d.token);
            } catch(e){}
          }
        });
        return xhr;
      };
    })();
    """;

    await _controller?.evaluateJavascript(source: js);
  }

  // ================= FCM REGISTER =================
  Future<void> _sendFcmToApi(String jwtToken) async {
    if (_fcmSent) return;
    _fcmSent = true;

    final fcmToken = await _fcm.getToken();
    if (fcmToken == null || fcmToken.isEmpty) return;

    // save locally for notifications
    await NotificationService.instance.saveFcmToken(fcmToken);

    await _dio.put(
      BasoodEndpoints.user.registerFcmToken,
      data: {'fcmToken': fcmToken},
      options: Options(
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ),
    );

    // listen once for refresh
    _fcmRefreshSub ??= _fcm.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;

      await NotificationService.instance.saveFcmToken(newToken);

      await _dio.put(
        BasoodEndpoints.user.registerFcmToken,
        data: {'fcmToken': newToken},
        options: Options(
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
        ),
      );
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    await _sendFcmToApi(args[0]);
                  },
                );
              },
              onLoadStart: (_, __) {
                setState(() => _loading = true);
              },
              onLoadStop: (_, url) async {
                _refresh?.endRefreshing();
                setState(() => _loading = false);

                if (url != null && url.path.contains('/login')) {
                  await _injectLoginInterceptorJS();
                }
              },
              androidOnPermissionRequest: (_, __, res) async =>
                  PermissionRequestResponse(
                    resources: res,
                    action: PermissionRequestResponseAction.GRANT,
                  ),
            ),

            if (_loading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fcmRefreshSub?.cancel();
    super.dispose();
  }
}
