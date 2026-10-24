import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_address.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_totals.dart';

/// Projection of the exact Odoo website-sale quote. Prices, stock limits,
/// currency precision and tax totals are all supplied by Odoo, not the builder.
class OdooCart85 {
  const OdooCart85({
    required this.revision,
    required this.cart,
    required this.zeroTotalCheckout,
  });

  factory OdooCart85.fromResponse(
    Map<String, dynamic> response, {
    required int? customerId,
    required Uri origin,
  }) {
    if (response['cart_contract_version'] != '85.1' ||
        response['customer_id'] != customerId) {
      throw const FormatException('Unverified Odoo cart owner or contract.');
    }
    final raw = object85(response['cart']);
    final revision = text85(raw['revision'], maximum: 64);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(revision)) {
      throw const FormatException('Unverified Odoo cart revision.');
    }
    final currencyRaw = object85(raw['currency']);
    final code = text85(currencyRaw['code'], maximum: 3);
    final digits = int85(currencyRaw['minor_unit'], maximum: 8);
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
      throw const FormatException('Invalid Odoo currency.');
    }
    final currency = CartCurrency(
      code: code,
      symbol: text85(currencyRaw['symbol'], maximum: 16),
      minorUnit: digits,
      decimalSeparator: '.',
      thousandSeparator: ',',
      prefix: '$code ',
      suffix: '',
    );
    final totals = object85(raw['totals']);
    final total = minor85(totals['total_minor']);
    final taxes = minor85(totals['tax_minor']);
    minor85(totals['untaxed_minor']);
    final itemsRaw = raw['items'];
    if (itemsRaw is! List || itemsRaw.length > 1000) {
      throw const FormatException('Invalid Odoo cart lines.');
    }
    final ids = <int>{};
    var count = 0;
    final items = <CartItem>[];
    for (final itemRaw in itemsRaw) {
      final item = object85(itemRaw);
      final lineId = int85(item['line_id'], minimum: 1);
      if (!ids.add(lineId)) throw const FormatException('Duplicate Odoo line.');
      final productId = int85(item['product_id'], minimum: 1);
      final quantity = int85(item['quantity'], minimum: 1);
      count += quantity;
      final limits = object85(item['quantity_limit']);
      final maximum = int85(limits['maximum']);
      final minimum = int85(limits['minimum'], minimum: 1);
      final multiple = int85(limits['multiple_of'], minimum: 1);
      final editable = bool85(limits['editable']);
      if (editable && maximum > 0 && maximum < minimum) {
        throw const FormatException('Invalid Odoo quantity rules.');
      }
      final imageText = text85(item['image_url'], maximum: 2048);
      final parsedImage = imageText.isEmpty ? null : Uri.tryParse(imageText);
      final image = parsedImage == null ? null : origin.resolveUri(parsedImage);
      if (imageText.isNotEmpty &&
          (image == null ||
              image.scheme != 'https' ||
              image.host != origin.host ||
              image.userInfo.isNotEmpty ||
              image.port != origin.port)) {
        throw const FormatException('Unverified Odoo product image origin.');
      }
      final price = minor85(item['unit_price_minor']);
      final tax = minor85(item['tax_minor']);
      final subtotal = minor85(item['subtotal_minor']);
      final lineTotal = minor85(item['total_minor']);
      final stock = item['stock_remaining'] == null
          ? null
          : int85(item['stock_remaining']);
      items.add(
        CartItem(
          key: '$lineId',
          productId: productId,
          quantity: quantity,
          quantityLimits: CartItemQuantityLimits(
            minimum: minimum,
            maximum: maximum,
            multipleOf: multiple,
            editable: editable,
          ),
          name: text85(item['name'], maximum: 16000),
          shortDescription: '',
          sku: text85(item['sku'], maximum: 240),
          images: image == null
              ? const []
              : [
                  CartItemImage(
                    id: productId,
                    sourceUrl: image.toString(),
                    thumbnailUrl: image.toString(),
                    alt: '',
                  ),
                ],
          variation: const [],
          prices: CartItemPrices(
            priceMinor: price,
            regularPriceMinor: '',
            salePriceMinor: '',
            currency: currency,
          ),
          totals: CartItemTotals(
            subtotalMinor: subtotal,
            subtotalTaxMinor: tax,
            totalMinor: lineTotal,
            totalTaxMinor: tax,
            currency: currency,
          ),
          backordersAllowed: bool85(item['backorders_allowed']),
          showBackorderBadge: false,
          soldIndividually: false,
          lowStockRemaining: stock,
        ),
      );
    }
    final zeroCheckout = bool85(raw['checkout_zero_total']);
    if (zeroCheckout && total != '0') {
      throw const FormatException('Odoo free checkout has a nonzero total.');
    }
    String optionalTotal(String key) =>
        totals[key] == null ? '' : minor85(totals[key]);
    return OdooCart85(
      revision: revision,
      zeroTotalCheckout: zeroCheckout,
      cart: Cart(
        items: items,
        coupons: const [],
        totals: CartTotals(
          itemsMinor: optionalTotal('items_minor'),
          itemsTaxMinor: optionalTotal('items_tax_minor'),
          feesMinor: optionalTotal('fees_minor'),
          feesTaxMinor: optionalTotal('fees_tax_minor'),
          discountMinor: optionalTotal('discount_minor'),
          discountTaxMinor: optionalTotal('discount_tax_minor'),
          shippingMinor: optionalTotal('shipping_minor'),
          shippingTaxMinor: optionalTotal('shipping_tax_minor'),
          priceMinor: total,
          taxMinor: taxes,
          currency: currency,
        ),
        shippingAddress: address85(raw['shipping_address']),
        billingAddress: address85(raw['billing_address']),
        itemsCount: count,
        itemsWeight: 0,
        needsPayment: total != '0',
        needsShipping: bool85(raw['needs_shipping']),
        hasCalculatedShipping: bool85(raw['has_calculated_shipping']),
        // Cart85 does not advertise native payment providers. Do not invent
        // a portal method or infer support from a nonzero total.
        paymentMethods: const [],
        errors: response['warning'] == null || response['warning'] == ''
            ? const []
            : [
                CartError(
                  code: 'odoo_cart_warning',
                  message: text85(response['warning'], maximum: 16000),
                ),
              ],
      ),
    );
  }

  final String revision;
  final Cart cart;
  final bool zeroTotalCheckout;
}

