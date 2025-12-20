import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

import '../../core/config/env.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/refresh_interceptor.dart';
import '../../infrastructure/datasources/auth_remote_ds.dart';
import '../../infrastructure/datasources/driver_remote_ds.dart';
import '../../infrastructure/datasources/supplier_remote_ds.dart';
import '../../infrastructure/datasources/dashboard_remote_ds.dart';
import '../../infrastructure/datasources/notification_remote_ds.dart';
import '../../infrastructure/repositories_impl/auth_repository_impl.dart';
import '../../infrastructure/repositories_impl/driver_repository_impl.dart';
import '../../infrastructure/repositories_impl/supplier_repository_impl.dart';
import '../../infrastructure/repositories_impl/dashboard_repository_impl.dart';
import '../../infrastructure/repositories_impl/notification_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/notification_repository.dart';

// Storage
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// Token providers
final accessTokenProvider = StateProvider<String?>((ref) => null);
final refreshTokenProvider = StateProvider<String?>((ref) => null);

// Token provider function
final tokenProvider = Provider<Future<String?> Function()>((ref) {
  return () async => ref.read(accessTokenProvider.notifier).state;
});

// Refresh handler
final refreshHandlerProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    try {
      // Get the refresh token
      final refreshToken = ref.read(refreshTokenProvider.notifier).state;
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      // Create a separate Dio instance for refresh to avoid circular dependency
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: Env.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $refreshToken',
          },
        ),
      );

      final authDS = AuthRemoteDS(refreshDio);
      final authRepo = AuthRepositoryImpl(authDS);
      final newTokens = await authRepo.refreshToken();
      if (newTokens != null) {
        ref.read(accessTokenProvider.notifier).state = newTokens.accessToken;
        ref.read(refreshTokenProvider.notifier).state = newTokens.refreshToken;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  };
});

// Interceptors
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(ref.read(tokenProvider));
});

final refreshInterceptorProvider = Provider<RefreshInterceptor>((ref) {
  return RefreshInterceptor(ref.read(refreshHandlerProvider));
});

// Dio client
final dioProvider = Provider<Dio>((ref) {
  final client = DioClient();
  return client.create(
    authInterceptor: ref.read(authInterceptorProvider),
    refreshInterceptor: ref.read(refreshInterceptorProvider),
  );
});

// Data sources
final authRemoteDSProvider = Provider<AuthRemoteDS>((ref) {
  return AuthRemoteDS(ref.read(dioProvider));
});

final driverRemoteDSProvider = Provider<DriverRemoteDS>((ref) {
  return DriverRemoteDS(ref.read(dioProvider));
});

final supplierRemoteDSProvider = Provider<SupplierRemoteDS>((ref) {
  return SupplierRemoteDS(ref.read(dioProvider));
});

final dashboardRemoteDSProvider = Provider<DashboardRemoteDS>((ref) {
  return DashboardRemoteDS(ref.read(dioProvider));
});

final notificationRemoteDSProvider = Provider<NotificationRemoteDS>((ref) {
  return NotificationRemoteDS(ref.read(dioProvider));
});

// Repositories
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(authRemoteDSProvider));
});

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepositoryImpl(ref.read(driverRemoteDSProvider));
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepositoryImpl(ref.read(supplierRemoteDSProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.read(dashboardRemoteDSProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.read(notificationRemoteDSProvider));
});
