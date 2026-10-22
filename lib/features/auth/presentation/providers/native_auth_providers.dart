import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_service.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'auth_providers.dart';

final nativeAuthActionsProvider = Provider.autoDispose<NativeAuthActions>((
  ref,
) {
  AppConfig.requireWooCommerceCustomerTransport('authentication');
  AppConfig.validateStoreConnection();
  final actions = NativeAuthService(
    storeUri: Uri.parse(AppConfig.apiBaseUrl.trim()),
    dio: ref.watch(authDioProvider),
    sdk: FirebaseNativeAuthSdk(),
    sessionStore: ref.watch(authSessionStoreProvider),
    legacyTransport: ref.watch(authApiTransportProvider),
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    onCommitted: (session) async {
      await ref.read(authControllerProvider.future);
      if (ref.mounted) {
        ref.read(authControllerProvider.notifier).acceptNativeSession(session);
      }
    },
  );
  ref.onDispose(actions.cancel);
  return actions;
});

final nativeAuthConfigProvider = FutureProvider.autoDispose<NativeAuthConfig>((
  ref,
) {
  return ref.watch(nativeAuthActionsProvider).config();
});
