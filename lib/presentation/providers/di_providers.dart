import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

import '../../core/config/env.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/refresh_interceptor.dart';
import '../../infrastructure/datasources/auth_remote_ds.dart';
import '../../infrastructure/repositories_impl/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

// Storage - unified iOS options for token persistence (KeychainAccessibility.first_unlock)
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
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

// Repositories
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(authRemoteDSProvider));
});
