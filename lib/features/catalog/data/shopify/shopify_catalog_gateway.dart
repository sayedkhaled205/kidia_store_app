import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';

enum ShopifyCatalogSort {
  newest,
  priceLowToHigh,
  priceHighToLow,
  name,
  relevance,
}

/// Storefront products expose cursors, not WooCommerce page totals. Keep
/// that distinction instead of fabricating totalItems/totalPages for the UI.
class ShopifyCursorPage<T> {
  const ShopifyCursorPage({
    required this.items,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.startCursor,
    required this.endCursor,
  });

  final List<T> items;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final String? startCursor;
  final String? endCursor;
}

class ShopifyProductRecord {
  const ShopifyProductRecord({
    required this.product,
    required this.selectedVariantId,
    required this.variants,
    required this.requiresSellingPlan,
  });

  final CatalogProduct product;

  /// Shopify carts require a ProductVariant GID, never a product ID. The cart
  /// adapter must keep this mapping; existing WooCommerce cart is not reused.
  final String? selectedVariantId;

  /// Null on list cards: variants have not been fetched, not an empty result.
  final ShopifyCursorPage<CatalogVariation>? variants;
  final bool requiresSellingPlan;
}

/// Read-only Native catalog. Its repository can be selected independently;
/// this does not enable or certify customer auth/cart/checkout integration.
/// Requests are direct to the platform and always carry arguments as variables.
class ShopifyCatalogGateway {
  ShopifyCatalogGateway({
    required this.client,
    required Map<String, int> currencyMinorUnits,
    String? countryCode,
    String? languageCode,
  }) : countryCode = _contextCode(countryCode, language: false),
       languageCode = _contextCode(languageCode, language: true),
       _currencyMinorUnits = Map<String, int>.unmodifiable(currencyMinorUnits) {
    if (_currencyMinorUnits.values.any((int scale) => scale < 0 || scale > 4)) {
      throw const FormatException('Invalid currency precision.');
    }
  }

  final ShopifyStorefrontReader client;
  final String? countryCode;
  final String? languageCode;
  final Map<String, int> _currencyMinorUnits;

  Map<String, dynamic> get _context => <String, dynamic>{
    'country': countryCode,
    'language': languageCode,
  };

