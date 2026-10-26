import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';

import 'app_design_fixture58.dart';

AppDesignBundle58 _parse(
  Map<String, dynamic> fixture, {
  CommercePlatform platform = CommercePlatform.odoo,
  String origin = appDesignOrigin58,
}) => AppDesignBundle58.fromEncoded(
  appDesignRawEncoded58(fixture),
  platform: platform,
  storeOrigin: Uri.parse(origin),
);

String _produce(
  Map<String, dynamic> fixture, {
  Map<String, Map<String, dynamic>> queries = const {},
}) => encodeSavedAppDesign58(
  platform: CommercePlatform.odoo,
  storeOrigin: Uri.parse(appDesignOrigin58),
  identity: appDesignMap58(fixture['identity']),
  splash: appDesignMap58(fixture['splash']),
  home: appDesignMap58(fixture['home']),
  pages: appDesignMap58(fixture['pages']),
  catalogQueries: queries,
);

CatalogProduct _product(
  int id, {
  String name = 'Live product',
  String priceMinor = '12345',
  String regularPriceMinor = '15000',
  bool inStock = true,
  bool withImage = true,
  bool withThumbnail = false,
}) => CatalogProduct(
  id: id,
  name: '$name $id',
  slug: 'live-$id',
  type: 'simple',
  prices: CatalogMoney(
    currencyCode: 'EGP',
    currencySymbol: 'EGP',
    currencyMinorUnit: 2,
    priceMinor: priceMinor,
    regularPriceMinor: regularPriceMinor,
  ),
  isPurchasable: true,
  isInStock: inStock,
  stockStatus: inStock
      ? CatalogStockStatus.inStock
      : CatalogStockStatus.outOfStock,
  images: withImage
      ? <CatalogImage>[
          CatalogImage(
            source: Uri.parse('$appDesignOrigin58/images/live-$id.png'),
            thumbnail: withThumbnail
                ? Uri.parse('$appDesignOrigin58/images/live-$id-300x300.png')
                : null,
          ),
        ]
      : const <CatalogImage>[],
);

class _Catalog implements CatalogRepository {
  final productQueries = <CatalogProductQuery>[];
  final categoryQueries = <CatalogCategoryQuery>[];
  final productIds = <int>[];
  List<CatalogProduct> products = <CatalogProduct>[_product(71)];
  List<CatalogCategory> categories = <CatalogCategory>[
    CatalogCategory(
      id: 9,
      name: 'Live category',
      slug: 'live-category',
      image: CatalogImage(
        source: Uri.parse('$appDesignOrigin58/images/category.png'),
      ),
    ),
  ];
  Object? failure;

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    productQueries.add(query);
    if (failure != null) throw failure!;
    return CatalogPage<CatalogProduct>(
      items: products.take(query.perPage).toList(growable: false),
      page: query.page,
      perPage: query.perPage,
      totalItems: products.length,
      totalPages: 1,
    );
  }

  @override
  Future<CatalogProduct> getProduct(int productId) async {
    productIds.add(productId);
    if (failure != null) throw failure!;
    return products.singleWhere((product) => product.id == productId);
  }

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async {
    categoryQueries.add(query);
    if (failure != null) throw failure!;
    return CatalogPage<CatalogCategory>(
      items: categories.take(query.perPage).toList(growable: false),
      page: query.page,
      perPage: query.perPage,
      totalItems: categories.length,
      totalPages: 1,
    );
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) =>
      throw UnsupportedError('Hydration must not create a variation request.');

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) => throw UnsupportedError('Hydration must not create a filter request.');
}

