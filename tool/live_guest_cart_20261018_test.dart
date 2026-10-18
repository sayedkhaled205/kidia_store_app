import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_api_transport.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/cart_repository_impl.dart';

void main() {
  test(
    'fresh guest cart returns its new count in add-item response without opening cart',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      final container = ProviderContainer();
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );
      final repo = CartRepositoryImpl(
        StoreApiCartRemoteDataSource(
          storeApiClient: DioStoreApiClient.forConfiguredStore(dio: dio),
          transport: StoreApiCartTransport.forConfiguredStore(dio: dio),
        ),
      );
      String? key;
      try {
        expect(Uri.parse(AppConfig.apiBaseUrl).host, 'staging.kidiastore.com');
        final page = await container
            .read(catalogRepositoryProvider)
            .getProducts(CatalogProductQuery(perPage: 30));
        final product = page.items.firstWhere(
          (p) => p.type == 'simple' && p.isInStock && p.isPurchasable,
        );
        final initial = await repo.getCart();
        expect(
          initial.itemsCount,
          0,
          reason: 'Never mutate an existing customer basket.',
        );
        final added = await repo.addItem(productId: product.id);
        key = added.items.singleWhere((i) => i.productId == product.id).key;
        expect(added.itemsCount, 1);
        print('LIVE_CART_VERIFIED initial=0 immediate_add_response=1');
        final cleaned = await repo.removeItem(key!);
        key = null;
        expect(cleaned.itemsCount, 0);
        print('LIVE_CART_CLEANED count=0');
      } finally {
        if (key != null) await repo.removeItem(key!);
        dio.close(force: true);
        container.dispose();
        HttpOverrides.global = previous;
      }
    },
    skip: Platform.environment['WOOMOBILE_LIVE_CART_TEST'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
