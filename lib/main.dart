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
  
  // Initialize file logger first
  await FileLogger.init();
  await FileLogger.log('🚀 ========== APP STARTING ==========');
  
  // Register background message handler before Firebase initialization
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FileLogger.log('✅ Background message handler registered');
  
  // Initialize Firebase and Notification Service in parallel for better performance
  await FileLogger.log('📦 Initializing Firebase and Notification Service...');
  await Future.wait([
    Firebase.initializeApp(),
    NotificationService.instance.init(),
  ]);
  await FileLogger.log('✅ Firebase and Notification Service initialized');

  runApp(
    const ProviderScope(
      child: SupplyGoApp(),
    ),
  );
}