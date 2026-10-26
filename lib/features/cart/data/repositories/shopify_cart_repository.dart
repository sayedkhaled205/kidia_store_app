import 'dart:async';
import 'package:mobishop_store_app/core/commerce/currency_minor_units.dart';

import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_buyer_cart_session.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_gateway.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_variant_resolver.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_address.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_coupon.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_totals.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';

/// Direct Shopify guest cart, selected independently of the Woo customer APIs.
/// No Customer Account identity, profile, order, payment, Admin credential, or
/// builder relay is consumed. Checkout is only a verified URL in returned data.
class ShopifyCartRepository implements CartRepository {
  ShopifyCartRepository({
    required this.gateway,
    required this.session,
    required this.variantResolver,
    required CommerceConnection connection,
    Map<String, int> currencyMinorUnits = supportedCurrencyMinorUnits,
    bool Function()? isCurrentSession,
  }) : _currencyMinorUnits = Map<String, int>.unmodifiable(currencyMinorUnits),
       _isCurrentSession = isCurrentSession ?? (() => true),
       _countryCode = gateway.countryCode {
    if (!session.belongsTo(connection)) {
      throw const FormatException(
        'Shopify cart session belongs to another storefront.',
      );
    }
    if (_currencyMinorUnits.values.any((scale) => scale < 0 || scale > 4)) {
      throw const FormatException('Invalid Shopify cart currency precision.');
    }
  }

  static const Map<String, int> supportedCurrencyMinorUnits =
      commerceCurrencyMinorUnits;
  final ShopifyCartGateway gateway;
  final ShopifyBuyerCartSession session;
  final ShopifyCartVariantResolver variantResolver;
  final Map<String, int> _currencyMinorUnits;
  final bool Function() _isCurrentSession;
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;
  String? _countryCode;

