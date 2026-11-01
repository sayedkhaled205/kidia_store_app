import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/home/data/home_image_prefetch.dart';
import 'package:mobishop_store_app/features/home/presentation/providers/home_providers.dart';

import '../../../core/app_design/app_design_fixture58.dart';

class _PendingCatalog implements CatalogRepository {
  final pending = Completer<CatalogPage<CatalogProduct>>();
  @override
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query) =>
      pending.future;
  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async => const CatalogPage(
    items: <CatalogCategory>[],
    page: 1,
    perPage: 6,
    totalItems: 0,
    totalPages: 0,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'images start before catalog hydration completes and do not block it',
    () async {
      final fixture = appDesignFixture58();
      final home = fixture['home'] as Map<String, dynamic>;
      (home['blocks'] as List).insert(0, {
        'id': 'static-banner',
        'type': 'image_banner',
        'enabled': true,
        'data': {
          'image_url': '$appDesignOrigin58/banner.webp',
          'aspect_ratio': 2.35,
        },
      });
      final design = AppDesignBundle58.fromEncoded(
        appDesignRawEncoded58(fixture),
        platform: CommercePlatform.odoo,
        storeOrigin: Uri.parse(appDesignOrigin58),
      );
      final catalog = _PendingCatalog();
      final image = Completer<void>();
      final started = <String>[];
      final container = ProviderContainer(
        overrides: [
          portableAppDesign58Provider.overrideWithValue(design),
          catalogRepositoryProvider.overrideWithValue(catalog),
          homeImageDownloadProvider.overrideWithValue((url) {
            started.add(url);
            return image.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(homeLayoutProvider('ar'), (_, _) {});
      addTearDown(sub.close);
      final loaded = container.read(homeLayoutProvider('ar').future);
      expect(started, contains('$appDesignOrigin58/banner.webp'));
      expect(catalog.pending.isCompleted, isFalse);
      catalog.pending.complete(
        const CatalogPage(
          items: <CatalogProduct>[],
          page: 1,
          perPage: 8,
          totalItems: 0,
          totalPages: 0,
        ),
      );
      expect((await loaded).blocks, isNotEmpty);
      expect(
        image.isCompleted,
        isFalse,
        reason: 'Slow imagery must not hold Home hydration',
      );
      image.complete();
    },
  );

  test(
    'prefetch is bounded, deduplicated, failure tolerant and cancellable',
    () async {
      final pending = <Completer<void>>[];
      final urls = <String>[];
      final prefetch = HomeImagePrefetch((url) {
        urls.add(url);
        final request = Completer<void>();
        pending.add(request);
        return request.future;
      });
      prefetch.add(List.generate(8, (i) => 'https://images.example/$i.webp'));
      prefetch.add(['https://images.example/0.webp']);
      expect(urls.length, 4);
      pending.first.completeError(StateError('Image unavailable'));
      await pumpEventQueue();
      expect(urls.length, 5);
      prefetch.close();
      for (final request in pending.skip(1)) {
        request.complete();
      }
      await pumpEventQueue();
      expect(urls.length, 5);
    },
  );

  test(
    'only static enabled imagery warms the cache, later hero slides last',
    () {
      Map<String, dynamic> block(
        String type,
        Map<String, dynamic> data, {
        bool enabled = true,
        bool catalog = false,
      }) => {
        'type': type,
        'enabled': enabled,
        'data': data,
        if (catalog) 'catalog_query': {},
      };
      final urls = staticHomeImageUrls({
        'blocks': [
          block('hero_slider', {
            'items': [
              {'image_url': 'first'},
              {'image_url': 'later'},
            ],
          }),
          block('quick_links', {
            'items': [
              {'image_url': 'circle'},
            ],
          }),
          block('image_banner', {'image_url': 'hidden'}, enabled: false),
          block('category_grid', {
            'items': [
              {'image_url': 'dynamic'},
            ],
          }, catalog: true),
          block('image_banner', {'image_url': 'banner'}),
        ],
      }).toList();
      expect(urls, ['first', 'circle', 'banner', 'later']);
    },
  );
}
