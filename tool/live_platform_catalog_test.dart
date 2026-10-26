// Opt-in, read-only buyer API smoke test. No identity, order or payment writes.
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';

void main() {
  test(
    'configured live buyer catalog preserves products, categories and prices',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      final container = ProviderContainer();
      addTearDown(() {
        container.dispose();
        HttpOverrides.global = previous;
      });
      final repository = container.read(catalogRepositoryProvider);
      final page = await repository.getProducts(
        CatalogProductQuery(perPage: 5),
      );
      expect(page.items, isNotEmpty);
      expect(page.items.map((p) => p.id).toSet().length, page.items.length);
      final detail = await repository.getProduct(page.items.first.id);
      expect(detail.id, page.items.first.id);
      expect(detail.prices.currencyCode, isNotEmpty);
      final categories = await repository.getCategories(
        CatalogCategoryQuery(perPage: 20),
      );
      expect(
        categories.items.map((p) => p.id).toSet().length,
        categories.items.length,
      );
      // Only public counts and platform identity, never tokens/customer records.
      // ignore: avoid_print
      print(
        'LIVE_CATALOG_PASS platform=${AppConfig.commercePlatform.name} products=${page.items.length} categories=${categories.items.length} currency=${detail.prices.currencyCode}',
      );
    },
    skip: !const bool.fromEnvironment('ALLOW_LIVE_CATALOG'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
