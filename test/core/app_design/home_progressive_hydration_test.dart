import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/app_design/app_design_hydration58.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';
import 'package:mobishop_store_app/features/home/presentation/pages/home_page.dart';
import 'package:mobishop_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

import 'app_design_fixture58.dart';

const empty = CatalogPage<CatalogProduct>(
  items: [],
  page: 1,
  perPage: 8,
  totalItems: 0,
  totalPages: 0,
);

class PendingCatalog implements CatalogRepository {
  final requests = <Completer<CatalogPage<CatalogProduct>>>[];
  @override
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query) {
    final request = Completer<CatalogPage<CatalogProduct>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> fixture({int sections = 2}) {
  final value = appDesignFixture58();
  final home = appDesignMap58(value['home']);
  final original = appDesignMap58((home['blocks'] as List)[1]);
  home['blocks'] = [
    (home['blocks'] as List).first,
    for (var i = 0; i < sections; i++)
      {
        ...original,
        'id': 'products-$i',
        'catalog_query': {
          ...appDesignMap58(original['catalog_query']),
          'limit': i + 1,
        },
      },
  ];
  return value;
}

void main() {
  testWidgets('saved home is usable while first products are pending', (
    tester,
  ) async {
    final value = fixture(sections: 1);
    final design = AppDesignBundle58.fromEncoded(
      appDesignRawEncoded58(value),
      platform: CommercePlatform.odoo,
      storeOrigin: Uri.parse(appDesignOrigin58),
    );
    final catalog = PendingCatalog();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portableAppDesign58Provider.overrideWithValue(design),
          catalogRepositoryProvider.overrideWithValue(catalog),
          cmsPageLayoutProvider.overrideWith(
            (ref, page) async => CmsPageLayout.fallback(page),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en')],
          home: HomePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(catalog.requests.length, 1);
    expect(find.text('Saved heading'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Saved heading'), findsOneWidget);
    expect(catalog.requests.length, 1);
    catalog.requests.single.complete(empty);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  test(
    'static content and completed sections do not wait for slow sections',
    () async {
      final snapshots = <HomeLayout>[];
      final catalog = PendingCatalog();
      final read = hydrateSavedHome58(
        appDesignMap58(fixture()['home']),
        catalog,
        locale: 'en',
        onProgress: snapshots.add,
      );
      await pumpEventQueue();
      expect(catalog.requests.length, 2);
      final initial = snapshots.single;
      expect(initial.blocks.first, isA<TextBlock>());
      expect(initial.blocks.skip(1), everyElement(isA<CatalogLoadingBlock>()));
      catalog.requests.first.complete(empty);
      await pumpEventQueue();
      expect(snapshots.last.blocks[1], isA<ProductGridBlock>());
      expect(snapshots.last.blocks[2], isA<CatalogLoadingBlock>());
      expect(
        initial.blocks[1],
        isA<CatalogLoadingBlock>(),
        reason: 'Snapshots cannot mutate after publishing.',
      );
      expect(snapshots.last.blocks.map((b) => b.id), [
        'saved-heading',
        'products-0',
        'products-1',
      ]);
      catalog.requests.last.complete(empty);
      final completed = await read;
      expect(completed.blocks.whereType<CatalogLoadingBlock>(), isEmpty);
    },
  );

  test(
    'malformed later selector starts no requests and emits no layout',
    () async {
      final home = appDesignMap58(fixture()['home']);
      ((home['blocks'] as List).last['catalog_query'] as Map)['limit'] = 0;
      final snapshots = <HomeLayout>[];
      final catalog = PendingCatalog();
      await expectLater(
        hydrateSavedHome58(
          home,
          catalog,
          locale: 'en',
          onProgress: snapshots.add,
        ),
        throwsFormatException,
      );
      expect(catalog.requests, isEmpty);
      expect(snapshots, isEmpty);
    },
  );

  for (final kind in [
    StoreApiFailureKind.connection,
    StoreApiFailureKind.unauthorized,
  ]) {
    test(
      'section failure $kind preserves fatal/transient distinction',
      () async {
        final snapshots = <HomeLayout>[];
        final catalog = PendingCatalog();
        final read = hydrateSavedHome58(
          appDesignMap58(fixture()['home']),
          catalog,
          locale: 'en',
          onProgress: snapshots.add,
        );
        final failure = CatalogRepositoryException(
          kind: kind,
          message: 'fixture',
        );
        final handled = read.then<Object?>(
          (value) => value,
          onError: (Object error) => error,
        );
        await pumpEventQueue();
        catalog.requests.first.completeError(failure);
        await pumpEventQueue();
        final count = snapshots.length;
        catalog.requests.last.complete(empty);
        final result = await handled;
        if (kind == StoreApiFailureKind.unauthorized) {
          expect(result, same(failure));
          await pumpEventQueue();
          expect(
            snapshots.length,
            count,
            reason: 'Late success cannot repaint after fatal failure.',
          );
        } else {
          expect(result, isA<HomeLayout>());
          expect(
            (result as HomeLayout).blocks[1],
            isA<CatalogUnavailableBlock>(),
          );
          expect(result.blocks[2], isA<ProductGridBlock>());
        }
      },
    );
  }

  test(
    'manual retry ignores superseded progress and future still waits for final',
    () async {
      final value = fixture(sections: 1);
      final design = AppDesignBundle58.fromEncoded(
        appDesignRawEncoded58(value),
        platform: CommercePlatform.odoo,
        storeOrigin: Uri.parse(appDesignOrigin58),
      );
      final catalog = PendingCatalog();
      final container = ProviderContainer(
        overrides: [
          portableAppDesign58Provider.overrideWithValue(design),
          catalogRepositoryProvider.overrideWithValue(catalog),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(homeLayoutProvider('en'), (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(container.read(homeLayoutProvider('en')).isLoading, true);
      container.invalidate(homeLayoutProvider('en'));
      catalog.requests.first.complete(empty);
      await pumpEventQueue();
      expect(catalog.requests.length, 2);
      final progress = container.read(homeLayoutProgressProvider('en')).value!;
      expect(progress.blocks[1], isA<CatalogLoadingBlock>());
      expect(container.read(homeLayoutProvider('en')).isLoading, true);
      catalog.requests.last.complete(empty);
      await container.read(homeLayoutProvider('en').future);
      expect(container.read(homeLayoutProvider('en')).hasValue, true);
    },
  );

  test(
    'late section after publication swap or dispose cannot paint old progress',
    () async {
      AppDesignBundle58 design(String heading) {
        final value = fixture(sections: 1);
        (((value['home'] as Map)['blocks'] as List).first['data']
                as Map)['title'] =
            heading;
        return AppDesignBundle58.fromEncoded(
          appDesignRawEncoded58(value),
          platform: CommercePlatform.odoo,
          storeOrigin: Uri.parse(appDesignOrigin58),
        );
      }

      final oldDesign = design('old');
      final newDesign = design('new');
      final catalog = PendingCatalog();
      final container = ProviderContainer(
        overrides: [
          portableAppDesign58Provider.overrideWithValue(oldDesign),
          catalogRepositoryProvider.overrideWithValue(catalog),
        ],
      );
      final sub = container.listen(homeLayoutProvider('en'), (_, _) {});
      await pumpEventQueue();
      container.updateOverrides([
        portableAppDesign58Provider.overrideWithValue(newDesign),
        catalogRepositoryProvider.overrideWithValue(catalog),
      ]);
      catalog.requests.first.complete(empty);
      await pumpEventQueue();
      expect(catalog.requests.length, 2);
      final progress = container.read(homeLayoutProgressProvider('en')).value!;
      expect((progress.blocks.first as TextBlock).title, 'new');
      expect(progress.blocks[1], isA<CatalogLoadingBlock>());
      sub.close();
      container.dispose();
      catalog.requests.last.complete(empty);
      await pumpEventQueue();
    },
  );
}
