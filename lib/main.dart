import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'presentation/app.dart';
import 'services/notification_service.dart';
import 'core/utils/file_logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.instance.showRemoteMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileLogger.init();

  // Capture all debugPrint output so FAB can show full logs
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.isNotEmpty) {
      FileLogger.log(message); // Logs to file + prints to console
    }
  };

  await Firebase.initializeApp();

  // REQUIRED for Android + iOS background notifications
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.instance.init();

  runApp(const ProviderScope(child: SupplyGoApp()));
}