  @override
  Future<Cart> getCart() => _enqueue((owner) async {
    if (session.cartId == null) {
      _requireCertainCreation();
      return _write(() => gateway.createCart(), owner);
    }
    return _readKnown(owner);
  });

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const <CartItemVariation>[],
  }) => _enqueue((owner) async {
    if (productId <= 0 ||
        quantity <= 0 ||
        quantity > 2147483647 ||
        variation.any(
          (option) => option.attribute.isEmpty || option.value.isEmpty,
        )) {
      throw _invalid('Choose a product and a positive Shopify quantity.');
    }
    _requireCertainCreation();
    final String variant = await variantResolver.resolve(
      productId: productId,
      variation: variation,
      countryCode: _countryCode,
      languageCode: gateway.languageCode,
    );
    _checkOwner(owner);
    final line = ShopifyCartLineInput(variantId: variant, quantity: quantity);
    if (session.cartId == null) {
      return _write(() => gateway.createCart(lines: [line]), owner);
    }
    await _ready(owner);
    return _write(() => gateway.addLines(session.snapshot!.id, [line]), owner);
  });

  @override
  Future<Cart> updateItem({required String key, required int quantity}) =>
      _enqueue((owner) async {
        if (quantity <= 0 || quantity > 2147483647) {
          throw _invalid('Use removeItem for a zero Shopify quantity.');
        }
        await _ready(owner);
        final ShopifyCartLine line = _ownedLine(key);
        if (quantity < line.minimumQuantity ||
            quantity > (line.maximumQuantity ?? 2147483647) ||
            quantity % line.quantityIncrement != 0) {
          throw _invalid('This quantity does not meet Shopify quantity rules.');
        }
        return _write(
          () => gateway.updateQuantity(
            session.snapshot!.id,
            lineId: key,
            quantity: quantity,
          ),
          owner,
        );
      });

  @override
  Future<Cart> removeItem(String key) => _enqueue((owner) async {
    await _ready(owner);
    _ownedLine(key);
    return _write(
      () => gateway.removeLines(session.snapshot!.id, [key]),
      owner,
    );
  });

  @override
  Future<Cart> applyCoupon(String code) => _enqueue((owner) async {
    final String coupon = _coupon(code);
    await _ready(owner);
    final List<String> codes = session.snapshot!.discounts
        .map((d) => d.code)
        .toList();
    if (!codes.any((value) => value.toLowerCase() == coupon.toLowerCase())) {
      codes.add(coupon);
    }
    final Cart cart = await _write(
      () => gateway.updateDiscountCodes(session.snapshot!.id, codes),
      owner,
    );
    if (!session.snapshot!.discounts.any(
      (discount) =>
          discount.applicable &&
          discount.code.toLowerCase() == coupon.toLowerCase(),
    )) {
      throw CartRepositoryException(
        kind: CartFailureKind.invalidInput,
        message: 'Shopify did not apply this discount code.',
        serverCart: cart,
      );
    }
    return cart;
  });

  @override
  Future<Cart> removeCoupon(String code) => _enqueue((owner) async {
    final String coupon = _coupon(code);
    await _ready(owner);
    final List<String> codes = session.snapshot!.discounts
        .where((d) => d.code.toLowerCase() != coupon.toLowerCase())
        .map((d) => d.code)
        .toList();
    return _write(
      () => gateway.updateDiscountCodes(session.snapshot!.id, codes),
      owner,
    );
  });

  /// Country-only guest pricing update. Account tokens cannot enter this path.
  Future<Cart> updateBuyerCountry(String countryCode) =>
      _enqueue((owner) async {
        final String country = countryCode.trim().toUpperCase();
        if (!RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
          throw _invalid('Invalid buyer country.');
        }
        await _ready(owner);
        final Cart cart = await _write(
          () => gateway.updateBuyerIdentity(
            session.snapshot!.id,
            countryCode: country,
          ),
          owner,
        );
        if (session.snapshot!.buyerCountryCode != country) {
          await session.markUncertain(owner);
          throw const CartRepositoryException(
            kind: CartFailureKind.invalidResponse,
            message: 'Shopify did not confirm the requested buyer country.',
          );
        }
        _countryCode = country;
        return cart;
      });

  void dispose() => _disposed = true;

  Future<void> _ready(int owner) async {
    _requireCertainCreation();
    if (session.cartId == null) {
      throw _invalid('Load the Shopify guest cart first.');
    }
    if (session.needsReconciliation ||
        session.snapshot == null ||
        session.snapshot!.hasNextLinePage) {
      await _readKnown(owner);
    }
    _checkOwner(owner);
  }

  void _requireCertainCreation() {
    if (session.creationUncertain) {
      throw const CartRepositoryException(
        kind: CartFailureKind.conflict,
        message:
            'The previous Shopify cart creation outcome is unknown. '
            'Explicitly reset the guest session before starting another cart.',
      );
    }
  }

  ShopifyCartLine _ownedLine(String key) {
    for (final line in session.snapshot!.lines) {
      if (line.id == key) return line;
    }
    throw _invalid(
      'This line does not belong to the current Shopify buyer cart.',
    );
  }

  Future<Cart> _readKnown(int owner) async {
    try {
      final ShopifyCartSnapshot snapshot = await gateway.getCart(
        session.cartId!,
      );
      _checkOwner(owner);
      return await _accept(snapshot, owner);
    } on StoreApiException catch (error) {
      _checkOwner(owner);
      if (error.kind == StoreApiFailureKind.notFound) {
        await session.clearExpired(owner);
        // Only clear this expired owner. Never create/replay in this request.
      }
      rethrow;
    }
  }

  Future<Cart> _write(
    Future<ShopifyCartMutationResult> Function() action,
    int owner,
  ) async {
    _checkOwner(owner);
    final bool creating = session.cartId == null;
    if (creating) {
      // Persist before the non-idempotent create, including process death.
      await session.markUncertain(owner);
    }
    try {
      final ShopifyCartMutationResult result = await action();
      _checkOwner(owner);
      final Cart? cart = result.cart == null
          ? null
          : await _accept(
              result.cart!,
              owner,
              issues: [...result.errors, ...result.warnings],
            );
      if (!result.accepted) {
        if (creating && result.cart == null) await session.clearExpired(owner);
        throw CartRepositoryException(
          kind: CartFailureKind.invalidInput,
          message: 'Shopify rejected this cart change.',
          serverCart: cart,
        );
      }
      return cart!;
    } on ShopifyCartMutationFailure catch (error) {
      _checkOwner(owner);
      if (error.needsReconciliation) await session.markUncertain(owner);
      if (creating && !error.needsReconciliation) {
        await session.clearExpired(owner);
      }
      throw CartRepositoryException(
        kind: error.needsReconciliation
            ? CartFailureKind.conflict
            : CartFailureKind.server,
        message: error.needsReconciliation
            ? 'The Shopify cart change outcome is unknown. Refresh the cart before another change.'
            : 'Shopify rejected the cart request.',
      );
    }
  }

  Future<Cart> _accept(
    ShopifyCartSnapshot first,
    int owner, {
    List<ShopifyCartIssue> issues = const [],
  }) async {
    _checkOwner(owner);
    // Keep a successfully created ID even when pagination/model validation
    // fails. A later request can reconcile, but must never create a second cart.
    await session.accept(first, owner);
    try {
      final List<ShopifyCartLine> lines = [...first.lines];
      final Set<String> ids = first.lines.map((line) => line.id).toSet();
      if (ids.length != lines.length) {
        throw const FormatException('Duplicate cart line.');
      }
      final Set<String> cursors = <String>{};
      ShopifyCartSnapshot page = first;
      int pages = 1;
      while (page.hasNextLinePage) {
        if (++pages > 40 || !cursors.add(page.endLineCursor!)) {
          throw const FormatException(
            'Shopify cart pagination did not advance.',
          );
        }
        page = await gateway.getCart(first.id, after: page.endLineCursor);
        _checkOwner(owner);
        if (page.updatedAt != first.updatedAt ||
            page.totalQuantity != first.totalQuantity ||
            page.total.amount != first.total.amount ||
            page.subtotal.amount != first.subtotal.amount ||
            page.total.currencyCode != first.total.currencyCode ||
            page.buyerCountryCode != first.buyerCountryCode ||
            page.lines.isEmpty) {
          throw const FormatException(
            'Shopify cart changed during pagination; refresh it.',
          );
        }
        for (final line in page.lines) {
          if (!ids.add(line.id)) {
            throw const FormatException('Repeated Shopify cart line.');
          }
          lines.add(line);
        }
      }
      if (lines.fold<int>(0, (sum, line) => sum + line.quantity) !=
          first.totalQuantity) {
        throw const FormatException('Incomplete Shopify cart quantities.');
      }
      final ShopifyCartSnapshot complete = ShopifyCartSnapshot(
        id: first.id,
        checkoutUrl: first.checkoutUrl,
        totalQuantity: first.totalQuantity,
        lines: List<ShopifyCartLine>.unmodifiable(lines),
        hasNextLinePage: false,
        endLineCursor: page.endLineCursor,
        subtotal: first.subtotal,
        total: first.total,
        subtotalEstimated: first.subtotalEstimated,
        totalEstimated: first.totalEstimated,
        discounts: first.discounts,
        updatedAt: first.updatedAt,
        buyerCountryCode: first.buyerCountryCode,
      );
      final Cart cart = _mapCart(complete, issues);
      _checkOwner(owner);
      await session.accept(complete, owner);
      _countryCode = complete.buyerCountryCode;
      return cart;
    } catch (_) {
      if (!_disposed && session.generation == owner && _isCurrentSession()) {
        await session.markUncertain(owner);
      }
      rethrow;
    }
  }

  Cart _mapCart(ShopifyCartSnapshot snapshot, List<ShopifyCartIssue> issues) {
    final String code = snapshot.total.currencyCode;
    final int? scale = _currencyMinorUnits[code];
    if (scale == null) {
      throw const FormatException('Unknown Shopify cart currency precision.');
    }
    final CartCurrency currency = CartCurrency(
      code: code,
      symbol: code,
      minorUnit: scale,
      decimalSeparator: '.',
      thousandSeparator: ',',
      prefix: '$code ',
      suffix: '',
    );
    final List<CartItem> items = snapshot.lines.map((line) {
      final int? productId = int.tryParse(
        Uri.parse(line.productId).pathSegments.last,
      );
      if (productId == null || productId > 9007199254740991) {
        throw const FormatException(
          'Shopify product ID exceeds safe Native range.',
        );
      }
      final String unit = _minor(line.unitPrice.amount, scale);
      final String regular = line.compareAtPrice == null
          ? ''
          : _minor(line.compareAtPrice!.amount, scale);
      return CartItem(
        key: line.id,
        productId: productId,
        quantity: line.quantity,
        quantityLimits: CartItemQuantityLimits(
          minimum: line.minimumQuantity,
          maximum: line.maximumQuantity ?? 2147483647,
          multipleOf: line.quantityIncrement,
          editable: line.availableForSale,
        ),
        name: line.title,
        shortDescription: '',
        sku: line.sku,
        images: line.imageUrl.isEmpty
            ? []
            : [
                CartItemImage(
                  id: 0,
                  sourceUrl: line.imageUrl,
                  thumbnailUrl: line.imageUrl,
                  alt: line.title,
                ),
              ],
        variation: line.options.entries
            .where((e) => !(e.key == 'Title' && e.value == 'Default Title'))
            .map((e) => CartItemVariation(attribute: e.key, value: e.value))
            .toList(),
        prices: CartItemPrices(
          priceMinor: unit,
          regularPriceMinor: regular,
          salePriceMinor:
              regular.isNotEmpty && BigInt.parse(regular) > BigInt.parse(unit)
              ? unit
              : '',
          currency: currency,
        ),
        totals: CartItemTotals(
          subtotalMinor: _minor(line.subtotal.amount, scale),
          subtotalTaxMinor: '',
          totalMinor: _minor(line.total.amount, scale),
          totalTaxMinor: '',
          currency: currency,
        ),
        backordersAllowed: false,
        showBackorderBadge: false,
        soldIndividually: line.maximumQuantity == 1,
      );
    }).toList();
    return Cart(
      items: items,
      coupons: snapshot.discounts
          .where((d) => d.applicable)
          .map(
            (d) => CartCoupon(
              code: d.code,
              discountType: 'shopify',
              totals: CartCouponTotals(
                discountMinor: '',
                discountTaxMinor: '',
                currency: currency,
              ),
            ),
          )
          .toList(),
      totals: CartTotals(
        itemsMinor: _minor(snapshot.subtotal.amount, scale),
        itemsTaxMinor: '',
        feesMinor: '',
        feesTaxMinor: '',
        discountMinor: '',
        discountTaxMinor: '',
        shippingMinor: '',
        shippingTaxMinor: '',
        priceMinor: _minor(snapshot.total.amount, scale),
        taxMinor: '',
        currency: currency,
        subtotalEstimated: snapshot.subtotalEstimated,
        totalEstimated: snapshot.totalEstimated,
      ),
      shippingAddress: CartAddress(country: snapshot.buyerCountryCode ?? ''),
      billingAddress: const CartAddress(),
      itemsCount: snapshot.totalQuantity,
      itemsWeight: 0,
      needsPayment:
          BigInt.parse(_minor(snapshot.total.amount, scale)) > BigInt.zero,
      needsShipping: snapshot.lines.any((line) => line.requiresShipping),
      hasCalculatedShipping: false,
      paymentMethods: const [],
      checkoutUrl: snapshot.checkoutUrl,
      errors: issues
          .map(
            (issue) => CartError(
              code: _safeCode(issue.code),
              message:
                  'Shopify reported a cart issue (${_safeCode(issue.code)}).',
            ),
          )
          .toList(),
    );
  }

  static String _minor(String amount, int scale) {
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(amount)) {
      throw const FormatException('Invalid Shopify money.');
    }
    final List<String> parts = amount.split('.');
    final String fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > scale &&
        fraction.substring(scale).contains(RegExp('[1-9]'))) {
      throw const FormatException(
        'Shopify amount requires rounding; no total was invented.',
      );
    }
    return BigInt.parse(
      '${parts.first}${fraction.padRight(scale, '0').substring(0, scale)}',
    ).toString();
  }

  static String _safeCode(String code) =>
      RegExp(r'^[A-Z0-9_]{1,80}$').hasMatch(code) ? code : 'UNKNOWN';
  static String _coupon(String code) {
    final String value = code.trim();
    if (value.isEmpty ||
        value.length > 255 ||
        value.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw _invalid('Enter a valid Shopify discount code.');
    }
    return value;
  }

  void _checkOwner(int owner) {
    if (_disposed || session.generation != owner || !_isCurrentSession()) {
      throw const CartRepositoryException(
        kind: CartFailureKind.cancelled,
        message: 'The Shopify buyer session changed.',
      );
    }
  }

  Future<Cart> _enqueue(Future<Cart> Function(int owner) action) {
    final int owner = session.generation;
    final Completer<Cart> result = Completer<Cart>();
    _tail = _tail.then((_) async {
      try {
        _checkOwner(owner);
        await session.hydrate(owner);
        _checkOwner(owner);
        result.complete(await action(owner));
      } on CartRepositoryException catch (error, trace) {
        result.completeError(error, trace);
      } on StoreApiException catch (error, trace) {
        result.completeError(
          CartRepositoryException(
            kind: _failureKind(error.kind),
            statusCode: error.statusCode,
            message: error.message,
          ),
          trace,
        );
      } on FormatException catch (_, trace) {
        result.completeError(
          const CartRepositoryException(
            kind: CartFailureKind.invalidResponse,
            message:
                'Shopify returned unsupported or invalid cart data. No fallback cart was substituted.',
          ),
          trace,
        );
      } catch (_, trace) {
        result.completeError(
          const CartRepositoryException(
            kind: CartFailureKind.unknown,
            message: 'The Shopify guest cart request could not be completed.',
          ),
          trace,
        );
      }
    });
    return result.future;
  }

  static CartRepositoryException _invalid(String message) =>
      CartRepositoryException(
        kind: CartFailureKind.invalidInput,
        message: message,
      );
  static CartFailureKind _failureKind(StoreApiFailureKind kind) =>
      switch (kind) {
        StoreApiFailureKind.configuration => CartFailureKind.configuration,
        StoreApiFailureKind.timeout => CartFailureKind.timeout,
        StoreApiFailureKind.connection => CartFailureKind.connection,
        StoreApiFailureKind.cancelled => CartFailureKind.cancelled,
        StoreApiFailureKind.certificate => CartFailureKind.certificate,
        StoreApiFailureKind.unauthorized => CartFailureKind.unauthorized,
        StoreApiFailureKind.notFound => CartFailureKind.notFound,
        StoreApiFailureKind.server => CartFailureKind.server,
        StoreApiFailureKind.invalidResponse => CartFailureKind.invalidResponse,
        _ => CartFailureKind.unknown,
      };
}
