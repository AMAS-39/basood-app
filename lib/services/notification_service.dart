import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ================= FCM STORAGE =================
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> saveFcmToken(String token) async {
    _fcmToken = token;
  }

  // ================= NAVIGATION =================
  static GlobalKey<NavigatorState>? navigatorKey;
  static VoidCallback? _onNotificationTapped;

  static void setNotificationTapCallback(VoidCallback? callback) {
    _onNotificationTapped = callback;
  }

  // ================= DUPLICATE PROTECTION =================
  static final Set<String> _shownNotificationIds = {};

  // ================= CHANNEL =================
  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        'basood_notifications',
        'Basood Notifications',
        description: 'General alerts and updates from Basood',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  // ================= INIT =================
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_defaultChannel);

    _initialized = true;
    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showRemoteMessage(message);
    });

    // Get token (required for backend)
    final token = await messaging.getToken();
    if (token != null) {
      await saveFcmToken(token);
    }
  }

  // ================= SHOW NOTIFICATION =================
  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (!_initialized) await init();

    final messageId =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (_shownNotificationIds.contains(messageId)) return;
    _shownNotificationIds.add(messageId);

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Basood';

    final body =
        message.notification?.body ??
        message.data['body'] ??
        'New notification';

    final androidDetails = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      messageId.hashCode.abs(),
      title,
      body,
      details,
      payload: message.data.toString(),
    );
  }

  // ================= NOTIFICATION TAP =================
  void handleNotificationTap(RemoteMessage message) {
    _onNotificationTapped?.call();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _onNotificationTapped?.call();
  }
}
