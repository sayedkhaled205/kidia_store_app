import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_widgets.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/kids_home_product_feed.dart';

class _Repository implements CatalogRepository {
  final queries = <CatalogProductQuery>[];
  late Future<CatalogPage<CatalogProduct>> Function(CatalogProductQuery) fetch;
  @override
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query) {
    queries.add(query);
    return fetch(query);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductGridBlock block(Object limit) =>
    HomeBlockModel.fromJson({
          'id': 'any-customer-final-section',
          'type': 'product_grid',
          'enabled': true,
          'data': {
            'limit': limit,
            'source': 'latest',
            'columns': 2,
            'quick_add_enabled': false,
            'show_wishlist': false,
            'items': [
              {
                'id': 1,
                'name': 'Seed',
                'image_url': 'https://example.com/product.png',
                'price': '25',
                'currency_code': 'USD',
                'currency_symbol': r'$',
              },
            ],
          },
        })
        as ProductGridBlock;

CatalogPage<CatalogProduct> page(
  CatalogProductQuery query,
  List<int> ids, {
  bool more = false,
}) => CatalogPage(
  items: ids
      .map(
        (id) => CatalogProduct(
          id: id,
          name: 'Item $id',
          slug: 'item-$id',
          type: 'simple',
          isInStock: true,
          prices: const CatalogMoney(
            currencyCode: 'USD',
            currencySymbol: r'$',
            currencyMinorUnit: 2,
            priceMinor: '2500',
          ),
        ),
      )
      .toList(),
  page: query.page,
  perPage: query.perPage,
  totalItems: null,
  totalPages: null,
  cursorPagination: true,
  cursorHasNextPage: more,
);

Future<void> pumpFeed(
  WidgetTester tester,
  _Repository repository,
  ScrollController scroll,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: KidsHomeProductFeed(
              block: block('all'),
              scrollController: scroll,
              onAction: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('All survives parsing; numeric limits remain finite', () {
    expect(block('all').loadAll, isTrue);
    expect(block(12).loadAll, isFalse);
  });

  testWidgets('one in-flight request, deduplication and cursor exhaustion', (
    tester,
  ) async {
    final repository = _Repository();
    final first = Completer<CatalogPage<CatalogProduct>>();
    repository.fetch = (query) async =>
        query.page == 1 ? first.future : page(query, [2, 3]);
    final scroll = ScrollController();
    await pumpFeed(tester, repository, scroll);
    await tester.pump();
    expect(repository.queries.length, 1);
    first.complete(page(repository.queries.first, [1, 2], more: true));
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final grid = tester.widget<ProductGridBlockWidget>(
      find.byType(ProductGridBlockWidget),
    );
    expect(grid.block.items.map((p) => p.id), [1, 2, 3]);
    expect(repository.queries.map((q) => q.page), [1, 2]);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(repository.queries.length, 2);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });

  testWidgets('failure keeps loaded items and retries the same page', (
    tester,
  ) async {
    final repository = _Repository();
    repository.fetch = (_) async => throw StateError('offline');
    final scroll = ScrollController();
    await pumpFeed(tester, repository, scroll);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<ProductGridBlockWidget>(find.byType(ProductGridBlockWidget))
          .block
          .items
          .single
          .name,
      'Seed',
    );
    expect(repository.queries.length, 1);
    repository.fetch = (query) async => page(query, [5]);
    await tester.tap(find.text('Could not load more · Retry'));
    await tester.pumpAndSettle();
    expect(repository.queries.map((q) => q.page), [1, 1]);
    expect(
      tester
          .widget<ProductGridBlockWidget>(find.byType(ProductGridBlockWidget))
          .block
          .items
          .single
          .id,
      5,
    );
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
}
