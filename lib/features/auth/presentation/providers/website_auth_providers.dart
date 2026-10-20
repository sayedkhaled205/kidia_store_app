import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/auth/data/website_auth_service.dart';
import 'auth_providers.dart';

final websiteAuthServiceProvider = Provider<WebsiteAuthService>((ref) {
  AppConfig.requireWooCommerceCustomerTransport('website authentication');
  return WebsiteAuthService(
    store: Uri.parse(AppConfig.apiBaseUrl),
    dio: ref.watch(authDioProvider),
    sessions: ref.watch(authSessionStoreProvider),
  );
});

final websiteAuthEnabledProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb ||
      AppConfig.isCmsPreview ||
      !AppConfig.hasConfiguredStore ||
      AppConfig.commercePlatform != CommercePlatform.wooCommerce ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return false;
  }
  return ref.watch(websiteAuthServiceProvider).enabled();
});
