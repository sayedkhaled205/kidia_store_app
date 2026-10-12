import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';

/// Exact platform decimal value: no client-side tax/discount/total arithmetic.
class ShopifyCartMoney {
  const ShopifyCartMoney({required this.amount, required this.currencyCode});
  final String amount;
  final String currencyCode;
}

class ShopifyCartLine {
  const ShopifyCartLine({
    required this.id,
    required this.variantId,
    required this.productId,
    required this.title,
    required this.quantity,
    required this.availableForSale,
    required this.total,
    required this.subtotal,
    required this.unitPrice,
    required this.compareAtPrice,
    required this.sku,
    required this.imageUrl,
    required this.options,
    required this.requiresShipping,
    required this.minimumQuantity,
    required this.maximumQuantity,
    required this.quantityIncrement,
  });
  final String id;
  final String variantId;
  final String productId;
  final String title;
  final int quantity;
  final bool availableForSale;
  final ShopifyCartMoney total;
  final ShopifyCartMoney subtotal;
  final ShopifyCartMoney unitPrice;
  final ShopifyCartMoney? compareAtPrice;
  final String sku;
  final String imageUrl;
  final Map<String, String> options;
  final bool requiresShipping;
  final int minimumQuantity;
  final int? maximumQuantity;
  final int quantityIncrement;

  @override
  String toString() => 'ShopifyCartLine(quantity: $quantity, IDs redacted)';
}

class ShopifyCartDiscount {
  const ShopifyCartDiscount({required this.code, required this.applicable});
  final String code;
  final bool applicable;
}

class ShopifyCartSnapshot {
  const ShopifyCartSnapshot({
    required this.id,
    required this.checkoutUrl,
    required this.totalQuantity,
    required this.lines,
    required this.hasNextLinePage,
    required this.endLineCursor,
    required this.subtotal,
    required this.total,
    required this.subtotalEstimated,
    required this.totalEstimated,
    required this.discounts,
    required this.updatedAt,
    required this.buyerCountryCode,
  });

  /// Full opaque GID, including its buyer secret key. Persist only in secure
  /// buyer-session storage; never log, truncate, parse into an integer, or send
  /// to the central builder.
  final String id;
  final Uri checkoutUrl;
  final int totalQuantity;
  final List<ShopifyCartLine> lines;
  final bool hasNextLinePage;
  final String? endLineCursor;
  final ShopifyCartMoney subtotal;
  final ShopifyCartMoney total;
  final bool subtotalEstimated;
  final bool totalEstimated;
  final List<ShopifyCartDiscount> discounts;
  final String updatedAt;
  final String? buyerCountryCode;

  @override
  String toString() =>
      'ShopifyCartSnapshot(quantity: $totalQuantity, '
      'cart and checkout credentials redacted)';
}

class ShopifyCartIssue {
  const ShopifyCartIssue({required this.code, required this.message});
  final String code;
  final String message;

  @override
  String toString() => 'ShopifyCartIssue($code)';
}

class ShopifyCartMutationResult {
  const ShopifyCartMutationResult({
    required this.cart,
    required this.errors,
    required this.warnings,
  });
  final ShopifyCartSnapshot? cart;
  final List<ShopifyCartIssue> errors;
  final List<ShopifyCartIssue> warnings;
  bool get accepted => cart != null && errors.isEmpty;
}

class ShopifyCartMutationFailure implements Exception {
  const ShopifyCartMutationFailure({required this.needsReconciliation});

  /// True means the write may have reached Shopify even though no usable
  /// response returned. Re-read a known cart; NEVER automatically replay/create.
  final bool needsReconciliation;

  @override
  String toString() => needsReconciliation
      ? 'Cart mutation outcome is unknown; reconcile before another write.'
      : 'Shopify rejected the cart request.';
}

