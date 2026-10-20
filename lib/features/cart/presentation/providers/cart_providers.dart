import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/core/commerce/shopify_checkout_policy297.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_api_transport.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/shopify_cart_repository.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_buyer_cart_session.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_gateway.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_session_store.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_variant_resolver.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';

/// One configured Dio client is shared by the Store API bootstrap request and
/// token-authenticated cart requests for the lifetime of the provider scope.
final cartDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final cartStoreUriProvider = Provider<Uri>((Ref ref) {
  AppConfig.requireWooCommerceCustomerTransport('cart');
  AppConfig.validateStoreConnection();
  return Uri.parse(AppConfig.apiBaseUrl.trim());
});

final cartStoreApiClientProvider = Provider<StoreApiClient>((Ref ref) {
  return DioStoreApiClient(
    storeUri: ref.watch(cartStoreUriProvider),
    dio: ref.watch(cartDioProvider),
  );
});

final cartApiTransportProvider = Provider.autoDispose<CartApiTransport>((
  Ref ref,
) {
  AppConfig.requireWooCommerceCustomerTransport('cart');
  final identity = ref.watch(
    authControllerProvider.select(
      (AsyncValue<AuthSession?> state) =>
          (state.value?.user.id, state.value?.token),
    ),
  );
  return StoreApiCartTransport(
    storeUri: ref.watch(cartStoreUriProvider),
    dio: ref.watch(cartDioProvider),
    authTokenReader: () => _currentSessionToken(ref, identity),
  );
});

final cartTokenStoreProvider = Provider<CartTokenStore>((Ref ref) {
  AppConfig.requireWooCommerceCustomerTransport('cart');
  final store = MemoryCartTokenStore();
  ref.listen<(int?, String?)>(
    authControllerProvider.select(
      (AsyncValue<AuthSession?> state) =>
          (state.value?.user.id, state.value?.token),
    ),
    (previous, next) {
      // Preserve an anonymous basket at login. A signed-in basket never belongs
      // to the next customer or an anonymous session after logout.
      if (previous?.$2 != null &&
          (next.$2 == null || previous?.$1 != next.$1)) {
        store.clear();
      }
    },
  );
  ref.onDispose(store.clear);
  return store;
});

final cartRemoteDataSourceProvider = Provider.autoDispose<CartRemoteDataSource>(
  (Ref ref) {
    AppConfig.requireWooCommerceCustomerTransport('cart');
    final identity = ref.watch(
      authControllerProvider.select(
        (AsyncValue<AuthSession?> state) =>
            (state.value?.user.id, state.value?.token),
      ),
    );
    return StoreApiCartRemoteDataSource(
      storeApiClient: ref.watch(cartStoreApiClientProvider),
      transport: ref.watch(cartApiTransportProvider),
      tokenStore: ref.watch(cartTokenStoreProvider),
      currentSessionToken: () => _currentSessionToken(ref, identity),
      isCurrentSession: () => _isCurrentSession(ref, identity),
    );
  },
);

final cartRepositoryProvider = Provider.autoDispose<CartRepository>((Ref ref) {
  if (AppConfig.commercePlatform == CommercePlatform.shopify) {
    final session = ref.watch(shopifyBuyerCartSessionProvider);
    final transport = ref.watch(shopifyCartTransportProvider);
    final ShopifyCartRepository repository = ShopifyCartRepository(
      gateway: ShopifyCartGateway(
        transport: transport,
        connection: AppConfig.commerceConnection,
        checkoutPolicy: ref.watch(shopifyCheckoutPolicy297Provider),
        countryCode: AppConfig.buyerCountryCode.trim().isEmpty
            ? null
            : AppConfig.buyerCountryCode,
        languageCode: AppConfig.shopifyLanguageCode,
      ),
      session: session,
      variantResolver: ShopifyCartVariantResolver(reader: transport),
      connection: AppConfig.commerceConnection,
      isCurrentSession: () =>
          ref.mounted && session.belongsTo(AppConfig.commerceConnection),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return CartRepositoryImpl(ref.watch(cartRemoteDataSourceProvider));
});

/// Deliberately separate from Woo Dio, Cart-Token, auth restoration and builder
/// analytics. No private/customer/admin token can be supplied by these providers.
final shopifyCartTransportProvider = Provider<ShopifyStorefrontCartTransport>((
  Ref ref,
) {
  if (AppConfig.commercePlatform != CommercePlatform.shopify) {
    throw const AppConfigurationException(
      'Shopify guest cart requires STORE_PLATFORM=shopify.',
    );
  }
  final client = ShopifyStorefrontClient(
    connection: AppConfig.commerceConnection,
  );
  ref.onDispose(client.close);
  return client;
});

final shopifyCheckoutPolicy297Provider = Provider<ShopifyCheckoutPolicy297>((
  ref,
) {
  return ShopifyCheckoutPolicy297(
    connection: AppConfig.commerceConnection,
    reader: ref.watch(shopifyCartTransportProvider),
  );
});

final shopifyBuyerCartSessionProvider = Provider<ShopifyBuyerCartSession>((
  Ref ref,
) {
  if (AppConfig.commercePlatform != CommercePlatform.shopify) {
    throw const AppConfigurationException(
      'Shopify guest cart requires STORE_PLATFORM=shopify.',
    );
  }
  final session = ShopifyBuyerCartSession(
    AppConfig.commerceConnection,
    storage: ref.watch(shopifyCartSessionStoreProvider),
  );
  ref.onDispose(session.dispose);
  return session;
});

final shopifyCartSessionStoreProvider = Provider<ShopifyCartSessionStore>((
  Ref ref,
) {
  if (AppConfig.commercePlatform != CommercePlatform.shopify) {
    throw const AppConfigurationException(
      'Shopify guest storage requires STORE_PLATFORM=shopify.',
    );
  }
  return SecureShopifyCartSessionStore(
    connection: AppConfig.commerceConnection,
  );
});

bool _isCurrentSession(Ref ref, (int?, String?) identity) {
  if (!ref.mounted) return false;
  final session = ref.read(authControllerProvider).value;
  return session == null
      ? identity.$1 == null && identity.$2 == null
      : !session.isExpired &&
            session.user.id == identity.$1 &&
            session.token == identity.$2;
}

String? _currentSessionToken(Ref ref, (int?, String?) identity) {
  if (!_isCurrentSession(ref, identity)) return null;
  if (!ref.mounted) return null;
  final session = ref.read(authControllerProvider).value;
  return session == null || session.isExpired ? null : session.token;
}