  Future<ShopifyCursorPage<ShopifyProductRecord>> getProducts({
    int first = 20,
    String? after,
    String search = '',
    ShopifyCatalogSort sort = ShopifyCatalogSort.newest,
    int? collectionId,
  }) async {
    _pageSize(first, 20);
    // A user search is a literal title search, not injected Shopify search DSL.
    final String term = search.trim();
    if (collectionId != null) {
      if (collectionId <= 0 || term.isNotEmpty) {
        throw ArgumentError(
          'Collection products do not support a text query here.',
        );
      }
      final Map<String, dynamic> data = await client.query(
        _collectionProducts,
        variables: <String, dynamic>{
          'id': 'gid://shopify/Collection/$collectionId',
          'first': first,
          'after': after,
          'sort': switch (sort) {
            ShopifyCatalogSort.newest => 'CREATED',
            ShopifyCatalogSort.priceLowToHigh ||
            ShopifyCatalogSort.priceHighToLow => 'PRICE',
            ShopifyCatalogSort.name => 'TITLE',
            ShopifyCatalogSort.relevance => 'COLLECTION_DEFAULT',
          },
          'reverse':
              sort == ShopifyCatalogSort.newest ||
              sort == ShopifyCatalogSort.priceHighToLow,
          ..._context,
        },
      );
      if (data['collection'] == null) {
        throw StateError('This collection is not published to the storefront.');
      }
      final Map<String, dynamic> collection = _map(data['collection']);
      if (_id(collection['id'], 'Collection') != collectionId) {
        throw const FormatException('Shopify returned a different collection.');
      }
      return _page<ShopifyProductRecord>(
        _map(collection['products']),
        _product,
      );
    }
    final String? query = term.isEmpty
        ? null
        : 'title:"${term.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    final Map<String, dynamic> data = await client.query(
      _listProducts,
      variables: <String, dynamic>{
        'first': first,
        'after': after,
        'search': query,
        'sort': switch (sort) {
          ShopifyCatalogSort.newest => 'CREATED_AT',
          ShopifyCatalogSort.priceLowToHigh ||
          ShopifyCatalogSort.priceHighToLow => 'PRICE',
          ShopifyCatalogSort.name => 'TITLE',
          ShopifyCatalogSort.relevance => term.isEmpty ? 'ID' : 'RELEVANCE',
        },
        'reverse':
            sort == ShopifyCatalogSort.newest ||
            sort == ShopifyCatalogSort.priceHighToLow,
        ..._context,
      },
    );
    return _page<ShopifyProductRecord>(_map(data['products']), _product);
  }

  Future<ShopifyProductRecord> getProduct(
    int productId, {
    String? variantAfter,
    int variantFirst = 50,
  }) async {
    if (productId <= 0) throw ArgumentError.value(productId, 'productId');
    _pageSize(variantFirst, 50);
    final Map<String, dynamic> data = await client.query(
      _productDetail,
      variables: <String, dynamic>{
        'id': 'gid://shopify/Product/$productId',
        'variantFirst': variantFirst,
        'variantAfter': variantAfter,
        ..._context,
      },
    );
    if (data['product'] == null) {
      throw StateError('This product is not published to the storefront.');
    }
    return _product(_map(data['product']));
  }

  /// Shopify collections are flat storefront groupings, not invented parent
  /// categories. Counts are deliberately not queried or claimed here.
  Future<ShopifyCursorPage<CatalogCategory>> getCollections({
    int first = 20,
    String? after,
  }) async {
    // Below Shopify's documented 250-node limit; category screens request100.
    _pageSize(first, 100);
    final Map<String, dynamic> data = await client.query(
      _collections,
      variables: <String, dynamic>{
        'first': first,
        'after': after,
        'sort': 'TITLE',
        ..._context,
      },
    );
    return _page<CatalogCategory>(_map(data['collections']), (node) {
      return _collection(node);
    });
  }

  Future<CatalogCategory> getCollection(int collectionId) async {
    if (collectionId <= 0) throw ArgumentError.value(collectionId);
    final data = await client.query(
      _collectionDetail,
      variables: {'id': 'gid://shopify/Collection/$collectionId', ..._context},
    );
    if (data['collection'] == null) {
      throw StateError('This selected collection is not published.');
    }
    final collection = _collection(_map(data['collection']));
    if (collection.id != collectionId) {
      throw const FormatException('Shopify returned a different collection.');
    }
    return collection;
  }

  static CatalogCategory _collection(Map<String, dynamic> node) =>
      CatalogCategory(
        id: _id(node['id'], 'Collection'),
        name: _text(node['title']),
        slug: _text(node['handle']),
        description: _text(node['description']),
        image: _image(node['image']),
      );

  ShopifyProductRecord _product(Map<String, dynamic> node) {
    final int id = _id(node['id'], 'Product');
    final Map<String, dynamic> range = _map(node['priceRange']);
    final Map<String, dynamic> minimum = _map(range['minVariantPrice']);
    final Map<String, dynamic> maximum = _map(range['maxVariantPrice']);
    final String currency = _text(minimum['currencyCode']);
    if (maximum['currencyCode'] != currency) {
      throw const FormatException('Product price range mixes currencies.');
    }
    final int? scale = _currencyMinorUnits[currency];
    if (scale == null) {
      throw FormatException(
        'Currency precision is not configured for $currency.',
      );
    }
    final String price = _minor(minimum['amount'], scale);
    final String maxPrice = _minor(maximum['amount'], scale);
    if (BigInt.parse(maxPrice) < BigInt.parse(price)) {
      throw const FormatException('Product price range is reversed.');
    }
    final dynamic selected = node['selectedOrFirstAvailableVariant'];
    final String? selectedId = selected is Map ? _text(selected['id']) : null;
    if (selectedId != null) _id(selectedId, 'ProductVariant');
    final Map<String, dynamic>? selectedPrice =
        selected is Map && selected['price'] is Map
        ? _map(selected['price'])
        : null;
    final Map<String, dynamic>? compare =
        selected is Map && selected['compareAtPrice'] is Map
        ? _map(selected['compareAtPrice'])
        : null;
    String regular = '';
    if (selectedPrice?['currencyCode'] == currency &&
        compare?['currencyCode'] == currency &&
        _minor(selectedPrice!['amount'], scale) == price) {
      final String candidate = _minor(compare!['amount'], scale);
      if (BigInt.parse(candidate) > BigInt.parse(price)) regular = candidate;
    }
    final bool available = _boolean(node['availableForSale']);
    final bool requiresSellingPlan = _boolean(node['requiresSellingPlan']);
    final dynamic images = node['images'];
    final List<CatalogImage> mappedImages = images is Map
        ? _list(
            images['nodes'],
          ).map(_image).whereType<CatalogImage>().toList(growable: false)
        : <CatalogImage>[];
    final ShopifyCursorPage<CatalogVariation>? variants =
        node['variants'] is Map
        ? _page<CatalogVariation>(_map(node['variants']), _variation)
        : null;
    final bool hasOptions = _list(node['options']).any((dynamic option) {
      final Map<String, dynamic> item = _map(option);
      final List<dynamic> values = _list(item['values']);
      return item['name'] != 'Title' ||
          values.length != 1 ||
          values.single != 'Default Title';
    });
    final CatalogMoney money = CatalogMoney(
      currencyCode: currency,
      currencySymbol: currency,
      currencyMinorUnit: scale,
      priceMinor: price,
      regularPriceMinor: regular,
      salePriceMinor: regular.isEmpty ? '' : price,
      priceRange: price == maxPrice
          ? null
          : CatalogPriceRange(minimumMinor: price, maximumMinor: maxPrice),
    );
    return ShopifyProductRecord(
      selectedVariantId: selectedId,
      requiresSellingPlan: requiresSellingPlan,
      variants: variants,
      product: CatalogProduct(
        id: id,
        name: _text(node['title']),
        slug: _text(node['handle']),
        type: hasOptions ? 'variable' : 'simple',
        description: _text(node['descriptionHtml']),
        summary: _text(node['description']),
        permalink: _https(node['onlineStoreUrl']),
        prices: money,
        isOnSale: regular.isNotEmpty,
        isPurchasable: available && selectedId != null && !requiresSellingPlan,
        // This is Shopify sellability, NOT an assertion about physical stock
        // quantity or backorders. The public response does not certify either.
        isInStock: available,
        stockStatus: CatalogStockStatus.unknown,
        images: List<CatalogImage>.unmodifiable(mappedImages),
        variations: hasOptions
            ? variants?.items ?? const <CatalogVariation>[]
            : const <CatalogVariation>[],
      ),
    );
  }

  CatalogVariation _variation(Map<String, dynamic> node) {
    final Map<String, dynamic> price = _map(node['price']);
    final String currency = _text(price['currencyCode']);
    final int? scale = _currencyMinorUnits[currency];
    if (scale == null) {
      throw const FormatException('Unknown currency precision.');
    }
    return CatalogVariation(
      id: _id(node['id'], 'ProductVariant'),
      isPurchasable: _boolean(node['availableForSale']),
      isInStock: _boolean(node['availableForSale']),
      prices: CatalogMoney(
        currencyCode: currency,
        currencySymbol: currency,
        currencyMinorUnit: scale,
        priceMinor: _minor(price['amount'], scale),
      ),
      image: _image(node['image']),
      attributes: List<CatalogVariationAttribute>.unmodifiable(
        _list(node['selectedOptions']).map((dynamic item) {
          final Map<String, dynamic> option = _map(item);
          return CatalogVariationAttribute(
            name: _text(option['name']),
            value: _text(option['value']),
          );
        }),
      ),
    );
  }

  static ShopifyCursorPage<T> _page<T>(
    Map<String, dynamic> connection,
    T Function(Map<String, dynamic>) map,
  ) {
    final Map<String, dynamic> info = _map(connection['pageInfo']);
    final bool next = _boolean(info['hasNextPage']);
    final String? end = info['endCursor'] as String?;
    if (next && (end == null || end.isEmpty)) {
      throw const FormatException('Next Storefront page has no cursor.');
    }
    return ShopifyCursorPage<T>(
      items: List<T>.unmodifiable(
        _list(connection['nodes']).map((dynamic node) => map(_map(node))),
      ),
      hasNextPage: next,
      hasPreviousPage: _boolean(info['hasPreviousPage']),
      startCursor: info['startCursor'] as String?,
      endCursor: end,
    );
  }

  static void _pageSize(int value, int maximum) {
    if (value < 1 || value > maximum) {
      throw ArgumentError.value(value, 'first', 'Must be 1..$maximum.');
    }
  }

  static String? _contextCode(String? source, {required bool language}) {
    if (source == null) return null;
    final String code = source.trim().toUpperCase();
    if (!(language ? RegExp(r'^[A-Z]{2}(_[A-Z]{2})?$') : RegExp(r'^[A-Z]{2}$'))
        .hasMatch(code)) {
      throw const FormatException('Invalid Shopify buyer context code.');
    }
    // Syntactic validation only. The store still decides supported markets and
    // translations; unsupported enum values fail visibly at the platform API.
    return code;
  }

  static int _id(dynamic source, String type) {
    final RegExpMatch? match = RegExp(
      '^gid://shopify/$type/([1-9][0-9]*)\$',
    ).firstMatch(_text(source));
    final int? value = match == null ? null : int.tryParse(match.group(1)!);
    if (value == null) {
      throw const FormatException('Invalid Shopify resource ID.');
    }
    return value;
  }

  static String _minor(dynamic source, int scale) {
    final RegExpMatch? match = RegExp(
      r'^(\d+)(?:\.(\d+))?$',
    ).firstMatch(_text(source));
    if (match == null) throw const FormatException('Invalid Shopify amount.');
    String fraction = match.group(2) ?? '';
    if (fraction.length > scale) {
      if (fraction.substring(scale).contains(RegExp(r'[1-9]'))) {
        throw const FormatException(
          'Price exceeds configured currency precision.',
        );
      }
      fraction = fraction.substring(0, scale);
    }
    return BigInt.parse(
      '${match.group(1)}${fraction.padRight(scale, '0')}',
    ).toString();
  }

  static CatalogImage? _image(dynamic source) {
    if (source == null) return null;
    final Map<String, dynamic> node = _map(source);
    final Uri? url = _https(node['url']);
    if (url == null) throw const FormatException('Invalid Shopify image URL.');
    return CatalogImage(source: url, alt: node['altText'] as String? ?? '');
  }

  static Uri? _https(dynamic source) {
    if (source == null) return null;
    final Uri? url = Uri.tryParse(_text(source));
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      return null;
    }
    return url;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Missing Storefront object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(dynamic value) {
    if (value is! List) throw const FormatException('Missing Storefront list.');
    return value;
  }

  static String _text(dynamic value) {
    if (value is! String) {
      throw const FormatException('Invalid Storefront text.');
    }
    return value;
  }

  static bool _boolean(dynamic value) {
    if (value is! bool) throw const FormatException('Invalid Storefront flag.');
    return value;
  }

  static const String _fields = '''
    id title handle description descriptionHtml onlineStoreUrl
    availableForSale requiresSellingPlan options { name values }
    priceRange {
      minVariantPrice { amount currencyCode }
      maxVariantPrice { amount currencyCode }
    }
    selectedOrFirstAvailableVariant {
      id price { amount currencyCode } compareAtPrice { amount currencyCode }
    }
  ''';
  static const String _pageInfo = '''
    pageInfo { hasNextPage hasPreviousPage startCursor endCursor }
  ''';
  static const String _listProducts =
      '''
    query NativeCatalog(\$first: Int!, \$after: String, \$search: String,
        \$sort: ProductSortKeys!, \$reverse: Boolean!,
        \$country: CountryCode, \$language: LanguageCode)
        @inContext(country: \$country, language: \$language) {
      products(first: \$first, after: \$after, query: \$search,
          sortKey: \$sort, reverse: \$reverse) {
        nodes { $_fields images(first: 1) { nodes { url altText } } }
        $_pageInfo
      }
    }
  ''';
  static const String _productDetail =
      '''
    query NativeProduct(\$id: ID!, \$variantFirst: Int!, \$variantAfter: String,
        \$country: CountryCode, \$language: LanguageCode)
        @inContext(country: \$country, language: \$language) {
      product(id: \$id) {
        $_fields images(first: 20) { nodes { url altText } }
        variants(first: \$variantFirst, after: \$variantAfter) {
          nodes {
            id availableForSale price { amount currencyCode }
            image { url altText } selectedOptions { name value }
          }
          $_pageInfo
        }
      }
    }
  ''';
  static const String _collectionProducts =
      '''
    query NativeCollectionProducts(\$id: ID!, \$first: Int!, \$after: String,
        \$sort: ProductCollectionSortKeys!, \$reverse: Boolean!,
        \$country: CountryCode, \$language: LanguageCode)
        @inContext(country: \$country, language: \$language) {
      collection(id: \$id) {
        id
        products(first: \$first, after: \$after, sortKey: \$sort, reverse: \$reverse) {
          nodes { $_fields images(first: 1) { nodes { url altText } } }
          $_pageInfo
        }
      }
    }
  ''';
  static const String _collections =
      '''
    query NativeCollections(\$first: Int!, \$after: String,
        \$sort: CollectionSortKeys!,
        \$country: CountryCode, \$language: LanguageCode)
        @inContext(country: \$country, language: \$language) {
      collections(first: \$first, after: \$after, sortKey: \$sort) {
        nodes { id title handle description image { url altText } }
        $_pageInfo
      }
    }
  ''';
  static const String _collectionDetail = '''
    query NativeSelectedCollection(\$id: ID!,
        \$country: CountryCode, \$language: LanguageCode)
        @inContext(country: \$country, language: \$language) {
      collection(id: \$id) { id title handle description image { url altText } }
    }
  ''';
}
