import 'dart:async';
import 'package:mobishop_store_app/core/commerce/currency_minor_units.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_catalog_client.dart';
import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/core/network/public_catalog_cache.dart';
import 'package:mobishop_store_app/core/live_updates/store_change_bus.dart';
import 'package:mobishop_store_app/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:mobishop_store_app/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:mobishop_store_app/features/catalog/data/repositories/odoo_catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/data/repositories/shopify_catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/data/odoo/odoo_catalog_gateway.dart';
import 'package:mobishop_store_app/features/catalog/data/shopify/shopify_catalog_gateway.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';

/// The catalog's transport boundary.
///
/// Tests and store-specific shells can override this provider without replacing
/// any presentation code. No WooCommerce credentials are embedded in the app:
/// the public Store API is always scoped to [AppConfig.apiBaseUrl].
final catalogDioProvider = Provider<Dio>((Ref ref) {
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

final catalogStoreApiClientProvider = Provider<StoreApiClient>((Ref ref) {
  final cache = PublicCatalogCache(
    DioStoreApiClient.forConfiguredStore(dio: ref.watch(catalogDioProvider)),
    store: AppConfig.apiBaseUrl,
  );
  final changes = ref
      .watch(storeCatalogChangeBusProvider)
      .catalogChanges
      .listen((_) => cache.invalidate());
  ref.onDispose(() => unawaited(changes.cancel()));
  return cache;
});

final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>(
  (Ref ref) =>
      StoreApiCatalogRemoteDataSource(ref.watch(catalogStoreApiClientProvider)),
);

/// Foreign platform events need their own verified revision source. This is
/// intentionally not wired to WordPress's /mobishop/v1/store-changes endpoint.
/// Until that source exists, manual direct reads work but no realtimeclaim.
final platformCatalogChangesProvider = Provider<Stream<int>>(
  (Ref ref) => const Stream<int>.empty(),
);

final shopifyCatalogReaderProvider = Provider<ShopifyStorefrontReader>((
  Ref ref,
) {
  final ShopifyStorefrontClient client = ShopifyStorefrontClient(
    connection: AppConfig.commerceConnection,
  );
  ref.onDispose(client.close);
  return client;
});

final odooCatalogReaderProvider = Provider<StoreApiClient>((Ref ref) {
  final OdooCatalogClient client = OdooCatalogClient(
    connection: AppConfig.commerceConnection,
  );
  ref.onDispose(client.close);
  return client;
});

final catalogRepositoryProvider = Provider<CatalogRepository>((Ref ref) {
  switch (AppConfig.commercePlatform) {
    case CommercePlatform.wooCommerce:
      // Default builds retain the original transport, exact paging andbus.
      final repository = CatalogRepositoryImpl(
        ref.watch(catalogRemoteDataSourceProvider),
        changes: ref.watch(storeCatalogChangeBusProvider).catalogChanges,
      );
      ref.onDispose(() => unawaited(repository.dispose()));
      return repository;
    case CommercePlatform.shopify:
      final ShopifyCatalogRepository repository = ShopifyCatalogRepository(
        gateway: ShopifyCatalogGateway(
          client: ref.watch(shopifyCatalogReaderProvider),
          currencyMinorUnits: commerceCurrencyMinorUnits,
          countryCode: AppConfig.buyerCountryCode.trim().isEmpty
              ? null
              : AppConfig.buyerCountryCode,
          languageCode: AppConfig.shopifyLanguageCode,
        ),
        changes: ref.watch(platformCatalogChangesProvider),
      );
      ref.onDispose(() => unawaited(repository.dispose()));
      return repository;
    case CommercePlatform.odoo:
      return OdooCatalogRepository(
        gateway: OdooCatalogGateway(
          reader: ref.watch(odooCatalogReaderProvider),
          connection: AppConfig.commerceConnection,
        ),
        changes: ref.watch(platformCatalogChangesProvider),
      );
  }
});
