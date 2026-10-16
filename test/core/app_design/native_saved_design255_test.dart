import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/splash/presentation/splash_providers.dart';

class _Catalog extends Fake implements CatalogRepository {
  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async => CatalogPage(
    items: const [],
    page: 1,
    perPage: 20,
    totalItems: 0,
    totalPages: 1,
  );

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async => CatalogPage(
    items: const [],
    page: 1,
    perPage: 20,
    totalItems: 0,
    totalPages: 1,
  );
}

void main() {
  test(
    'native Woo uses the saved design; legacy Woo and CMS retain their source',
    () async {
      final container = ProviderContainer(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_Catalog()),
          homeRepositoryProvider.overrideWith(
            (ref) => throw StateError('Unexpected WordPress Home read'),
          ),
          cmsPageLayoutRemoteDataSourceProvider.overrideWith(
            (ref) => throw StateError('Unexpected WordPress page read'),
          ),
          homeDioProvider.overrideWith(
            (ref) => throw StateError('Unexpected WordPress branding read'),
          ),
        ],
      );
      addTearDown(container.dispose);
      if (AppConfig.isCmsPreview || AppConfig.appDesignBundle.isEmpty) {
        expect(container.read(portableAppDesign58Provider), isNull);
        return;
      }
      final design = container.read(portableAppDesign58Provider)!;
      final home = await container.read(
        homeLayoutProvider(AppConfig.storeLocale).future,
      );
      expect(home.blocks, isNotEmpty);
      expect(
        home.blocks.length,
        (design.toJson()['home']['blocks'] as List).length,
      );
      expect(container.read(applicationIdentity58Provider), design.identity);
      expect(
        (await container.read(splashConfigProvider.future)).duration,
        design.splash.duration,
      );
      for (final page in [
        'home',
        'category',
        'catalog',
        'product',
        'wishlist',
        'account',
      ]) {
        final actual = await container.read(cmsPageLayoutProvider(page).future);
        expect(actual.settings, design.pageLayout(page).settings);
      }
    },
  );
}
