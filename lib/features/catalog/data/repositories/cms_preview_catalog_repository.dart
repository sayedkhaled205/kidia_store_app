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
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_change_source.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_preview_layout_bridge.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_product_model.dart';

/// Native preview catalog: theme fixtures in demo mode, connected store data
/// through the authenticated parent bridge in live editor mode.
class CmsPreviewCatalogRepository
    implements CatalogRepository, CatalogChangeSource {
  CmsPreviewCatalogRepository({
    Future<Map<String, dynamic>> Function()? catalog,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? fetchPage,
    bool? live,
    Stream<int>? changes,
    int Function()? revision,
  }) : _catalogLoader = catalog,
       _pageLoader = fetchPage,
       // Preserve the public named arguments independently of private fields.
       // ignore: prefer_initializing_formals
       _live = live,
       // ignore: prefer_initializing_formals
       _changes = changes,
       // ignore: prefer_initializing_formals
       _revision = revision;

  final Future<Map<String, dynamic>> Function()? _catalogLoader;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  _pageLoader;
  final bool? _live;
  final Stream<int>? _changes;
  final int Function()? _revision;
  int _cacheRevision = -1;
  int get _currentRevision =>
      _revision?.call() ?? CmsPreviewLayoutBridge.catalogRevision;
  @override
  Stream<int> get catalogChanges =>
      _changes ?? CmsPreviewLayoutBridge.catalogChanges;

  void _synchronizeProductCache() {
    final int revision = _currentRevision;
    if (_cacheRevision == revision) return;
    _loadedProducts.clear();
    _cacheRevision = revision;
  }

  bool get _usesLiveCatalog => _live ?? CmsPreviewLayoutBridge.useLiveCatalog;
  Future<Map<String, dynamic>> _fetchPage(Map<String, dynamic> query) =>
      (_pageLoader ?? CmsPreviewLayoutBridge.fetchCatalogPage)(query);
  final Map<int, CatalogProduct> _loadedProducts = <int, CatalogProduct>{};

  Future<Map<String, dynamic>> get _catalog =>
      _catalogLoader?.call() ?? CmsPreviewLayoutBridge.demoCatalog;

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    if (_usesLiveCatalog) {
      _synchronizeProductCache();
      final int requestedRevision = _currentRevision;
      final Map<String, dynamic> response = await _fetchPage(
        query.toStoreApiQuery(),
      );
      if ('${response['error'] ?? ''}'.isNotEmpty) {
        throw StateError('${response['error']}');
      }
      final List<CatalogProduct> items = await _parseProducts(
        response['products'] is List
            ? response['products'] as List<dynamic>
            : const <dynamic>[],
      );
      if (requestedRevision == _currentRevision) {
        for (final CatalogProduct product in items) {
          _loadedProducts[product.id] = product;
        }
      }
      final int total = _integer(response['total_items'], items.length);
      return CatalogPage<CatalogProduct>(
        items: items,
        page: query.page,
        perPage: query.perPage,
        totalItems: total,
        totalPages: total == 0 ? 0 : (total / query.perPage).ceil(),
      );
    }
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
        (CatalogProduct product) => product.name.toLowerCase().contains(search),
      );
    }
    final List<CatalogProduct> items = filtered.toList(growable: false);
    return _page(items, query.page, query.perPage);
  }

  @override
  Future<CatalogProduct> getProduct(int productId) async {
    if (_usesLiveCatalog) {
      _synchronizeProductCache();
      final CatalogProduct? cached = _loadedProducts[productId];
      if (cached != null) return cached;
      final int requestedRevision = _currentRevision;
      final Map<String, dynamic> response = await _fetchPage(<String, dynamic>{
        'page': 1,
        'per_page': 1,
        'include': '$productId',
      });
      final List<CatalogProduct> fetched = await _parseProducts(
        response['products'] is List
            ? response['products'] as List<dynamic>
            : const <dynamic>[],
      );
      for (final product in fetched) {
        if (product.id == productId) {
          if (requestedRevision == _currentRevision) {
            _loadedProducts[productId] = product;
          }
          return product;
        }
      }
      throw StateError('The product is not available in the connected store.');
    }
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
    if (_usesLiveCatalog) {
      final Map<int, CatalogProduct> details = {};
      final ids = product.variations.map((variation) => variation.id).toList();
      for (int start = 0; start < ids.length; start += 100) {
        final response = await _fetchPage({
          'include': ids.skip(start).take(100).join(','),
          'type': 'variation',
          'per_page': 100,
          'page': 1,
        });
        if ('${response['error'] ?? ''}'.isNotEmpty) {
          throw StateError('${response['error']}');
        }
        final products = await _parseProducts(
          response['products'] as List<dynamic>? ?? [],
        );
        for (final detail in products) {
          details[detail.id] = detail;
          _loadedProducts[detail.id] = detail;
        }
      }
      return product.variations
          .map((variation) {
            final detail = details[variation.id];
            return CatalogVariation(
              id: variation.id,
              attributes: variation.attributes,
              isPurchasable: detail?.isPurchasable ?? false,
              isInStock: detail?.isInStock ?? false,
              prices: detail?.prices,
              image: detail?.primaryImage,
            );
          })
          .toList(growable: false);
    }
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
    return _page(filtered.toList(growable: false), query.page, query.perPage);
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
    return _parseProducts(raw);
  }

  Future<List<CatalogProduct>> _parseProducts(List<dynamic> raw) async {
    final List<CatalogCategory> categories = await _categories();
    final Map<int, CatalogCategory> byId = <int, CatalogCategory>{
      for (final CatalogCategory category in categories) category.id: category,
    };
    return raw
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> json = Map<String, dynamic>.from(item);
          if (_usesLiveCatalog && json['store_api_product'] is Map) {
            return CatalogProductModel.fromJson(
              Map<String, dynamic>.from(json['store_api_product'] as Map),
            ).toEntity();
          }
          final int id = _integer(json['id'], 9001);
          final Uri? image = _uri(json['image_url']);
          final List<dynamic> gallery = json['image_urls'] is List
              ? json['image_urls'] as List<dynamic>
              : <dynamic>[json['image_url']];
          final List<CatalogImage> images = gallery
              .map(_uri)
              .whereType<Uri>()
              .map((Uri url) => CatalogImage(source: url, thumbnail: url))
              .toList(growable: false);
          final List<int> categoryIds = json['category_ids'] is List
              ? (json['category_ids'] as List<dynamic>)
                    .map((dynamic id) => _integer(id, 0))
                    .where((int id) => id > 0)
                    .toList(growable: false)
              : <int>[_integer(json['category_id'], 0)];
          return CatalogProduct(
            id: id,
            name: '${json['name'] ?? 'Theme product'}',
            slug: '${json['slug'] ?? 'theme-product-$id'}',
            type: '${json['type'] ?? 'simple'}',
            summary: '${json['summary'] ?? ''}',
            description: '${json['description'] ?? ''}',
            sku: '${json['sku'] ?? ''}',
            isFeatured: !_usesLiveCatalog,
            isOnSale: json['is_on_sale'] == true,
            isPurchasable: _usesLiveCatalog ? json['in_stock'] == true : true,
            isInStock: _usesLiveCatalog
                ? json['in_stock'] == true
                : json['in_stock'] != false,
            stockStatus: json['in_stock'] == false
                ? CatalogStockStatus.outOfStock
                : json['in_stock'] == true
                ? CatalogStockStatus.inStock
                : CatalogStockStatus.unknown,
            averageRating: _number(json['rating'], _usesLiveCatalog ? 0 : 4.7),
            reviewCount: _integer(
              json['review_count'],
              _usesLiveCatalog ? 0 : 24,
            ),
            prices: CatalogMoney(
              currencyCode: '${json['currency_code'] ?? 'USD'}',
              currencySymbol: '${json['currency_symbol'] ?? r'$'}',
              currencyMinorUnit: 2,
              priceMinor: '${json['price_minor'] ?? '9900'}',
              regularPriceMinor: '${json['regular_price_minor'] ?? ''}',
              salePriceMinor: json['is_on_sale'] == true
                  ? '${json['price_minor'] ?? '9900'}'
                  : '',
            ),
            images: images.isEmpty && image != null
                ? <CatalogImage>[CatalogImage(source: image, thumbnail: image)]
                : images,
            categories: categoryIds
                .map((int id) => byId[id])
                .whereType<CatalogCategory>()
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  Future<List<CatalogCategory>> _categories() async {
    final Map<String, dynamic> catalog = await _catalog;
    final List<dynamic> raw = catalog['categories'] is List
        ? catalog['categories'] as List<dynamic>
        : const <dynamic>[];
    return raw
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> json = Map<String, dynamic>.from(item);
          final int id = _integer(json['id'], 9101);
          final Uri? image = _uri(json['image_url']);
          return CatalogCategory(
            id: id,
            name: '${json['name'] ?? 'Collection'}',
            slug: '${json['slug'] ?? 'collection-$id'}',
            parentId: _integer(json['parent'], 0),
            description: '${json['description'] ?? ''}',
            count: _integer(json['count'], 12),
            image: image == null
                ? null
                : CatalogImage(source: image, thumbnail: image),
          );
        })
        .toList(growable: false);
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
