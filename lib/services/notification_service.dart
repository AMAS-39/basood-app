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
  
  // Track shown notification IDs to prevent duplicates
  static final Set<String> _shownNotificationIds = {};
  
  // Global navigator key for handling notification taps
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
    if (_initialized) {
      FileLogger.log('⏭️ NotificationService already initialized, skipping');
      return;
    }

    FileLogger.log('📦 ========== INITIALIZING NOTIFICATION SERVICE ==========');

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    FileLogger.log('   Initializing flutter_local_notifications plugin...');
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    FileLogger.log('✅ flutter_local_notifications plugin initialized');

    FileLogger.log('   Creating Android notification channel: ${_defaultChannel.id}');
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_defaultChannel);
    FileLogger.log('✅ Android notification channel created: ${_defaultChannel.id}');

    _initialized = true;
    FileLogger.log('✅ NotificationService initialization completed');
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    FileLogger.log('🔔 ========== showRemoteMessage CALLED ==========');
    try {
      if (!_initialized) {
        FileLogger.log('   Notification service not initialized, initializing now...');
        await init();
      }

      // Generate unique notification ID from messageId or timestamp
      final messageId = message.messageId ?? 
                       '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';
      
      // Check if this notification was already shown (prevent duplicates)
      if (_shownNotificationIds.contains(messageId)) {
        FileLogger.log('⏭️ Notification already shown (ID: $messageId) - skipping duplicate');
        return;
      }
      
      // Mark as shown
      _shownNotificationIds.add(messageId);
      // Keep only last 100 IDs to prevent memory issues
      if (_shownNotificationIds.length > 100) {
        final oldestId = _shownNotificationIds.first;
        _shownNotificationIds.remove(oldestId);
      }

      final notification = message.notification;
      FileLogger.log('   Notification object: ${notification != null ? "exists" : "null"}');
      FileLogger.log('   Notification title: ${notification?.title ?? "null"}');
      FileLogger.log('   Notification body: ${notification?.body ?? "null"}');
      FileLogger.log('   Message data: ${message.data}');
      FileLogger.log('   Message ID: $messageId');
      
      final title = notification?.title ?? message.data['title'] ?? 'Basood';
      final body = notification?.body ?? message.data['body'] ?? 'You have a new notification';

      // Don't show generic "You have a new notification" if we have actual data
      if (title == 'Basood' && body == 'You have a new notification' && message.data.isNotEmpty) {
        FileLogger.log('⚠️ Using generic fallback text, but data payload exists: ${message.data}');
      }
      
      FileLogger.log('   Final title: $title');
      FileLogger.log('   Final body: $body');

      FileLogger.log('   Creating Android notification details...');
      FileLogger.log('     Channel ID: ${_defaultChannel.id}');
      FileLogger.log('     Channel name: ${_defaultChannel.name}');
      final androidDetails = AndroidNotificationDetails(
        _defaultChannel.id,
        _defaultChannel.name,
        channelDescription: _defaultChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher', // Will use app launcher icon
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Large icon for expanded view
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

      // Use a hash of messageId for notification ID (must be int)
      final notificationId = messageId.hashCode.abs() % 2147483647; // Keep within int32 range
      FileLogger.log('   Calling plugin.show() with:');
      FileLogger.log('     Notification ID: $notificationId (from messageId: $messageId)');
      FileLogger.log('     Title: $title');
      FileLogger.log('     Body: $body');
      FileLogger.log('     Channel ID: ${_defaultChannel.id}');

      await _plugin.show(
        notificationId,
        title,
        body,
        details,
        payload: message.data.isNotEmpty ? message.data.toString() : null,
      );
      
      FileLogger.log('✅ Notification plugin.show() called successfully (ID: $notificationId, MessageID: $messageId)');
    } catch (e, stackTrace) {
      FileLogger.log('❌ Error in showRemoteMessage: $e');
      FileLogger.log('   Stack trace: $stackTrace');
      debugPrint('❌ Error showing notification: $e');
      // Don't throw - notifications should not crash the app
    }
  }

  void handleNotificationTap(RemoteMessage message) {
    FileLogger.log('📱 ========== NOTIFICATION TAPPED ==========');
    FileLogger.log('   Title: ${message.notification?.title ?? "N/A"}');
    FileLogger.log('   Body: ${message.notification?.body ?? "N/A"}');
    try {
      debugPrint('📱 Notification tapped: ${message.notification?.title}');
      
      // Trigger WebView refresh via a static callback
      // This will refresh the WebView if it's currently displayed
      Future.microtask(() {
        try {
          FileLogger.log('   Calling notification tap callback...');
          _onNotificationTapped?.call();
          FileLogger.log('✅ Notification tap callback executed');
        } catch (e) {
          FileLogger.log('❌ Error calling notification tap callback: $e');
          debugPrint('❌ Error calling notification tap callback: $e');
        }
      });
    } catch (e) {
      FileLogger.log('❌ Error handling notification tap: $e');
      debugPrint('❌ Error handling notification tap: $e');
    }
  }
  
  // Callback for WebView refresh when notification is tapped
  static VoidCallback? _onNotificationTapped;
  
  static void setNotificationTapCallback(VoidCallback? callback) {
    _onNotificationTapped = callback;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    FileLogger.log('📱 ========== LOCAL NOTIFICATION RESPONSE ==========');
    FileLogger.log('   Action ID: ${response.actionId}');
    FileLogger.log('   Payload: ${response.payload}');
    FileLogger.log('   Input: ${response.input}');
    try {
      debugPrint('📱 Local notification clicked with payload: ${response.payload}');
      // Refresh WebView or navigate if needed
      // Navigate to WebView screen if not already there
      if (navigatorKey?.currentState != null) {
        FileLogger.log('   Navigator key is available');
        // The app will handle navigation
      } else {
        FileLogger.log('   Navigator key is null');
      }
      FileLogger.log('✅ Notification response handled');
    } catch (e) {
      FileLogger.log('❌ Error handling notification response: $e');
      debugPrint('❌ Error handling notification response: $e');
    }
  }
}
