import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/auth/application/auth_controller.dart';
import 'package:kidia_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:kidia_store_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kidia_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';

final authDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final authApiTransportProvider = Provider<AuthApiTransport>((Ref ref) {
  return DioAuthApiTransport.forConfiguredStore(dio: ref.watch(authDioProvider));
});

final authSessionStoreProvider = Provider<AuthSessionStore>((Ref ref) {
  return SecureAuthSessionStore.forConfiguredStore();
});

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepositoryImpl(
    transport: ref.watch(authApiTransportProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
  );
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(
      AuthController.new,
      retry: (int retryCount, Object error) => null,
    );
