import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/data/cms_preview_auth_actions.dart';
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
) async {
  final actions = ref.watch(nativeAuthActionsProvider);
  // The editor must reflect changed capabilities on every preview visit.
  if (AppConfig.isCmsPreview || actions is CmsPreviewAuthActions) {
    return actions.config();
  }
  // A first-frame prefetch must survive until the login screen subscribes.
  // Retain only this merchant's public capabilities, never an OTP or session.
  final cache = ref.keepAlive();
  Timer? expiry;
  ref.onDispose(() => expiry?.cancel());
  try {
    final config = await actions.config();
    if (ref.mounted) {
      expiry = Timer(const Duration(minutes: 5), cache.close);
    }
    return config;
  } catch (_) {
    cache.close();
    rethrow;
  }
}, retry: (retryCount, error) => null);