void main() {
  for (final platform in CommercePlatform.values) {
    test('saved $platform Home works in both app languages', () async {
      final fixture = appDesignFixture58()
        ..['platform'] = platform == CommercePlatform.wooCommerce
            ? 'woocommerce'
            : platform.name;
      final origin = platform == CommercePlatform.shopify
          ? 'https://design-fixture.myshopify.com'
          : appDesignOrigin58;
      fixture['store_origin'] = origin;
      final bundle = _parse(fixture, platform: platform, origin: origin);
      final repository = _Catalog();
      final arabic = await bundle.hydrateHome(repository, locale: 'ar');
      final english = await bundle.hydrateHome(repository, locale: 'en');
      expect(arabic.locale, 'ar');
      expect(english.locale, 'en');
      expect(
        english.blocks.map((block) => block.id),
        arabic.blocks.map((block) => block.id),
      );
      expect(
        english.blocks.whereType<TextBlock>().first.title,
        arabic.blocks.whereType<TextBlock>().first.title,
      );
      expect(
        english.blocks.whereType<ProductGridBlock>().single.items,
        isNotEmpty,
      );
      expect(
        english.blocks.whereType<CategoryGridBlock>().single.items,
        isNotEmpty,
      );
    });
  }
  test('selector83 preserves newest, root and ordered category IDs', () async {
    final fixture = appDesignFixture58();
    appDesignBlock58(fixture, 'saved-products')['catalog_query'] = {
      'kind': 'products',
      'mode': 'latest',
      'limit': 8,
      'sort': 'newest',
    };
    appDesignBlock58(fixture, 'saved-categories')['catalog_query'] = {
      'kind': 'categories',
      'mode': 'parent',
      'parent_id': 0,
      'hide_empty': false,
      'limit': 6,
      'sort': 'name',
    };
    final repository = _Catalog();
    await _parse(fixture).hydrateHome(repository, locale: 'ar');
    expect(repository.productQueries.single.sort, CatalogSort.newest);
    expect(repository.categoryQueries.single.parentId, 0);
    expect(repository.categoryQueries.single.hideEmpty, isFalse);
    appDesignBlock58(fixture, 'saved-categories')['catalog_query'] = {
      'kind': 'categories',
      'mode': 'ids',
      'ids': [8, 9],
      'hide_empty': false,
      'limit': 2,
      'sort': 'relevance',
    };
    repository.categories.add(
      const CatalogCategory(id: 8, name: 'Eight', slug: 'eight'),
    );
    final home = await _parse(fixture).hydrateHome(repository, locale: 'ar');
    expect(repository.categoryQueries.last.includeIds, [8, 9]);
    expect(
      home.blocks.whereType<CategoryGridBlock>().single.items.map((c) => c.id),
      [8, 9],
    );
    appDesignBlock58(fixture, 'saved-products')['catalog_query'] = {
      'kind': 'products',
      'mode': 'featured',
      'limit': 8,
      'sort': 'newest',
    };
    expect(() => _parse(fixture), throwsFormatException);
  });
  group('saved public design binding and security', () {
    test(
      'valid design retains exact identity, splash and every page chrome',
      () {
        final bundle = _parse(appDesignFixture58());
        expect(bundle.identity['app_name'], 'Kidia saved design');
        expect(bundle.identity['language'], 'ar');
        expect(bundle.identity['direction'], 'rtl');
        expect(bundle.identity['font_family'], 'noto_sans_arabic');
        expect(bundle.splash.imageUrl, '$appDesignOrigin58/assets/splash.png');
        expect(bundle.splash.duration, const Duration(milliseconds: 1250));
        expect(bundle.splash.imageWidth, 180);
        expect(bundle.splash.imageHeight, 150);
        expect(bundle.splash.backgroundColor, const Color(0xFF91AEBB));
        expect(bundle.splash.showLoader, isFalse);
        for (final page in const <String>[
          'home',
          'category',
          'catalog',
          'product',
          'size_chart',
          'wishlist',
          'account',
        ]) {
          final layout = bundle.pageLayout(page);
          expect(layout.page, page);
          expect(layout.enabled, isTrue);
          expect(layout.string('page_background_color', ''), '#EAF4F5');
          expect(layout.number('content_horizontal_padding', 0), 17);
          expect(layout.header.number('height', 0), 91);
          expect(layout.footer.number('height', 0), 74);
          expect(layout.footer.string('active_color', ''), '#4EA999');
          final rows = layout.header.json('layout_json')['rows'] as List;
          expect((rows.single as Map)['columns'], hasLength(1));
        }
      },
    );

    test(
      'platform and origin mismatches cannot reuse another store design',
      () {
        final fixture = appDesignFixture58();
        expect(
          () => _parse(fixture, platform: CommercePlatform.shopify),
          throwsFormatException,
        );
        expect(
          () => _parse(fixture, origin: 'https://foreign.example.invalid'),
          throwsFormatException,
        );
      },
    );

    for (final origin in const <String>[
      'http://odoo.example.invalid',
      'https://user:secret@odoo.example.invalid',
      'https://odoo.example.invalid/shop',
      'https://odoo.example.invalid?session_id=private',
      'https://odoo.example.invalid#private',
      'https://odoo.example.invalid:8443',
    ]) {
      test('rejects non-origin bundle binding $origin', () {
        final fixture = appDesignFixture58()..['store_origin'] = origin;
        expect(() => _parse(fixture), throwsFormatException);
      });
    }

    test('identity rejects a mutable credentials/session payload', () {
      for (final key in const <String>[
        'access_token',
        'session_id',
        'password',
        'customer',
      ]) {
        final fixture = appDesignFixture58();
        appDesignMap58(fixture['identity'])[key] = 'not-public';
        expect(() => _parse(fixture), throwsFormatException, reason: key);
      }
    });

    test(
      'page settings cannot embed account/order or cached catalog records',
      () {
        for (final key in const <String>[
          'customer',
          'orders',
          'products',
          'demo_catalog',
          'access_token',
        ]) {
          final fixture = appDesignFixture58();
          final page = appDesignMap58(
            appDesignMap58(fixture['pages'])['account'],
          );
          appDesignMap58(page['settings'])[key] = <String, dynamic>{
            'private': 'should-never-ship',
          };
          expect(() => _parse(fixture), throwsFormatException, reason: key);
        }
      },
    );

    test(
      'consumer refuses embedded product prices and stock in data.items',
      () {
        final fixture = appDesignFixture58();
        appDesignMap58(
          appDesignBlock58(fixture, 'saved-products')['data'],
        )['items'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 71,
            'name': 'Frozen product',
            'price': '1.00',
            'in_stock': true,
          },
        ];
        expect(() => _parse(fixture), throwsFormatException);
      },
    );

    test(
      'catalog selectors are mandatory and cannot be guessed from items',
      () {
        final fixture = appDesignFixture58();
        appDesignBlock58(fixture, 'saved-products').remove('catalog_query');
        expect(() => _parse(fixture), throwsFormatException);
      },
    );

    for (final mode in const <String>[
      'latest',
      'featured',
      'on_sale',
      'best_selling',
      'top_rated',
      'random',
    ]) {
      test('unsupported selector $mode cannot fall back to all products', () {
        final fixture = appDesignFixture58();
        final query = appDesignMap58(
          appDesignBlock58(fixture, 'saved-products')['catalog_query'],
        );
        query['mode'] = mode;
        expect(() => _parse(fixture), throwsFormatException);
      });
    }

    test('selector ignores neither unimplemented filter nor ordering', () {
      for (final field in const <String>[
        'on_sale',
        'featured',
        'brand_id',
        'minimum_price_minor',
      ]) {
        final fixture = appDesignFixture58();
        appDesignMap58(
          appDesignBlock58(fixture, 'saved-products')['catalog_query'],
        )[field] = true;
        expect(() => _parse(fixture), throwsFormatException, reason: field);
      }
      final fixture = appDesignFixture58();
      appDesignMap58(
        appDesignBlock58(fixture, 'saved-products')['catalog_query'],
      )['sort'] = 'popularity';
      expect(() => _parse(fixture), throwsFormatException);
    });

    test('category hierarchy/manual IDs are explicitly unsupported', () {
      final fixture = appDesignFixture58();
      appDesignMap58(
        appDesignBlock58(fixture, 'saved-categories')['catalog_query'],
      ).addAll(<String, dynamic>{
        'mode': 'ids',
        'ids': <int>[9],
      });
      expect(() => _parse(fixture), throwsFormatException);
    });

    test('query bounds do not silently broaden a requested selection', () {
      for (final limit in const <int>[0, -1, 101]) {
        final fixture = appDesignFixture58();
        appDesignMap58(
          appDesignBlock58(fixture, 'saved-products')['catalog_query'],
        )['limit'] = limit;
        expect(() => _parse(fixture), throwsFormatException);
      }
      final fixture = appDesignFixture58();
      appDesignMap58(
        appDesignBlock58(fixture, 'saved-products')['catalog_query'],
      ).addAll(<String, dynamic>{'mode': 'search', 'search': 'x' * 81});
      expect(() => _parse(fixture), throwsFormatException);
    });

    test(
      'Shopify saved selector rejects more than 20 list products at parse',
      () {
        final fixture = appDesignFixture58()
          ..['platform'] = 'shopify'
          ..['store_origin'] = 'https://design-fixture.myshopify.com';
        appDesignMap58(
          appDesignBlock58(fixture, 'saved-products')['catalog_query'],
        )['limit'] = 21;
        expect(
          () => _parse(
            fixture,
            platform: CommercePlatform.shopify,
            origin: 'https://design-fixture.myshopify.com',
          ),
          throwsFormatException,
        );
      },
    );

    test('malformed base64, JSON and schema are rejected', () {
      for (final encoded in <String>[
        'not-base64%%',
        base64Encode(utf8.encode('[]')),
        base64Encode(utf8.encode('{broken')),
      ]) {
        expect(
          () => AppDesignBundle58.fromEncoded(
            encoded,
            platform: CommercePlatform.odoo,
            storeOrigin: Uri.parse(appDesignOrigin58),
          ),
          throwsFormatException,
        );
      }
      final fixture = appDesignFixture58()..['schema_version'] = 2;
      expect(() => _parse(fixture), throwsFormatException);
    });

    test(
      'unknown dynamic block cannot disappear through permissive Home parser',
      () {
        final fixture = appDesignFixture58();
        appDesignBlock58(fixture, 'saved-products')['type'] =
            'merchant_private';
        expect(() => _parse(fixture), throwsFormatException);
      },
    );

    test(
      'identity is immutable and exported JSON cannot mutate saved design',
      () {
        final bundle = _parse(appDesignFixture58());
        expect(
          () => bundle.identity['app_name'] = 'Changed',
          throwsUnsupportedError,
        );
        final exported = bundle.toJson();
        try {
          appDesignMap58(exported['identity'])['app_name'] = 'Changed';
          final page = appDesignMap58(
            appDesignMap58(exported['pages'])['home'],
          );
          appDesignMap58(page['settings'])['page_background_color'] = '#000000';
        } on UnsupportedError {
          // An immutable export is also valid; it must not expose mutable state.
        }
        expect(bundle.identity['app_name'], 'Kidia saved design');
        expect(
          bundle.pageLayout('home').string('page_background_color', ''),
          '#EAF4F5',
        );
      },
    );

    test('public text containing colons is not treated as a URL', () async {
      final fixture = appDesignFixture58();
      appDesignMap58(
        appDesignBlock58(fixture, 'saved-heading')['data'],
      ).addAll(<String, dynamic>{
        'title': 'Delivery: next working day',
        'content': 'Note: public delivery terms only.',
      });
      final home = await _parse(fixture).hydrateHome(_Catalog(), locale: 'ar');
      expect(
        home.blocks.whereType<TextBlock>().single.title,
        'Delivery: next working day',
      );
    });

    test('nested credentials in serialized chrome JSON never ship', () {
      final fixture = appDesignFixture58();
      final page = appDesignMap58(appDesignMap58(fixture['pages'])['home']);
      final header = appDesignMap58(page['header']);
      appDesignMap58(header['settings'])['layout_json'] = jsonEncode(
        <String, dynamic>{
          'rows': <dynamic>[],
          'metadata': <String, dynamic>{'access_token': 'private-credential'},
        },
      );
      expect(() => _parse(fixture), throwsFormatException);
    });

    test(
      'public HTTPS media cannot contain URL credentials or secret query',
      () {
        for (final url in const <String>[
          'https://user:password@odoo.example.invalid/logo.png',
          '$appDesignOrigin58/logo.png?access_token=secret',
          '$appDesignOrigin58/logo.png?session_id=secret',
          'javascript:alert(1)',
          'file:///private/logo.png',
        ]) {
          final fixture = appDesignFixture58();
          appDesignMap58(fixture['identity'])['logo_url'] = url;
          expect(() => _parse(fixture), throwsFormatException, reason: url);
          appDesignMap58(fixture['identity'])['logo_url'] =
              '$appDesignOrigin58/assets/logo.png';
          appDesignMap58(fixture['splash'])['image_url'] = url;
          expect(() => _parse(fixture), throwsFormatException, reason: url);
        }
      },
    );

    test('splash proportions are optional for existing saved designs', () {
      final fixture = appDesignFixture58();
      expect(_parse(fixture).splash.imageAspectRatio, 0);
      appDesignMap58(fixture['splash'])['image_aspect_ratio'] = 3.2;
      expect(_parse(fixture).splash.imageAspectRatio, 3.2);
      for (final ratio in <dynamic>[-1, 11, '3.2', null]) {
        appDesignMap58(fixture['splash'])['image_aspect_ratio'] = ratio;
        expect(() => _parse(fixture), throwsFormatException);
      }
    });

    test('required normalized splash fields cannot be silently defaulted', () {
      for (final field in appDesignMap58(appDesignFixture58()['splash']).keys) {
        final fixture = appDesignFixture58();
        appDesignMap58(fixture['splash']).remove(field);
        expect(() => _parse(fixture), throwsFormatException, reason: field);
      }
    });

    test('asset query cannot encode customer or commerce record fields', () {
      for (final query in const <String>[
        'customer_email=buyer%40example.invalid',
        'EMAIL=buyer%40example.invalid',
        'auth=private',
        'order_id=77',
        'price=12.50',
        'stock_quantity=3',
        '%63ustomer_email=buyer%40example.invalid',
      ]) {
        final fixture = appDesignFixture58();
        appDesignMap58(fixture['identity'])['logo_url'] =
            '$appDesignOrigin58/logo.png?$query';
        expect(() => _parse(fixture), throwsFormatException, reason: query);
        expect(() => _produce(fixture), throwsFormatException, reason: query);
      }
      final fixture = appDesignFixture58();
      appDesignMap58(fixture['identity'])['logo_url'] =
          '$appDesignOrigin58/logo.png?width=128&format=webp';
      expect(_parse(fixture).identity['logo_url'], contains('width=128'));
    });

    test(
      'splash ranges and enums cannot silently clamp to a different design',
      () {
        final mutations = <String, List<dynamic>>{
          'duration_ms': <dynamic>[0, 499, 10001, '1250'],
          'image_width': <dynamic>[39, 321, '180'],
          'image_height': <dynamic>[39, 321, '150'],
          'image_fit': <dynamic>['unexpected', 1],
          'image_shape': <dynamic>['unexpected', 1],
          'show_loader': <dynamic>['false', 1],
        };
        for (final mutation in mutations.entries) {
          for (final value in mutation.value) {
            final fixture = appDesignFixture58();
            appDesignMap58(fixture['splash'])[mutation.key] = value;
            expect(
              () => _parse(fixture),
              throwsFormatException,
              reason: '${mutation.key}=$value',
            );
          }
        }
      },
    );
  });

  group('direct catalog hydration, never a saved commerce snapshot', () {
    test(
      'fresh price/stock/name reads retain exact design and block order',
      () async {
        final bundle = _parse(appDesignFixture58());
        final repository = _Catalog();
        final first = await bundle.hydrateHome(repository, locale: 'ar');
        expect(first.blocks.map((block) => block.id), <String>[
          'saved-heading',
          'saved-products',
          'saved-categories',
        ]);
        final firstGrid = first.blocks.whereType<ProductGridBlock>().single;
        expect(firstGrid.columns, 3);
        expect(firstGrid.cardStyle, 'minimal');
        expect(firstGrid.cardRadius, 7);
        expect(firstGrid.imageRatio, 0.82);
        expect(firstGrid.quickAddEnabled, isFalse);
        expect(firstGrid.imageSwipeEnabled, isTrue);
        expect(firstGrid.items.single.price, '123.45');
        expect(firstGrid.items.single.inStock, isTrue);
        expect(firstGrid.items.single.name, 'Live product 71');
        final heading = first.blocks.whereType<TextBlock>().single;
        expect(heading.title, 'Saved heading');
        expect(heading.presentation.marginTop, 11);
        expect(heading.presentation.paddingHorizontal, 17);
        expect(repository.productQueries.single.sort, CatalogSort.name);
        expect(repository.productQueries.single.perPage, 8);
        expect(repository.categoryQueries.single.perPage, 6);
        expect(repository.productIds, isEmpty);

        repository.products = <CatalogProduct>[
          _product(
            71,
            name: 'Changed live name',
            priceMinor: '7654',
            inStock: false,
          ),
        ];
        repository.categories = <CatalogCategory>[
          CatalogCategory(
            id: 9,
            name: 'Changed live category',
            slug: 'live-category',
            image: CatalogImage(
              source: Uri.parse('$appDesignOrigin58/images/new-category.png'),
            ),
          ),
        ];
        final second = await bundle.hydrateHome(repository, locale: 'ar');
        final secondGrid = second.blocks.whereType<ProductGridBlock>().single;
        expect(secondGrid.items.single.price, '76.54');
        expect(secondGrid.items.single.inStock, isFalse);
        expect(secondGrid.items.single.name, 'Changed live name 71');
        expect(secondGrid.columns, firstGrid.columns);
        expect(
          second.blocks.whereType<CategoryGridBlock>().single.items.single.name,
          'Changed live category',
        );
        expect(repository.productQueries, hasLength(2));
        expect(repository.categoryQueries, hasLength(2));
        expect(firstGrid.items.single.price, '123.45');
      },
    );

    test(
      'home cards request thumbnails while product originals stay available',
      () async {
        final repository = _Catalog()
          ..products = [_product(71, withThumbnail: true)];
        final home = await _parse(
          appDesignFixture58(),
        ).hydrateHome(repository, locale: 'ar');
        final card = home.blocks
            .whereType<ProductGridBlock>()
            .single
            .items
            .single;
        expect(card.imageUrl, '$appDesignOrigin58/images/live-71-300x300.png');
        expect(card.imageUrls, [
          '$appDesignOrigin58/images/live-71-300x300.png',
        ]);
        expect(
          repository.products.single.primaryImage!.source.toString(),
          '$appDesignOrigin58/images/live-71.png',
        );
        final fallback = _product(72).primaryImage!;
        expect(fallback.cardSource, fallback.source);
      },
    );

    test(
      'product-ID selector fetches direct details and preserves selected order',
      () async {
        final fixture = appDesignFixture58();
        appDesignMap58(
          appDesignBlock58(fixture, 'saved-products')['catalog_query'],
        ).addAll(<String, dynamic>{
          'mode': 'ids',
          'ids': <int>[72, 71],
          'limit': 2,
          'sort': 'relevance',
        });
        final repository = _Catalog()
          ..products = <CatalogProduct>[_product(71), _product(72)];
        final home = await _parse(
          fixture,
        ).hydrateHome(repository, locale: 'ar');
        expect(repository.productIds, <int>[72, 71]);
        expect(repository.productQueries, isEmpty);
        expect(
          home.blocks.whereType<ProductGridBlock>().single.items.map(
            (item) => item.id,
          ),
          <int>[72, 71],
        );
      },
    );

    test(
      'category and search selectors reach the repository without extra filters',
      () async {
        final fixture = appDesignFixture58();
        final query = appDesignMap58(
          appDesignBlock58(fixture, 'saved-products')['catalog_query'],
        );
        query.addAll(<String, dynamic>{'mode': 'category', 'category_id': 9});
        final repository = _Catalog();
        await _parse(fixture).hydrateHome(repository, locale: 'ar');
        expect(repository.productQueries.single.categoryIds, <int>[9]);
        expect(repository.productQueries.single.search, isEmpty);
        query.remove('category_id');
        query.addAll(<String, dynamic>{'mode': 'search', 'search': 'shoes'});
        await _parse(fixture).hydrateHome(repository, locale: 'ar');
        expect(repository.productQueries.last.search, 'shoes');
        expect(repository.productQueries.last.categoryIds, isEmpty);
      },
    );

    test(
      'a transient section failure preserves the saved non-catalog Home design',
      () async {
        final repository = _Catalog()
          ..failure = const CatalogRepositoryException(
            kind: StoreApiFailureKind.connection,
            message: 'offline',
          );
        final home = await _parse(
          appDesignFixture58(),
        ).hydrateHome(repository, locale: 'ar');
        expect(home.blocks.whereType<CatalogUnavailableBlock>(), isNotEmpty);
        expect(home.blocks.any((b) => b is! CatalogUnavailableBlock), isTrue);
        expect(home.blocks.whereType<ProductGridBlock>(), isEmpty);
      },
    );

    test(
      'live read failure does not return frozen product or invented fallback',
      () async {
        final repository = _Catalog()
          ..failure = StateError('Store unavailable');
        await expectLater(
          _parse(appDesignFixture58()).hydrateHome(repository, locale: 'ar'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'minor-unit hydration remains exact above floating-point precision',
      () async {
        final repository = _Catalog()
          ..products = <CatalogProduct>[
            _product(71, priceMinor: '900719925474099312'),
          ];
        final home = await _parse(
          appDesignFixture58(),
        ).hydrateHome(repository, locale: 'ar');
        expect(
          home.blocks.whereType<ProductGridBlock>().single.items.single.price,
          '9007199254740993.12',
        );
      },
    );

    test('real products and categories without images stay visible', () async {
      final repository = _Catalog()
        ..products = <CatalogProduct>[_product(71, withImage: false)]
        ..categories = const <CatalogCategory>[
          CatalogCategory(id: 9, name: 'No category image', slug: 'no-image'),
        ];
      final home = await _parse(
        appDesignFixture58(),
      ).hydrateHome(repository, locale: 'ar');
      final product = home.blocks
          .whereType<ProductGridBlock>()
          .single
          .items
          .single;
      expect(product.id, 71);
      expect(product.imageUrl, isEmpty);
      expect(product.imageUrls, isEmpty);
      expect(product.price, '123.45');
      final category = home.blocks
          .whereType<CategoryGridBlock>()
          .single
          .items
          .single;
      expect(category.id, 9);
      expect(category.name, 'No category image');
      expect(category.imageUrl, isEmpty);
    });

    test(
      'discount percentage is derived exactly from current minor units',
      () async {
        final repository = _Catalog()
          ..products = <CatalogProduct>[
            _product(
              71,
              priceMinor: '90000000000000000001',
              regularPriceMinor: '100000000000000000000',
            ),
          ];
        final home = await _parse(
          appDesignFixture58(),
        ).hydrateHome(repository, locale: 'ar');
        final item = home.blocks
            .whereType<ProductGridBlock>()
            .single
            .items
            .single;
        // Just under 10%. Floating-point conversion would incorrectly yield 10.
        expect(item.discountPercent, 9);
        expect(item.price, '900000000000000000.01');
        expect(item.regularPrice, '1000000000000000000.00');
      },
    );
  });

  group('saved design producer', () {
    test(
      'projects actual saved page-store metadata without changing design',
      () {
        final fixture = appDesignFixture58();
        final pages = appDesignMap58(fixture['pages']);
        for (final page in pages.values.cast<Map<String, dynamic>>()) {
          page.addAll(<String, dynamic>{
            'version': 1,
            'updated_at': '2026-10-10T12:00:00Z',
            'locale': 'ar',
          });
          appDesignMap58(page['header'])['locked'] = true;
          appDesignMap58(page['footer'])['locked'] = true;
        }
        final product = appDesignMap58(pages['product']);
        (product['elements'] as List).add(<String, dynamic>{
          'id': 'product_summary',
          'type': 'product_summary',
          'label': 'Product summary',
          'icon': 'tag',
          'locked': false,
          'enabled': true,
          'settings': <String, dynamic>{'show_price': true, 'name_size': 18},
        });
        final before = jsonEncode(fixture);
        final bundle = AppDesignBundle58.fromEncoded(
          _produce(fixture),
          platform: CommercePlatform.odoo,
          storeOrigin: Uri.parse(appDesignOrigin58),
        );
        expect(jsonEncode(fixture), before);
        expect(bundle.pageLayout('product').header.number('height', 0), 91);
        expect(bundle.pageLayout('product').footer.number('height', 0), 74);
        final summary = bundle.pageLayout('product').elements.single;
        expect(summary.id, 'product_summary');
        expect(summary.enabled, isTrue);
        expect(summary.boolean('show_price', false), isTrue);
        expect(summary.number('name_size', 0), 18);
        final exportedPage = appDesignMap58(
          appDesignMap58(bundle.toJson()['pages'])['product'],
        );
        expect(exportedPage.containsKey('version'), isFalse);
        expect(
          appDesignMap58(exportedPage['header']).containsKey('locked'),
          isFalse,
        );
        expect(
          (exportedPage['elements'] as List).single,
          isNot(containsPair('label', 'Product summary')),
        );
      },
    );

    test(
      'page projection never drops unknown or private metadata silently',
      () {
        for (final field in const <String>[
          'access_token',
          'private_metadata',
        ]) {
          final fixture = appDesignFixture58();
          final page = appDesignMap58(appDesignMap58(fixture['pages'])['home']);
          page[field] = 'must-not-ship';
          expect(() => _produce(fixture), throwsFormatException, reason: field);
        }
        final fixture = appDesignFixture58();
        final page = appDesignMap58(appDesignMap58(fixture['pages'])['home']);
        appDesignMap58(page['header'])['label'] = <String, dynamic>{
          'access_token': 'must-not-ship',
        };
        expect(() => _produce(fixture), throwsFormatException);
      },
    );

    test(
      'strips catalog snapshots without mutating the supplied saved state',
      () {
        final fixture = appDesignFixture58();
        final products = appDesignBlock58(fixture, 'saved-products');
        final categories = appDesignBlock58(fixture, 'saved-categories');
        final queries = <String, Map<String, dynamic>>{
          'saved-products': Map<String, dynamic>.from(
            appDesignMap58(products.remove('catalog_query')),
          ),
          'saved-categories': Map<String, dynamic>.from(
            appDesignMap58(categories.remove('catalog_query')),
          ),
        };
        appDesignMap58(products['data'])['items'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 71,
            'name': 'Saved stale item',
            'price': '0.01',
            'in_stock': true,
            'customer_token': 'must-not-ship',
          },
        ];
        appDesignMap58(categories['data'])['items'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 9, 'name': 'Saved stale category'},
        ];
        final before = jsonEncode(fixture);
        final encoded = _produce(fixture, queries: queries);
        expect(jsonEncode(fixture), before);
        final decoded = jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
        final serialized = jsonEncode(decoded);
        expect(serialized, isNot(contains('Saved stale item')));
        expect(serialized, isNot(contains('must-not-ship')));
        expect(serialized, isNot(contains('0.01')));
        final bundle = AppDesignBundle58.fromEncoded(
          encoded,
          platform: CommercePlatform.odoo,
          storeOrigin: Uri.parse(appDesignOrigin58),
        );
        expect(bundle.identity['primary_color'], '#4EA999');
        expect(bundle.pageLayout('product').footer.number('height', 0), 74);
      },
    );

    test('producer refuses catalog source without explicit saved selector', () {
      final fixture = appDesignFixture58();
      appDesignBlock58(fixture, 'saved-products').remove('catalog_query');
      appDesignBlock58(fixture, 'saved-categories').remove('catalog_query');
      expect(() => _produce(fixture), throwsFormatException);
    });

    test(
      'producer rejects credentials rather than encoding the raw builder state',
      () {
        final fixture = appDesignFixture58();
        appDesignMap58(fixture['identity'])['access_token'] = 'secret';
        expect(() => _produce(fixture), throwsFormatException);
      },
    );
  });
}
