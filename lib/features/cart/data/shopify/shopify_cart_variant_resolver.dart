import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';

/// Existing Native selections carry the selected variant ID when options are
/// present, otherwise the product ID. Resolve the latter explicitly; never send
/// a Product GID to cartLinesAdd or silently select a variable product's first.
class ShopifyCartVariantResolver {
  ShopifyCartVariantResolver({required this.reader});
  final ShopifyStorefrontReader reader;

  Future<String> resolve({
    required int productId,
    required List<CartItemVariation> variation,
    String? countryCode,
    String? languageCode,
  }) async {
    if (productId <= 0 || productId > 9007199254740991) {
      throw const FormatException('Invalid Shopify merchandise selection.');
    }
    final Map<String, dynamic> data = await reader.query(
      variation.isEmpty ? _simpleProduct : _variant,
      variables: <String, dynamic>{
        'id':
            'gid://shopify/${variation.isEmpty ? 'Product' : 'ProductVariant'}/$productId',
        'country': countryCode,
        'language': languageCode,
      },
    );
    dynamic selected;
    if (variation.isEmpty) {
      final dynamic product = data['product'];
      if (product is! Map ||
          product['id'] != 'gid://shopify/Product/$productId' ||
          product['requiresSellingPlan'] != false ||
          product['options'] is! List) {
        throw const FormatException(
          'Shopify product is not available for a simple cart selection.',
        );
      }
      final List<dynamic> options = product['options'] as List;
      if (options.length != 1 ||
          options.single is! Map ||
          options.single['name'] != 'Title' ||
          options.single['values'] is! List ||
          options.single['values'].length != 1 ||
          options.single['values'].single != 'Default Title') {
        throw const FormatException(
          'Choose the Shopify product options first.',
        );
      }
      selected = product['selectedOrFirstAvailableVariant'];
    } else {
      selected = data['node'];
      if (selected is! Map ||
          selected['id'] != 'gid://shopify/ProductVariant/$productId' ||
          selected['product'] is! Map ||
          selected['product']['requiresSellingPlan'] != false ||
          selected['selectedOptions'] is! List) {
        throw const FormatException(
          'Shopify variant selection is not available.',
        );
      }
      final Map<String, String> selectedOptions = <String, String>{};
      for (final dynamic option in selected['selectedOptions'] as List) {
        if (option is! Map ||
            option['name'] is! String ||
            option['value'] is! String ||
            selectedOptions.containsKey(option['name'])) {
          throw const FormatException('Invalid Shopify variant options.');
        }
        selectedOptions[option['name'] as String] = option['value'] as String;
      }
      if (variation.length != selectedOptions.length ||
          variation.map((option) => option.attribute).toSet().length !=
              variation.length ||
          variation.any(
            (option) => selectedOptions[option.attribute] != option.value,
          )) {
        throw const FormatException(
          'Shopify variant does not match the selected options.',
        );
      }
    }
    if (selected is! Map ||
        selected['id'] is! String ||
        !RegExp(
          r'^gid://shopify/ProductVariant/[1-9][0-9]*$',
        ).hasMatch(selected['id'] as String) ||
        selected['availableForSale'] != true ||
        selected['requiresComponents'] != false) {
      throw const FormatException(
        'This Shopify merchandise cannot be added to the guest cart.',
      );
    }
    return selected['id'] as String;
  }

  static const String _simpleProduct = r'''
    query NativeGuestCartProduct($id: ID!, $country: CountryCode, $language: LanguageCode)
      @inContext(country: $country, language: $language) {
      product(id: $id) { id requiresSellingPlan options { name values }
        selectedOrFirstAvailableVariant { id availableForSale requiresComponents } }
    }
  ''';
  static const String _variant = r'''
    query NativeGuestCartVariant($id: ID!, $country: CountryCode, $language: LanguageCode)
      @inContext(country: $country, language: $language) {
      node(id: $id) { ... on ProductVariant { id availableForSale requiresComponents
        selectedOptions { name value } product { requiresSellingPlan } } }
    }
  ''';
}
