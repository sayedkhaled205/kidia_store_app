import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_preview_layout_bridge.dart';

/// Catalog used by the built-in Setup Theme preview.
///
/// The data and images arrive in the same postMessage as the selected theme,
/// so this repository never calls the connected WooCommerce store.
class CmsPreviewCatalogRepository implements CatalogRepository {
  Future<Map<String, dynamic>> get _catalog =>
      CmsPreviewLayoutBridge.demoCatalog;

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    final List<CatalogProduct> products = await _products();
    Iterable<CatalogProduct> filtered = products;
    if (query.includeIds.isNotEmpty) {
      filtered = filtered.where(
        (CatalogProduct product) => query.includeIds.contains(product.id),
      );
    }
    if (query.categoryIds.isNotEmpty) {
      filtered = filtered.where(
        (CatalogProduct product) => product.categories.any(
          (CatalogCategory category) => query.categoryIds.contains(category.id),
        ),
      );
    }
    if (query.search.isNotEmpty) {
      final String search = query.search.toLowerCase();
      filtered = filtered.where(
        (CatalogProduct product) =>
            product.name.toLowerCase().contains(search),
      );
    }
    final List<CatalogProduct> items = filtered.toList(growable: false);
    return _page(items, query.page, query.perPage);
  }

  @override
  Future<CatalogProduct> getProduct(int productId) async {
    final List<CatalogProduct> products = await _products();
    return products.firstWhere(
      (CatalogProduct product) => product.id == productId,
      orElse: () => products.first,
    );
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) async {
    final CatalogProduct product = await getProduct(productId);
    if (product.type != 'variable') return const <CatalogVariation>[];
    return <CatalogVariation>[
      CatalogVariation(
        id: product.id + 100,
        attributes: const <CatalogVariationAttribute>[
          CatalogVariationAttribute(name: 'Option', value: 'Standard'),
        ],
        prices: product.prices,
        image: product.primaryImage,
      ),
    ];
  }

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async {
    final List<CatalogCategory> categories = await _categories();
    Iterable<CatalogCategory> filtered = categories;
    if (query.parentId != null) {
      filtered = filtered.where(
        (CatalogCategory category) => category.parentId == query.parentId,
      );
    }
    if (query.search.isNotEmpty) {
      final String search = query.search.toLowerCase();
      filtered = filtered.where(
        (CatalogCategory category) =>
            category.name.toLowerCase().contains(search),
      );
    }
    return _page(
      filtered.toList(growable: false),
      query.page,
      query.perPage,
    );
  }

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    final List<CatalogProduct> products = await _products();
    final List<int> prices = products
        .map(
          (CatalogProduct product) =>
              int.tryParse(product.prices.priceMinor) ?? 0,
        )
        .where((int price) => price > 0)
        .toList(growable: false);
    prices.sort();
    return CatalogFilterData(
      minimumPriceMinor: prices.isEmpty ? '' : '${prices.first}',
      maximumPriceMinor: prices.isEmpty ? '' : '${prices.last}',
      stockCounts: <CatalogStockCount>[
        CatalogStockCount(status: 'instock', count: products.length),
      ],
    );
  }

  Future<List<CatalogProduct>> _products() async {
    final Map<String, dynamic> catalog = await _catalog;
    final List<dynamic> raw = catalog['products'] is List
        ? catalog['products'] as List<dynamic>
        : const <dynamic>[];
    final List<CatalogCategory> categories = await _categories();
    final Map<int, CatalogCategory> byId = <int, CatalogCategory>{
      for (final CatalogCategory category in categories) category.id: category,
    };
    return raw
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> json = Map<String, dynamic>.from(item);
          final int id = _integer(json['id'], 9001);
          final Uri? image = _uri(json['image_url']);
          final List<dynamic> gallery = json['image_urls'] is List
              ? json['image_urls'] as List<dynamic>
              : <dynamic>[json['image_url']];
          final List<CatalogImage> images = gallery
              .map(_uri)
              .whereType<Uri>()
              .map(
                (Uri url) => CatalogImage(source: url, thumbnail: url),
              )
              .toList(growable: false);
          final int categoryId = _integer(json['category_id'], 0);
          return CatalogProduct(
            id: id,
            name: '${json['name'] ?? 'Theme product'}',
            slug: '${json['slug'] ?? 'theme-product-$id'}',
            type: '${json['type'] ?? 'simple'}',
            summary: '${json['summary'] ?? ''}',
            description: '${json['description'] ?? ''}',
            isFeatured: true,
            isOnSale: json['is_on_sale'] == true,
            isPurchasable: true,
            isInStock: json['in_stock'] != false,
            stockStatus: CatalogStockStatus.inStock,
            averageRating: _number(json['rating'], 4.7),
            reviewCount: _integer(json['review_count'], 24),
            prices: CatalogMoney(
              currencyCode: '${json['currency_code'] ?? 'USD'}',
              currencySymbol: '${json['currency_symbol'] ?? r'$'}',
              currencyMinorUnit: 2,
              priceMinor: '${json['price_minor'] ?? '9900'}',
              regularPriceMinor:
                  '${json['regular_price_minor'] ?? ''}',
              salePriceMinor: json['is_on_sale'] == true
                  ? '${json['price_minor'] ?? '9900'}'
                  : '',
            ),
            images: images.isEmpty && image != null
                ? <CatalogImage>[
                    CatalogImage(source: image, thumbnail: image),
                  ]
                : images,
            categories: byId[categoryId] == null
                ? const <CatalogCategory>[]
                : <CatalogCategory>[byId[categoryId]!],
          );
        })
        .toList(growable: false);
  }

  Future<List<CatalogCategory>> _categories() async {
    final Map<String, dynamic> catalog = await _catalog;
    final List<dynamic> raw = catalog['categories'] is List
        ? catalog['categories'] as List<dynamic>
        : const <dynamic>[];
    return raw.whereType<Map>().map((Map item) {
      final Map<String, dynamic> json = Map<String, dynamic>.from(item);
      final int id = _integer(json['id'], 9101);
      final Uri? image = _uri(json['image_url']);
      return CatalogCategory(
        id: id,
        name: '${json['name'] ?? 'Collection'}',
        slug: '${json['slug'] ?? 'collection-$id'}',
        description: '${json['description'] ?? ''}',
        count: _integer(json['count'], 12),
        image: image == null
            ? null
            : CatalogImage(source: image, thumbnail: image),
      );
    }).toList(growable: false);
  }

  CatalogPage<T> _page<T>(List<T> source, int page, int perPage) {
    final int start = (page - 1) * perPage;
    final int end = (start + perPage).clamp(0, source.length).toInt();
    final List<T> items = start >= source.length
        ? <T>[]
        : source.sublist(start, end);
    return CatalogPage<T>(
      items: items,
      page: page,
      perPage: perPage,
      totalItems: source.length,
      totalPages: source.isEmpty ? 0 : (source.length / perPage).ceil(),
    );
  }

  static int _integer(Object? value, int fallback) =>
      int.tryParse('$value') ?? fallback;

  static double _number(Object? value, double fallback) =>
      double.tryParse('$value') ?? fallback;

  static Uri? _uri(Object? value) {
    final Uri? uri = Uri.tryParse('$value');
    return uri != null && uri.hasScheme ? uri : null;
  }
}
