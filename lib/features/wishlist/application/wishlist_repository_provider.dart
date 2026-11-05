import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_preferences_wishlist_repository.dart';
import '../domain/repositories/wishlist_repository.dart';
import '../data/customer_wishlist_repository.dart';

import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  if (!AppConfig.isCmsPreview &&
      AppConfig.commercePlatform == CommercePlatform.wooCommerce) {
    final session = ref.watch(authControllerProvider).value;
    if (session != null && !session.isExpired) {
      final expectedToken = session.token;
      return CustomerWishlistRepository(
        DioCustomerAccountApiTransport(
          storeUri: Uri.parse(AppConfig.apiBaseUrl.trim()),
          dio: ref.watch(authDioProvider),
          authTokenReader: () {
            if (!ref.mounted) return null;
            final current = ref.read(authControllerProvider).value;
            return current != null &&
                    !current.isExpired &&
                    current.token == expectedToken
                ? current.token
                : null;
          },
        ),
        deviceRepository:
            SharedPreferencesWishlistRepository.forConfiguredStore(),
      );
    }
  }
  return SharedPreferencesWishlistRepository.forConfiguredStore();
});
