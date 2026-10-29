import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/push/app_page_link.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';

class CaptureRepository implements CatalogRepository {
  CatalogProductQuery? last;
  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    last = query;
    return CatalogPage(
      items: const [],
      page: 1,
      perPage: 20,
      totalItems: 0,
      totalPages: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('links open only safe destinations in their own store', () {
    Uri link(String route) =>
        Uri.https('shop.example', '/shop/', {'mobishop_page': route});
    expect(
      AppPageLink.location(
        link('/categories/42?name=ملابس'),
        'https://shop.example/shop',
      ),
      '/categories/42?name=ملابس',
    );
    expect(
      AppPageLink.location(link('/products'), 'https://other.example/shop'),
      isNull,
    );
    for (final route in [
      '//evil.test',
      'https://evil.test',
      '/orders/123',
      '/account?token=secret',
      '/product/0',
      '/products#token',
    ]) {
      expect(
        AppPageLink.location(link(route), 'https://shop.example/shop'),
        isNull,
      );
    }
  });
  test('filtered category round-trips into the same server query', () async {
    final repo = CaptureRepository();
    final original = CatalogProductListController(
      repo,
      request: const CatalogProductListRequest(
        title: 'سالوبت',
        search: 'قطن',
        categoryId: 42,
        initialSort: CatalogSort.priceLowToHigh,
        initialFilters: CatalogProductFilters(
          onSaleOnly: true,
          minimumPriceMinor: '10000',
          maximumPriceMinor: '50000',
          brandId: 7,
          tags: [CatalogTagOption(id: 9, label: 'صيف')],
          sizes: [
            CatalogSizeOption(
              taxonomy: 'pa_size',
              term: '2-3',
              label: '٢-٣ سنوات',
            ),
          ],
          colors: [
            CatalogSizeOption(
              taxonomy: 'pa_color',
              term: 'blue',
              label: 'أزرق',
            ),
          ],
        ),
      ),
    );
    await original.loadInitial();
    final query = repo.last!.toStoreApiQuery();
    final encoded = CatalogPageState.encode(original);
    final restored = CatalogPageState.restore(
      encoded,
      const CatalogProductListRequest(),
    );
    final reopened = CatalogProductListController(repo, request: restored);
    await reopened.loadInitial();
    expect(repo.last!.toStoreApiQuery(), query);
    expect(reopened.state.filters.sizes.single.label, '٢-٣ سنوات');
    expect(encoded.contains('token'), isFalse);
    original.dispose();
    reopened.dispose();
  });
  test('malformed catalog state leaves ordinary navigation intact', () {
    const request = CatalogProductListRequest(categoryId: 5);
    for (final value in ['bad!', 'e30', 'x' * 2000])
      expect(CatalogPageState.restore(value, request), same(request));
  });
}
