import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_category_model.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_filter_data_model.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_product_model.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_variation_model.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';

/// Direct public Odoo catalog foundation. Paths and base response shapes were
/// verified against the installed mobile API. This is not a customer/account,
/// cart/order transport, and never substitutes the merchant commerce endpoint.
/// Search/category semantics were verified in the installed controller source;
/// unverified parameters are deliberately not exposed.
class OdooCatalogGateway {
  OdooCatalogGateway({
    required this.reader,
    required CommerceConnection connection,
  }) : _origin = connection.storeOrigin {
    if (connection.platform != CommercePlatform.odoo) {
      throw const FormatException('Odoo catalog needs an Odoo connection.');
    }
  }

  final StoreApiClient reader;
  final Uri _origin;
  static const String _products = '/api/mobile/v1/catalog/products';
  static const String _categories = '/api/mobile/v1/catalog/categories';

  Future<CatalogPage<CatalogProduct>> getProducts({
    int page = 1,
    int perPage = 20,
    String search = '',
    int? categoryId,
    bool newest = false,
  }) async {
    _bounds(page, perPage);
    final String term = search.trim();
    // Installed controller truncates to80; reject rather than promise a
    // different search from the term the customer actually submitted.
    if (term.runes.length > 80 || (categoryId != null && categoryId <= 0)) {
      throw ArgumentError('Invalid Odoo search/category.');
    }
    final StoreApiResponse response = await reader.get(
      _products,
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (term.isNotEmpty) 'search': term,
        'category': ?categoryId,
        if (newest) 'sort': 'newest',
      },
    );
    if (newest) _selectors83(response);
    return _page(response, page, perPage, _product);
  }

  Future<CatalogProduct> getProduct(int productId) async {
    _positive(productId);
    final StoreApiResponse response = await reader.get('$_products/$productId');
    final CatalogProduct product = _product(_map(response.data));
    if (product.id != productId) {
      throw const FormatException('Odoo returned a different product.');
    }
    return product;
  }

  Future<List<CatalogVariation>> getVariations(int productId) async {
    _positive(productId);
    final StoreApiResponse response = await reader.get(
      '$_products/$productId/variations',
    );
    return List<CatalogVariation>.unmodifiable(
      _list(response.data).map((dynamic raw) {
        final Map<String, dynamic> json = _map(raw);
        _variation(json);
        return CatalogVariationModel.fromJson(
          _normalizeVariation(json),
        ).toEntity();
      }),
    );
  }

  Future<CatalogPage<CatalogCategory>> getCategories({
    int page = 1,
    int perPage = 100,
    int? parentId,
    bool hideEmpty = false,
    List<int> includeIds = const [],
  }) async {
    _bounds(page, perPage);
    if ((parentId != null && parentId < 0) ||
        includeIds.any((id) => id <= 0) ||
        includeIds.toSet().length != includeIds.length ||
        includeIds.length > 100 ||
        (parentId != null && includeIds.isNotEmpty)) {
      throw ArgumentError('Invalid Odoo category selection.');
    }
    final StoreApiResponse response = await reader.get(
      _categories,
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'parent': ?parentId,
        if (hideEmpty) 'hide_empty': 'true',
        if (includeIds.isNotEmpty) 'include': includeIds.join(','),
      },
    );
    if (parentId != null || hideEmpty || includeIds.isNotEmpty) {
      _selectors83(response);
    }
    return _page(response, page, perPage, _category);
  }

  // The earlier installed connector ignored these arguments. A versioned
  // acknowledgement prevents a newest/root selector silently becoming all.
  static void _selectors83(StoreApiResponse response) {
    if (response.header('x-woomobile-catalog-selectors') != '1') {
      throw const FormatException('Odoo catalog selectors need connector 83.');
    }
  }

  /// Unfiltered catalog-wide ranges/counts only; these stock counts are counts
  /// of availability states, not physical units or real-time quantity proof.
  Future<CatalogFilterData> getFilterData() async {
    final StoreApiResponse response = await reader.get(
      '$_products/collection-data',
    );
    final Map<String, dynamic> json = _map(response.data);
    final Map<String, dynamic> priceRange = _map(json['price_range']);
    final String minimum = _minor(priceRange['min_price']);
    final String maximum = _minor(priceRange['max_price']);
    if (BigInt.parse(maximum) < BigInt.parse(minimum)) {
      throw const FormatException('Odoo returned a reversed price range.');
    }
    for (final dynamic raw in _list(json['stock_status_counts'])) {
      final Map<String, dynamic> count = _map(raw);
      _stockStatus(count['status']);
      _nonNegative(count['count']);
    }
    _list(json['attribute_counts']);
    _list(json['rating_counts']);
    return CatalogFilterDataModel.fromJson(json).toEntity();
  }

  CatalogProduct _product(Map<String, dynamic> json) {
    _positive(json['id']);
    _nonEmpty(json['name']);
    _nonEmpty(json['slug']);
    _nonEmpty(json['type']);
    for (final String flag in <String>[
      'is_featured',
      'on_sale',
      'is_purchasable',
      'is_in_stock',
    ]) {
      _bool(json[flag]);
    }
    _stockStatus(json['stock_status']);
    _money(json['prices']);
    _nonNegative(json['review_count']);
    _list(json['attributes']);
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(json)
      ..['permalink'] = _url(json['permalink'], ownOrigin: true)
      ..['images'] = _list(json['images']).map(_image).toList(growable: false)
      ..['categories'] = _list(json['categories'])
          .map((dynamic raw) => _normalizeCategory(_map(raw)))
          .toList(growable: false)
      ..['brands'] = _list(json['brands'])
          .map((dynamic raw) => _normalizeCategory(_map(raw)))
          .toList(growable: false)
      ..['variations'] = _list(json['variations'])
          .map((dynamic raw) {
            final Map<String, dynamic> variation = _map(raw);
            _variation(variation);
            return _normalizeVariation(variation);
          })
          .toList(growable: false);
    return CatalogProductModel.fromJson(normalized).toEntity();
  }

  CatalogCategory _category(Map<String, dynamic> json) =>
      CatalogCategoryModel.fromJson(_normalizeCategory(json)).toEntity();

  Map<String, dynamic> _normalizeCategory(Map<String, dynamic> json) {
    _positive(json['id']);
    _nonEmpty(json['name']);
    _nonEmpty(json['slug']);
    _nonNegative(json['parent']);
    _nonNegative(json['count']);
    return Map<String, dynamic>.from(json)
      ..['permalink'] = _url(json['permalink'], ownOrigin: true)
      ..['image'] = json['image'] == null ? null : _image(json['image']);
  }

  void _variation(Map<String, dynamic> json) {
    _positive(json['id']);
    _bool(json['is_purchasable']);
    _bool(json['is_in_stock']);
    _money(json['prices']);
    for (final dynamic raw in _list(json['attributes'])) {
      final Map<String, dynamic> attribute = _map(raw);
      _nonEmpty(attribute['name']);
      _nonEmpty(attribute['value']);
    }
  }

  Map<String, dynamic> _normalizeVariation(Map<String, dynamic> json) =>
      Map<String, dynamic>.from(json)
        ..['image'] = json['image'] == null ? null : _image(json['image']);

  Map<String, dynamic> _image(dynamic raw) {
    final Map<String, dynamic> image = _map(raw);
    return Map<String, dynamic>.from(image)
      ..['src'] = _url(image['src'], required: true)
      ..['thumbnail'] = _url(image['thumbnail']);
  }

  String _url(dynamic raw, {bool ownOrigin = false, bool required = false}) {
    if ((raw == null || raw == '') && !required) return '';
    final String source = _nonEmpty(raw);
    final Uri? parsed = Uri.tryParse(source);
    if (parsed == null ||
        parsed.hasFragment ||
        parsed.userInfo.isNotEmpty ||
        parsed.pathSegments.contains('..')) {
      throw const FormatException('Invalid Odoo catalog URL.');
    }
    final Uri resolved = _origin.resolveUri(parsed);
    if (resolved.scheme != 'https' ||
        resolved.host.isEmpty ||
        resolved.userInfo.isNotEmpty ||
        (resolved.hasPort && resolved.port != 443) ||
        (ownOrigin && resolved.host != _origin.host)) {
      throw const FormatException('Unsafe Odoo catalog URL.');
    }
    return resolved.toString();
  }

  static CatalogPage<T> _page<T>(
    StoreApiResponse response,
    int page,
    int perPage,
    T Function(Map<String, dynamic>) parse,
  ) {
    final List<dynamic> raw = _list(response.data);
    final int total = _header(response, 'x-wp-total');
    final int pages = _header(response, 'x-wp-totalpages');
    if (pages != (total == 0 ? 0 : (total + perPage - 1) ~/ perPage) ||
        raw.length > perPage ||
        raw.length > total ||
        (page > pages && raw.isNotEmpty)) {
      throw const FormatException('Inconsistent Odoo catalog pagination.');
    }
    // Do not discard malformed product records and then claim complete data.
    return CatalogPage<T>(
      items: List<T>.unmodifiable(raw.map((dynamic item) => parse(_map(item)))),
      page: page,
      perPage: perPage,
      totalItems: total,
      totalPages: pages,
    );
  }

  static int _header(StoreApiResponse response, String name) {
    final String? value = response.header(name);
    if (value == null || !RegExp(r'^\d+$').hasMatch(value)) {
      throw const FormatException(
        'Odoo catalog pagination headers are required.',
      );
    }
    return int.parse(value);
  }

  static void _bounds(int page, int perPage) {
    if (page < 1 || page > 100000 || perPage < 1 || perPage > 100) {
      throw ArgumentError('Odoo catalog page is outside the bounded range.');
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Invalid Odoo catalog object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(dynamic value) {
    if (value is! List) {
      throw const FormatException('Invalid Odoo catalog list.');
    }
    return value;
  }

  static void _positive(dynamic value) {
    if (value is! int || value <= 0) {
      throw const FormatException(
        'Odoo catalog ID must be a positive integer.',
      );
    }
  }

  static void _nonNegative(dynamic value) {
    if (value is! int || value < 0) {
      throw const FormatException('Odoo catalog count must be non-negative.');
    }
  }

  static String _nonEmpty(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Missing Odoo catalog text.');
    }
    return value;
  }

  static void _bool(dynamic value) {
    if (value is! bool) {
      throw const FormatException('Missing Odoo availability flag.');
    }
  }

  static void _stockStatus(dynamic value) {
    if (!const <String>{
      'instock',
      'outofstock',
      'onbackorder',
    }.contains(value)) {
      throw const FormatException('Invalid Odoo availability status.');
    }
  }

  static String _minor(dynamic value, {bool allowEmpty = false}) {
    if (allowEmpty && value == '') return '';
    if (value is! String || !RegExp(r'^\d+$').hasMatch(value)) {
      throw const FormatException('Invalid Odoo minor-unit price.');
    }
    return value;
  }

  static void _money(dynamic raw) {
    final Map<String, dynamic> money = _map(raw);
    if (money['currency_code'] is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(money['currency_code'] as String) ||
        money['currency_minor_unit'] is! int ||
        (money['currency_minor_unit'] as int) < 0 ||
        (money['currency_minor_unit'] as int) > 8) {
      throw const FormatException('Odoo currency precision is required.');
    }
    _minor(money['price']);
    _minor(money['regular_price'], allowEmpty: true);
    _minor(money['sale_price'], allowEmpty: true);
  }
}