class ShopifyCartLineInput {
  ShopifyCartLineInput({required this.variantId, required this.quantity}) {
    _gid(variantId, 'ProductVariant');
    _quantity(quantity);
  }
  final String variantId;
  final int quantity;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'merchandiseId': variantId,
    'quantity': quantity,
  };
}

/// Direct Shopify buyer-cart protocol foundation. It deliberately does not
/// submit an order/payment, open checkout, or substitute the Woo cart provider.
class ShopifyCartGateway {
  ShopifyCartGateway({
    required this.transport,
    required CommerceConnection connection,
    Set<String> trustedCheckoutHosts = const <String>{},
    String? countryCode,
    String? languageCode,
  }) : _checkoutHosts = Set<String>.unmodifiable(<String>{
         connection.storeOrigin.host,
         ...trustedCheckoutHosts.map((String host) => host.toLowerCase()),
       }),
       countryCode = _context(countryCode, false),
       languageCode = _context(languageCode, true) {
    if (connection.platform != CommercePlatform.shopify) {
      throw const FormatException(
        'Shopify cart requires a Shopify connection.',
      );
    }
    connection.requireCapability(CustomerCommerceCapability.cart);
    if (_checkoutHosts.any(
      (String host) => host.isEmpty || host.contains(RegExp(r'[^a-z0-9.-]')),
    )) {
      throw const FormatException('Checkout hosts must be explicit DNS names.');
    }
  }

  final ShopifyStorefrontCartTransport transport;
  final Set<String> _checkoutHosts;
  final String? countryCode;
  final String? languageCode;

  Map<String, dynamic> get _variables => <String, dynamic>{
    'country': countryCode,
    'language': languageCode,
  };

