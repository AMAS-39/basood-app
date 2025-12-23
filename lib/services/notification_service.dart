import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/utils/file_logger.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static final Set<String> _shownNotificationIds = {};
  static GlobalKey<NavigatorState>? navigatorKey;

  static const AndroidNotificationChannel _defaultChannel =
  AndroidNotificationChannel(
    'basood_notifications',
    'Basood Notifications',
    description: 'General alerts and updates from Basood',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultChannel);

    _initialized = true;
    FileLogger.log('✅ NotificationService initialized');
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (!_initialized) await init();

    final messageId =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (_shownNotificationIds.contains(messageId)) return;
    _shownNotificationIds.add(messageId);

    final title = message.notification?.title ??
        message.data['title'] ??
        'Basood';
    final body = message.notification?.body ??
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
      largeIcon:
      const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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

  void handleNotificationTap(RemoteMessage message) {
    _onNotificationTapped?.call();
  }

  static VoidCallback? _onNotificationTapped;

  static void setNotificationTapCallback(VoidCallback? callback) {
    _onNotificationTapped = callback;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    FileLogger.log('📱 Notification clicked: ${response.payload}');
  }
}
