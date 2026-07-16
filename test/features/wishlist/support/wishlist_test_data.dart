import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';

typedef WishlistLoadCallback = Future<List<int>> Function();
typedef WishlistSaveCallback = Future<void> Function(List<int> productIds);
typedef CatalogProductsCallback =
    Future<CatalogPage<CatalogProduct>> Function(CatalogProductQuery query);

class FakeWishlistRepository implements WishlistRepository {
  FakeWishlistRepository({
    List<int> ids = const <int>[],
    this.onLoad,
    this.onSave,
  }) : ids = List<int>.of(ids);

  List<int> ids;
  WishlistLoadCallback? onLoad;
  WishlistSaveCallback? onSave;
  int loadCalls = 0;
  int saveCalls = 0;

  @override
  Future<List<int>> loadProductIds() async {
    loadCalls++;
    final WishlistLoadCallback? callback = onLoad;
    if (callback != null) {
      return callback();
    }
    return List<int>.of(ids);
  }

  @override
  Future<void> saveProductIds(List<int> productIds) async {
    saveCalls++;
    final WishlistSaveCallback? callback = onSave;
    if (callback != null) {
      await callback(List<int>.of(productIds));
      return;
    }
    ids = List<int>.of(productIds);
  }
}

class FakeWishlistCatalogRepository implements CatalogRepository {
  FakeWishlistCatalogRepository({
    Iterable<CatalogProduct> products = const <CatalogProduct>[],
    this.onGetProducts,
  }) : products = <int, CatalogProduct>{
         for (final CatalogProduct product in products) product.id: product,
       };

  final Map<int, CatalogProduct> products;
  CatalogProductsCallback? onGetProducts;
  final List<CatalogProductQuery> productQueries = <CatalogProductQuery>[];
  int productDetailCalls = 0;

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    productQueries.add(query);
    final CatalogProductsCallback? callback = onGetProducts;
    if (callback != null) {
      return callback(query);
    }
    final List<CatalogProduct> items = query.includeIds
        .map((int id) => products[id])
        .whereType<CatalogProduct>()
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    return catalogPage(items);
  }

  @override
  Future<CatalogProduct> getProduct(int productId) async {
    productDetailCalls++;
    final CatalogProduct? product = products[productId];
    if (product == null) {
      throw StateError('Missing product $productId');
    }
    return product;
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) async {
    return const <CatalogVariation>[];
  }

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async {
    return const CatalogPage<CatalogCategory>(
      items: <CatalogCategory>[],
      page: 1,
      perPage: 20,
      totalItems: 0,
      totalPages: 0,
    );
  }

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    return const CatalogFilterData();
  }
}

CatalogPage<CatalogProduct> catalogPage(List<CatalogProduct> products) {
  return CatalogPage<CatalogProduct>(
    items: List<CatalogProduct>.unmodifiable(products),
    page: 1,
    perPage: products.isEmpty ? 1 : products.length,
    totalItems: products.length,
    totalPages: products.isEmpty ? 0 : 1,
  );
}

const CatalogMoney wishlistMoney = CatalogMoney(
  currencyCode: 'USD',
  currencySymbol: r'$',
  currencyPrefix: r'$',
  currencyMinorUnit: 2,
  priceMinor: '8500',
  regularPriceMinor: '10000',
  salePriceMinor: '8500',
);

const CatalogProduct wishlistProductOne = CatalogProduct(
  id: 1,
  name: 'Everyday Jacket',
  slug: 'everyday-jacket',
  type: 'simple',
  prices: wishlistMoney,
  isOnSale: true,
  isPurchasable: true,
  isInStock: true,
  stockStatus: CatalogStockStatus.inStock,
);

const CatalogProduct wishlistProductTwo = CatalogProduct(
  id: 2,
  name: 'Classic Shirt',
  slug: 'classic-shirt',
  type: 'simple',
  prices: wishlistMoney,
  isPurchasable: true,
  isInStock: true,
  stockStatus: CatalogStockStatus.inStock,
);

const CatalogProduct wishlistProductThree = CatalogProduct(
  id: 3,
  name: 'Summer Shoes',
  slug: 'summer-shoes',
  type: 'simple',
  prices: wishlistMoney,
  isPurchasable: false,
  isInStock: false,
  stockStatus: CatalogStockStatus.outOfStock,
);
