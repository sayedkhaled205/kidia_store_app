import 'package:mobishop_store_app/features/checkout/data/models/checkout_field_normalizer.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_address.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_totals.dart';
import 'package:mobishop_store_app/features/checkout/data/models/checkout_field_definition_model.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';

/// Uses the application's real CheckoutScreen with an isolated, non-ordering
/// cart. The builder never receives a customer session or submits a purchase.
class CmsPreviewCheckoutRepository implements CheckoutRepository {
  CmsPreviewCheckoutRepository(this.layout, this.catalog);

  final Map<String, dynamic> layout;
  final Map<String, dynamic> catalog;

  late final Cart _cart = _buildCart();

  @override
  Future<CheckoutState> loadCheckout() async => CheckoutState(
    cart: _cart,
    fieldDefinitions: _fields(),
    allowDifferentShippingAddress:
        layout['checkout_shipping'] is Map &&
        (layout['checkout_shipping'] as Map)['allow_different_address'] == true,
  );

  @override
  Future<Cart> updateCustomer({
    required CheckoutAddress billingAddress,
    required CheckoutAddress shippingAddress,
  }) async => _cart;

  @override
  Future<CheckoutOrderResult> placeOrder(CheckoutSubmission submission) async {
    throw const CheckoutRepositoryException(
      kind: CheckoutFailureKind.configuration,
      message: 'Preview only. No order was created.',
    );
  }

  List<CheckoutFieldDefinition> _fields() {
    final dynamic raw = layout['checkout_fields'];
    if (raw is! List) return const <CheckoutFieldDefinition>[];
    final List<CheckoutFieldDefinition> fields = <CheckoutFieldDefinition>[];
    for (final Map<String, dynamic> item in raw.whereType<Map>().map(
      (Map item) => Map<String, dynamic>.from(item),
    )) {
      final dynamic enabled = item['enabled'];
      if (enabled != null &&
          !<String>{
            '1',
            'true',
            'yes',
            'on',
          }.contains('$enabled'.trim().toLowerCase())) {
        continue;
      }
      final Map<String, String> options = <String, String>{};
      if (item['options'] is Map) {
        for (final MapEntry<dynamic, dynamic> option
            in (item['options'] as Map).entries) {
          options['${option.key}'] = '${option.value ?? ''}';
        }
      } else {
        for (final String line in '${item['options_text'] ?? ''}'.split(
          RegExp(r'\r\n|\r|\n'),
        )) {
          final List<String> parts = line.trim().split('|');
          if (parts.first.trim().isNotEmpty) {
            options[parts.first.trim()] = parts.length > 1
                ? parts.sublist(1).join('|').trim()
                : parts.first.trim();
          }
        }
      }
      // Use the same type/boolean conversion as the application's API data.
      // Editor array order is authoritative until the draft is saved.
      final CheckoutFieldDefinition? field =
          CheckoutFieldDefinitionModel.tryParse(<String, dynamic>{
            ...item,
            'group': item['group'] ?? 'billing',
            'options': options,
            'priority': fields.length * 10,
          });
      if (field != null) fields.add(field);
    }
    return CheckoutFieldNormalizer.normalize(fields, <String, dynamic>{
      'defaults': layout['checkout_defaults'],
    });
  }

  Cart _buildCart() {
    final List<dynamic> raw = catalog['products'] is List
        ? catalog['products'] as List<dynamic>
        : const <dynamic>[];
    const CartCurrency currency = CartCurrency(
      code: 'EGP',
      symbol: 'EGP',
      minorUnit: 2,
      decimalSeparator: '.',
      thousandSeparator: ',',
      prefix: '',
      suffix: '',
    );
    final List<Map<String, dynamic>> products = raw
        .whereType<Map>()
        .take(2)
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
    if (products.isEmpty) {
      products.addAll(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Preview product',
          'price_minor': '10000',
        },
      ]);
    }
    int sum = 0;
    final List<CartItem> items = products
        .map((Map<String, dynamic> product) {
          final int id = int.tryParse('${product['id']}') ?? 1;
          final int minor = int.tryParse('${product['price_minor']}') ?? 0;
          sum += minor;
          final String price = '$minor';
          final String image = '${product['image_url'] ?? ''}';
          return CartItem(
            key: 'preview-$id',
            productId: id,
            quantity: 1,
            quantityLimits: const CartItemQuantityLimits(
              minimum: 1,
              maximum: 99,
              multipleOf: 1,
              editable: true,
            ),
            name: '${product['name'] ?? 'Preview product'}',
            shortDescription: '',
            sku: '${product['sku'] ?? ''}',
            images: image.isEmpty
                ? const <CartItemImage>[]
                : <CartItemImage>[
                    CartItemImage(
                      id: id,
                      sourceUrl: image,
                      thumbnailUrl: image,
                      alt: '',
                    ),
                  ],
            variation: const <CartItemVariation>[],
            prices: CartItemPrices(
              priceMinor: price,
              regularPriceMinor: price,
              salePriceMinor: '',
              currency: currency,
            ),
            totals: CartItemTotals(
              subtotalMinor: price,
              subtotalTaxMinor: '0',
              totalMinor: price,
              totalTaxMinor: '0',
              currency: currency,
            ),
            backordersAllowed: false,
            showBackorderBadge: false,
            soldIndividually: false,
          );
        })
        .toList(growable: false);
    final String total = '$sum';
    return Cart(
      items: items,
      coupons: const [],
      totals: CartTotals(
        itemsMinor: total,
        itemsTaxMinor: '0',
        feesMinor: '0',
        feesTaxMinor: '0',
        discountMinor: '0',
        discountTaxMinor: '0',
        shippingMinor: '0',
        shippingTaxMinor: '0',
        priceMinor: total,
        taxMinor: '0',
        currency: currency,
      ),
      shippingAddress: const CartAddress(country: 'EG'),
      billingAddress: const CartAddress(country: 'EG'),
      itemsCount: items.length,
      itemsWeight: 0,
      needsPayment: false,
      needsShipping: true,
      hasCalculatedShipping: true,
      paymentMethods: const [],
      errors: const [],
    );
  }
}
