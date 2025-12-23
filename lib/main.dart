import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'presentation/app.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'core/utils/file_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileLogger.init();

  FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp();
  await NotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: SupplyGoApp(),
    ),
  );
}