CartAddress address85(Object? raw) {
  final fields = object85(raw);
  String value(String key, {int maximum = 240}) =>
      text85(fields[key], maximum: maximum);
  final country = value('country', maximum: 2);
  if (country.isNotEmpty && !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
    throw const FormatException('Invalid Odoo country code.');
  }
  return CartAddress(
    firstName: value('first_name'),
    lastName: value('last_name'),
    company: value('company'),
    address1: value('address_1'),
    address2: value('address_2'),
    city: value('city'),
    state: value('state'),
    postcode: value('postcode'),
    country: country,
    email: value('email', maximum: 254),
    phone: value('phone', maximum: 120),
  );
}

Map<String, dynamic> object85(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Invalid Odoo public object.');
  }
  return Map<String, dynamic>.from(value);
}

String text85(Object? value, {int maximum = 240}) {
  if (value is! String ||
      value.length > maximum ||
      value.codeUnits.any(
        (unit) => unit < 32 && unit != 10 && unit != 9 || unit == 127,
      )) {
    throw const FormatException('Invalid Odoo public text.');
  }
  return value;
}

int int85(Object? value, {int minimum = 0, int maximum = 2147483647}) {
  if (value is! int || value < minimum || value > maximum) {
    throw const FormatException('Invalid Odoo public integer.');
  }
  return value;
}

bool bool85(Object? value) {
  if (value is! bool) throw const FormatException('Invalid Odoo public flag.');
  return value;
}

String minor85(Object? value) {
  if (value is! String || !RegExp(r'^(0|[1-9][0-9]{0,39})$').hasMatch(value)) {
    throw const FormatException('Invalid Odoo exact monetary amount.');
  }
  return value;
}