  Future<ShopifyCartSnapshot> getCart(
    String cartId, {
    int first = 50,
    String? after,
  }) async {
    _gid(cartId, 'Cart');
    if (first < 1 || first > 50) throw ArgumentError.value(first, 'first');
    final Map<String, dynamic> data = await transport.query(
      _read,
      variables: <String, dynamic>{
        'id': cartId,
        'first': first,
        'after': after,
        ..._variables,
      },
    );
    if (data['cart'] == null) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.notFound,
        message: 'Shopify cart is unavailable or expired.',
      );
    }
    final ShopifyCartSnapshot cart = _cart(_map(data['cart']));
    if (cart.id != cartId) {
      throw const FormatException('Shopify returned a different buyer cart.');
    }
    return cart;
  }

  Future<ShopifyCartMutationResult> createCart({
    List<ShopifyCartLineInput> lines = const <ShopifyCartLineInput>[],
  }) {
    _batch(lines.length, allowEmpty: true);
    return _mutate('cartCreate', _create, <String, dynamic>{
      'input': <String, dynamic>{
        'lines': lines.map((line) => line.toJson()).toList(growable: false),
        if (countryCode != null)
          'buyerIdentity': <String, dynamic>{'countryCode': countryCode},
      },
    });
  }

  Future<ShopifyCartMutationResult> addLines(
    String cartId,
    List<ShopifyCartLineInput> lines,
  ) {
    _gid(cartId, 'Cart');
    _batch(lines.length);
    return _mutate('cartLinesAdd', _add, <String, dynamic>{
      'cartId': cartId,
      'lines': lines.map((line) => line.toJson()).toList(growable: false),
    });
  }

  Future<ShopifyCartMutationResult> updateQuantity(
    String cartId, {
    required String lineId,
    required int quantity,
  }) {
    _gid(cartId, 'Cart');
    _gid(lineId, 'CartLine');
    _quantity(quantity);
    return _mutate('cartLinesUpdate', _update, <String, dynamic>{
      'cartId': cartId,
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{'id': lineId, 'quantity': quantity},
      ],
    });
  }

  Future<ShopifyCartMutationResult> removeLines(
    String cartId,
    List<String> lineIds,
  ) {
    _gid(cartId, 'Cart');
    _batch(lineIds.length);
    for (final String id in lineIds) {
      _gid(id, 'CartLine');
    }
    return _mutate('cartLinesRemove', _remove, <String, dynamic>{
      'cartId': cartId,
      'lineIds': lineIds,
    });
  }

  Future<ShopifyCartMutationResult> updateDiscountCodes(
    String cartId,
    List<String> codes,
  ) {
    _gid(cartId, 'Cart');
    _batch(codes.length, allowEmpty: true);
    if (codes.any(
      (String code) =>
          code.trim().isEmpty ||
          code.length > 255 ||
          code.contains(RegExp(r'[\x00-\x1f\x7f]')),
    )) {
      throw const FormatException('Invalid cart discount code.');
    }
    return _mutate('cartDiscountCodesUpdate', _discounts, <String, dynamic>{
      'cartId': cartId,
      'codes': codes,
    });
  }

  /// The caller owns buyer authentication and secure token lifecycle. This
  /// method accepts no merchant/admin credentials. Null token requests removal
  /// of the previous buyer token; live logout/session behavior must be tested
  /// alongside the actual Customer Account flow. No profile is queried here.
  Future<ShopifyCartMutationResult> updateBuyerIdentity(
    String cartId, {
    required String countryCode,
    String? customerAccessToken,
  }) {
    _gid(cartId, 'Cart');
    final String? country = _context(countryCode, false);
    if (customerAccessToken != null &&
        (customerAccessToken.isEmpty ||
            customerAccessToken.length > 8192 ||
            customerAccessToken.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
            RegExp(
              r'^(shpat_|shpca_|shpss_|shpua_)',
            ).hasMatch(customerAccessToken))) {
      throw const FormatException('Invalid customer access token.');
    }
    return _mutate('cartBuyerIdentityUpdate', _buyer, <String, dynamic>{
      'cartId': cartId,
      'buyer': <String, dynamic>{
        'countryCode': country,
        'customerAccessToken': customerAccessToken,
      },
    });
  }

  Future<ShopifyCartMutationResult> _mutate(
    String operation,
    String document,
    Map<String, dynamic> variables,
  ) async {
    try {
      final Map<String, dynamic> data = await transport.cartMutation(
        document,
        variables: <String, dynamic>{
          ...variables,
          ..._variables,
          'first': 50,
          'after': null,
        },
      );
      final Map<String, dynamic> result = _map(data[operation]);
      final List<ShopifyCartIssue> errors = _issues(result['userErrors']);
      final List<ShopifyCartIssue> warnings = _issues(result['warnings']);
      final ShopifyCartSnapshot? cart = result['cart'] == null
          ? null
          : _cart(_map(result['cart']));
      if (cart != null &&
          variables['cartId'] != null &&
          cart.id != variables['cartId']) {
        throw const FormatException('Shopify returned a different buyer cart.');
      }
      if (cart == null && errors.isEmpty) {
        throw const FormatException(
          'Mutation returned neither cart nor error.',
        );
      }
      return ShopifyCartMutationResult(
        cart: cart,
        errors: errors,
        warnings: warnings,
      );
    } on StoreApiException catch (error) {
      final int? status = error.statusCode;
      throw ShopifyCartMutationFailure(
        needsReconciliation:
            error.kind != StoreApiFailureKind.configuration &&
            !(status != null && status >= 400 && status < 500),
      );
    } on FormatException {
      throw const ShopifyCartMutationFailure(needsReconciliation: true);
    }
  }

  ShopifyCartSnapshot _cart(Map<String, dynamic> data) {
    final String id = _string(data['id']);
    _gid(id, 'Cart');
    final Uri? checkout = Uri.tryParse(_string(data['checkoutUrl']));
    if (checkout == null ||
        checkout.scheme != 'https' ||
        checkout.userInfo.isNotEmpty ||
        !_checkoutHosts.contains(checkout.host) ||
        (checkout.hasPort && checkout.port != 443)) {
      throw const FormatException(
        'Checkout is not on a verified platform host.',
      );
    }
    final Map<String, dynamic> lines = _map(data['lines']);
    final Map<String, dynamic> page = _map(lines['pageInfo']);
    final bool hasNext = _bool(page['hasNextPage']);
    final dynamic rawCursor = page['endCursor'];
    if (rawCursor != null && rawCursor is! String) {
      throw const FormatException('Invalid cart page cursor.');
    }
    final String? cursor = rawCursor as String?;
    if (hasNext && (cursor == null || cursor.isEmpty)) {
      throw const FormatException('Cart next page lacks a cursor.');
    }
    final Map<String, dynamic> cost = _map(data['cost']);
    final String updatedAt = _string(data['updatedAt']);
    if (DateTime.tryParse(updatedAt) == null) {
      throw const FormatException('Invalid cart revision.');
    }
    final dynamic country = _map(data['buyerIdentity'])['countryCode'];
    if (country != null &&
        (country is! String || !RegExp(r'^[A-Z]{2}$').hasMatch(country))) {
      throw const FormatException('Invalid cart buyer country.');
    }
    final ShopifyCartMoney subtotal = _money(cost['subtotalAmount']);
    final ShopifyCartMoney total = _money(cost['totalAmount']);
    if (subtotal.currencyCode != total.currencyCode) {
      throw const FormatException('Cart amounts mix currencies.');
    }
    final List<ShopifyCartLine> items = _list(lines['nodes'])
        .map((dynamic raw) {
          final Map<String, dynamic> line = _map(raw);
          final String lineId = _string(line['id']);
          _gid(lineId, 'CartLine');
          final Map<String, dynamic> merchandise = _map(line['merchandise']);
          final String variant = _string(merchandise['id']);
          _gid(variant, 'ProductVariant');
          final Map<String, dynamic> product = _map(merchandise['product']);
          final String productId = _string(product['id']);
          _gid(productId, 'Product');
          final ShopifyCartMoney lineTotal = _money(
            _map(line['cost'])['totalAmount'],
          );
          final Map<String, dynamic> lineCost = _map(line['cost']);
          final ShopifyCartMoney lineSubtotal = _money(
            lineCost['subtotalAmount'],
          );
          final ShopifyCartMoney unitPrice = _money(
            lineCost['amountPerQuantity'],
          );
          final ShopifyCartMoney? compareAt =
              lineCost['compareAtAmountPerQuantity'] == null
              ? null
              : _money(lineCost['compareAtAmountPerQuantity']);
          if (<ShopifyCartMoney>[
            lineTotal,
            lineSubtotal,
            unitPrice,
            ?compareAt,
          ].any((money) => money.currencyCode != total.currencyCode)) {
            throw const FormatException(
              'Cart line currency differs from cart.',
            );
          }
          final Map<String, dynamic> quantityRule = _map(
            merchandise['quantityRule'],
          );
          final int minimum = _int(quantityRule['minimum'], positive: true);
          final int increment = _int(quantityRule['increment'], positive: true);
          final int? maximum = quantityRule['maximum'] == null
              ? null
              : _int(quantityRule['maximum'], positive: true);
          if (maximum != null && maximum < minimum) {
            throw const FormatException('Invalid Shopify quantity rule.');
          }
          final Map<String, String> options = <String, String>{};
          for (final dynamic option in _list(merchandise['selectedOptions'])) {
            final Map<String, dynamic> item = _map(option);
            final String name = _string(item['name']);
            if (options.containsKey(name)) {
              throw const FormatException('Duplicate Shopify variant option.');
            }
            options[name] = _string(item['value']);
          }
          final dynamic image = merchandise['image'];
          final String imageUrl = image == null
              ? ''
              : _string(_map(image)['url']);
          final Uri? parsedImage = imageUrl.isEmpty
              ? null
              : Uri.tryParse(imageUrl);
          if (imageUrl.isNotEmpty &&
              (parsedImage == null ||
                  parsedImage.scheme != 'https' ||
                  parsedImage.host.isEmpty ||
                  parsedImage.userInfo.isNotEmpty ||
                  parsedImage.hasFragment ||
                  (parsedImage.hasPort && parsedImage.port != 443))) {
            throw const FormatException('Invalid Shopify cart image.');
          }
          return ShopifyCartLine(
            id: lineId,
            variantId: variant,
            productId: productId,
            title: _string(product['title']),
            quantity: _int(line['quantity'], positive: true),
            availableForSale: _bool(merchandise['availableForSale']),
            total: lineTotal,
            subtotal: lineSubtotal,
            unitPrice: unitPrice,
            compareAtPrice: compareAt,
            sku: merchandise['sku'] == null ? '' : _string(merchandise['sku']),
            imageUrl: imageUrl,
            options: Map<String, String>.unmodifiable(options),
            requiresShipping: _bool(merchandise['requiresShipping']),
            minimumQuantity: minimum,
            maximumQuantity: maximum,
            quantityIncrement: increment,
          );
        })
        .toList(growable: false);
    return ShopifyCartSnapshot(
      id: id,
      checkoutUrl: checkout,
      totalQuantity: _int(data['totalQuantity']),
      lines: List.unmodifiable(items),
      hasNextLinePage: hasNext,
      endLineCursor: cursor,
      subtotal: subtotal,
      total: total,
      subtotalEstimated: _bool(cost['subtotalAmountEstimated']),
      totalEstimated: _bool(cost['totalAmountEstimated']),
      discounts: List<ShopifyCartDiscount>.unmodifiable(
        _list(data['discountCodes']).map((dynamic raw) {
          final Map<String, dynamic> discount = _map(raw);
          return ShopifyCartDiscount(
            code: _string(discount['code']),
            applicable: _bool(discount['applicable']),
          );
        }),
      ),
      updatedAt: updatedAt,
      buyerCountryCode: country as String?,
    );
  }

  static ShopifyCartMoney _money(dynamic raw) {
    final Map<String, dynamic> data = _map(raw);
    final String amount = _string(data['amount']);
    final String currency = _string(data['currencyCode']);
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(amount) ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const FormatException('Invalid cart money.');
    }
    return ShopifyCartMoney(amount: amount, currencyCode: currency);
  }

  static List<ShopifyCartIssue> _issues(dynamic value) =>
      List<ShopifyCartIssue>.unmodifiable(
        _list(value).map((dynamic raw) {
          final Map<String, dynamic> item = _map(raw);
          return ShopifyCartIssue(
            code: item['code'] == null ? 'UNKNOWN' : _string(item['code']),
            message: _string(item['message']),
          );
        }),
      );

  static void _batch(int count, {bool allowEmpty = false}) {
    if (count < (allowEmpty ? 0 : 1) || count > 50) {
      throw ArgumentError(
        'Cart batch must contain ${allowEmpty ? 0 : 1}..50 items.',
      );
    }
  }

  static String? _context(String? value, bool language) {
    if (value == null) return null;
    final String code = value.trim().toUpperCase();
    if (!(language ? RegExp(r'^[A-Z]{2}(_[A-Z]{2})?$') : RegExp(r'^[A-Z]{2}$'))
        .hasMatch(code)) {
      throw const FormatException('Invalid buyer context.');
    }
    return code;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) throw const FormatException('Missing cart object.');
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(dynamic value) {
    if (value is! List) throw const FormatException('Missing cart list.');
    return value;
  }

  static String _string(dynamic value) {
    if (value is! String) throw const FormatException('Invalid cart text.');
    return value;
  }

  static bool _bool(dynamic value) {
    if (value is! bool) throw const FormatException('Invalid cart flag.');
    return value;
  }

  static int _int(dynamic value, {bool positive = false}) {
    if (value is! int || value < (positive ? 1 : 0)) {
      throw const FormatException('Invalid cart quantity.');
    }
    return value;
  }

  static const String _fields = '''
    id checkoutUrl totalQuantity updatedAt buyerIdentity { countryCode }
    discountCodes { code applicable }
    cost { subtotalAmount { amount currencyCode } subtotalAmountEstimated
      totalAmount { amount currencyCode } totalAmountEstimated }
    lines(first: \$first, after: \$after) {
      nodes { id quantity cost { totalAmount { amount currencyCode }
        subtotalAmount { amount currencyCode } amountPerQuantity { amount currencyCode }
        compareAtAmountPerQuantity { amount currencyCode } }
        merchandise { ... on ProductVariant { id availableForSale sku
          requiresShipping quantityRule { minimum maximum increment }
          image { url } selectedOptions { name value }
          product { id title } } } }
      pageInfo { hasNextPage endCursor }
    }
  ''';
  static const String _result =
      '''
    cart { $_fields } userErrors { code message } warnings { code message }
  ''';
  static const String _arguments = '''
    \$first: Int!, \$after: String, \$country: CountryCode, \$language: LanguageCode
  ''';
  static const String _contextDirective = '''
    @inContext(country: \$country, language: \$language)
  ''';
  static const String _read =
      '''
    query NativeCart(\$id: ID!, $_arguments) $_contextDirective {
      cart(id: \$id) { $_fields }
    }
  ''';
  static const String _create =
      '''
    mutation NativeCartCreate(\$input: CartInput!, $_arguments) $_contextDirective {
      cartCreate(input: \$input) { $_result }
    }
  ''';
  static const String _add =
      '''
    mutation NativeCartAdd(\$cartId: ID!, \$lines: [CartLineInput!]!, $_arguments)
      $_contextDirective { cartLinesAdd(cartId: \$cartId, lines: \$lines) { $_result } }
  ''';
  static const String _update =
      '''
    mutation NativeCartUpdate(\$cartId: ID!, \$lines: [CartLineUpdateInput!]!, $_arguments)
      $_contextDirective { cartLinesUpdate(cartId: \$cartId, lines: \$lines) { $_result } }
  ''';
  static const String _remove =
      '''
    mutation NativeCartRemove(\$cartId: ID!, \$lineIds: [ID!]!, $_arguments)
      $_contextDirective { cartLinesRemove(cartId: \$cartId, lineIds: \$lineIds) { $_result } }
  ''';
  static const String _discounts =
      '''
    mutation NativeCartDiscounts(\$cartId: ID!, \$codes: [String!]!, $_arguments)
      $_contextDirective { cartDiscountCodesUpdate(cartId: \$cartId,
        discountCodes: \$codes) { $_result } }
  ''';
  static const String _buyer =
      '''
    mutation NativeCartBuyer(\$cartId: ID!, \$buyer: CartBuyerIdentityInput!, $_arguments)
      $_contextDirective { cartBuyerIdentityUpdate(cartId: \$cartId,
        buyerIdentity: \$buyer) { $_result } }
  ''';
}

void _gid(String value, String type) {
  final Uri? uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'gid' ||
      uri.host != 'shopify' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      value.length > 4096 ||
      uri.pathSegments.length != 2 ||
      uri.pathSegments.first != type ||
      uri.pathSegments.last.isEmpty ||
      ((type == 'Product' || type == 'ProductVariant') && uri.hasQuery) ||
      (type == 'Cart' &&
          (uri.queryParametersAll['key']?.length != 1 ||
              uri.queryParameters['key']!.isEmpty)) ||
      ((type == 'Product' || type == 'ProductVariant') &&
          !RegExp(r'^[1-9][0-9]*$').hasMatch(uri.pathSegments.last)) ||
      value.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
    throw const FormatException('Invalid Shopify cart resource ID.');
  }
}

void _quantity(int value) {
  if (value <= 0 || value > 2147483647) {
    throw ArgumentError('Cart quantity must be a positive GraphQL Int.');
  }
}
