import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';

enum ProductDetailStatus { initial, loading, success, empty, failure }

@immutable
class ProductOptionValue {
  const ProductOptionValue({required this.value, required this.label});

  final String value;
  final String label;
}

@immutable
class ProductOptionGroup {
  const ProductOptionGroup({
    required this.key,
    required this.label,
    required this.values,
  });

  final String key;
  final String label;
  final List<ProductOptionValue> values;
}

@immutable
class ProductPurchaseSelection {
  ProductPurchaseSelection({
    required this.productId,
    required this.quantity,
    required Map<String, String> selectedAttributes,
    this.variationId,
  }) : selectedAttributes = Map<String, String>.unmodifiable(
         selectedAttributes,
       );

  final int productId;
  final int? variationId;
  final int quantity;
  final Map<String, String> selectedAttributes;
}

typedef ProductAddToCartCallback =
    Future<void> Function(ProductPurchaseSelection selection);

class ProductDetailController extends ChangeNotifier {
  ProductDetailController({required this.repository, required this.productId});

  final CatalogRepository repository;
  final int productId;

  ProductDetailStatus _status = ProductDetailStatus.initial;
  CatalogProduct? _product;
  List<CatalogVariation> _variations = const <CatalogVariation>[];
  Map<String, String> _selectedAttributes = const <String, String>{};
  int _quantity = 1;
  String? _loadError;
  String? _addError;
  bool _isAdding = false;
  bool _isDisposed = false;
  int _requestSerial = 0;

  ProductDetailStatus get status => _status;
  CatalogProduct? get product => _product;
  List<CatalogVariation> get variations =>
      List<CatalogVariation>.unmodifiable(_variations);
  Map<String, String> get selectedAttributes =>
      UnmodifiableMapView<String, String>(_selectedAttributes);
  int get quantity => _quantity;
  String? get loadError => _loadError;
  String? get addError => _addError;
  bool get isAdding => _isAdding;

  List<ProductOptionGroup> get optionGroups => _buildOptionGroups();

  bool get selectionComplete => optionGroups.every(
    (ProductOptionGroup group) =>
        _selectedAttributes[group.key]?.isNotEmpty ?? false,
  );

  CatalogVariation? get selectedVariation {
    final CatalogProduct? currentProduct = _product;
    if (currentProduct == null || !currentProduct.hasVariations) {
      return null;
    }
    if (!selectionComplete) {
      return null;
    }

    for (final CatalogVariation variation in _variations) {
      if (_variationMatches(variation, _selectedAttributes)) {
        return variation;
      }
    }
    return null;
  }

  CatalogMoney? get displayedPrice =>
      selectedVariation?.prices ?? _product?.prices;

  CatalogImage? get selectedImage => selectedVariation?.image;

  bool get canAddToCart {
    final CatalogProduct? currentProduct = _product;
    if (_status != ProductDetailStatus.success ||
        currentProduct == null ||
        _isAdding ||
        _quantity < 1) {
      return false;
    }

    if (!currentProduct.hasVariations) {
      return currentProduct.isPurchasable && currentProduct.isInStock;
    }

    final CatalogVariation? variation = selectedVariation;
    return variation != null && variation.isPurchasable && variation.isInStock;
  }

  Future<void> load() async {
    final int serial = ++_requestSerial;
    if (productId <= 0) {
      _status = ProductDetailStatus.empty;
      _product = null;
      _variations = const <CatalogVariation>[];
      _loadError = null;
      _notify();
      return;
    }

    _status = ProductDetailStatus.loading;
    _loadError = null;
    _addError = null;
    _notify();

    try {
      final CatalogProduct loadedProduct = await repository.getProduct(
        productId,
      );
      if (!_canCommit(serial)) {
        return;
      }

      _product = loadedProduct;
      _variations = List<CatalogVariation>.unmodifiable(
        loadedProduct.variations,
      );
      _selectedAttributes = const <String, String>{};
      _quantity = 1;
      _status = ProductDetailStatus.success;
      _notify();

      // The Store API already embeds the variation ids and attributes in the
      // product response. Render that native product page immediately, then
      // enrich stock, prices and images without keeping the whole screen on a
      // loading spinner while extra network requests finish.
      if (loadedProduct.hasVariations) {
        _loadDetailedVariations(serial);
      }
    } on CatalogRepositoryException catch (error) {
      _commitFailure(serial, error.message);
    } catch (_) {
      _commitFailure(serial, 'Unable to load this product. Please try again.');
    }
  }

  Future<void> _loadDetailedVariations(int serial) async {
    try {
      final List<CatalogVariation> detailedVariations = await repository
          .getVariations(productId);
      if (!_canCommit(serial) || detailedVariations.isEmpty) {
        return;
      }
      _variations = List<CatalogVariation>.unmodifiable(detailedVariations);
      _notify();
    } catch (_) {
      // The product response remains usable when optional variation
      // enrichment is unavailable or blocked by store security rules.
    }
  }

  void selectOption(String key, String value) {
    if (_status != ProductDetailStatus.success) {
      return;
    }
    final String normalizedKey = _canonicalAttributeKey(key);
    final ProductOptionGroup? group = _findOptionGroup(normalizedKey);
    if (group == null ||
        !group.values.any((ProductOptionValue item) => item.value == value) ||
        !isOptionAvailable(group.key, value)) {
      return;
    }

    final Map<String, String> next = <String, String>{
      ..._selectedAttributes,
      group.key: value,
    };
    if (mapEquals(next, _selectedAttributes)) {
      return;
    }
    _selectedAttributes = Map<String, String>.unmodifiable(next);
    _addError = null;
    _notify();
  }

  bool isOptionAvailable(String key, String value) {
    if (_variations.isEmpty) {
      return true;
    }
    final ProductOptionGroup? group = _findOptionGroup(_normalize(key));
    if (group == null) {
      return false;
    }
    final Map<String, String> proposed = <String, String>{
      ..._selectedAttributes,
      group.key: value,
    };
    return _variations.any(
      (CatalogVariation variation) =>
          variation.isPurchasable &&
          variation.isInStock &&
          _variationMatches(variation, proposed),
    );
  }

  void incrementQuantity() => setQuantity(_quantity + 1);

  void decrementQuantity() => setQuantity(_quantity - 1);

  void setQuantity(int value) {
    final int next = value < 1 ? 1 : (value > 99 ? 99 : value);
    if (_quantity == next) {
      return;
    }
    _quantity = next;
    _addError = null;
    _notify();
  }

  Future<bool> addToCart(ProductAddToCartCallback? callback) async {
    if (callback == null || !canAddToCart || _product == null) {
      return false;
    }

    final CatalogVariation? variation = selectedVariation;
    _isAdding = true;
    _addError = null;
    _notify();
    try {
      await callback(
        ProductPurchaseSelection(
          productId: _product!.id,
          variationId: variation?.id,
          quantity: _quantity,
          selectedAttributes: _selectedAttributes,
        ),
      );
      _isAdding = false;
      _notify();
      return true;
    } catch (error) {
      _isAdding = false;
      final String message = _cleanActionError(error);
      _addError = message.isEmpty
          ? 'Unable to add this item to the cart.'
          : message;
      _notify();
      return false;
    }
  }

  static String _cleanActionError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^(Bad state|Exception):\s*'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .trim();
  }

  void clearAddError() {
    if (_addError == null) {
      return;
    }
    _addError = null;
    _notify();
  }

  void _commitFailure(int serial, String message) {
    if (!_canCommit(serial)) {
      return;
    }
    _product = null;
    _variations = const <CatalogVariation>[];
    _selectedAttributes = const <String, String>{};
    _loadError = message.trim().isEmpty
        ? 'Unable to load this product. Please try again.'
        : message.trim();
    _status = ProductDetailStatus.failure;
    _notify();
  }

  List<ProductOptionGroup> _buildOptionGroups() {
    final CatalogProduct? currentProduct = _product;
    if (currentProduct == null || !currentProduct.hasVariations) {
      return const <ProductOptionGroup>[];
    }

    final Map<String, _MutableOptionGroup> groups =
        <String, _MutableOptionGroup>{};
    for (final CatalogProductAttribute attribute
        in currentProduct.attributes.where(
          (CatalogProductAttribute item) => item.hasVariations,
        )) {
      final String key = _productAttributeKey(attribute);
      if (key.isEmpty) {
        continue;
      }
      final _MutableOptionGroup group = groups.putIfAbsent(
        key,
        () => _MutableOptionGroup(label: attribute.name.trim()),
      );
      for (final CatalogAttributeTerm term in attribute.terms) {
        final String value = term.slug.trim().isNotEmpty
            ? term.slug.trim()
            : term.name.trim();
        if (value.isNotEmpty) {
          group.add(value, term.name.trim().isEmpty ? value : term.name.trim());
        }
      }
    }

    for (final CatalogVariation variation in _variations) {
      for (final CatalogVariationAttribute attribute in variation.attributes) {
        final String value = attribute.value.trim();
        if (value.isEmpty) {
          continue;
        }
        final String key = _variationAttributeKey(attribute);
        if (key.isEmpty) {
          continue;
        }
        final _MutableOptionGroup group = groups.putIfAbsent(
          key,
          () => _MutableOptionGroup(label: attribute.name.trim()),
        );
        final ProductOptionValue canonical = _canonicalOptionValue(key, value);
        group.add(canonical.value, canonical.label);
      }
    }

    return List<ProductOptionGroup>.unmodifiable(
      groups.entries.map(
        (MapEntry<String, _MutableOptionGroup> entry) => ProductOptionGroup(
          key: entry.key,
          label: entry.value.label.isEmpty ? entry.key : entry.value.label,
          values: List<ProductOptionValue>.unmodifiable(
            entry.value.values.entries.map(
              (MapEntry<String, String> value) =>
                  ProductOptionValue(value: value.key, label: value.value),
            ),
          ),
        ),
      ),
    );
  }

  ProductOptionGroup? _findOptionGroup(String normalizedKey) {
    final String canonicalKey = _canonicalAttributeKey(normalizedKey);
    for (final ProductOptionGroup group in optionGroups) {
      if (_canonicalAttributeKey(group.key) == canonicalKey) {
        return group;
      }
    }
    return null;
  }

  bool _variationMatches(
    CatalogVariation variation,
    Map<String, String> selections,
  ) {
    for (final MapEntry<String, String> selection in selections.entries) {
      CatalogVariationAttribute? matchingAttribute;
      for (final CatalogVariationAttribute attribute in variation.attributes) {
        if (_variationAttributeKey(attribute) == selection.key) {
          matchingAttribute = attribute;
          break;
        }
      }
      if (matchingAttribute == null || matchingAttribute.value.trim().isEmpty) {
        continue;
      }
      if (!_attributeValuesMatch(
        selection.key,
        selection.value,
        matchingAttribute.value,
      )) {
        return false;
      }
    }
    return true;
  }

  bool _attributeValuesMatch(
    String key,
    String selectedValue,
    String variationValue,
  ) {
    final String normalizedVariation = _normalize(variationValue);
    if (_normalize(selectedValue) == normalizedVariation) {
      return true;
    }

    final CatalogProduct? currentProduct = _product;
    if (currentProduct == null) {
      return false;
    }
    for (final CatalogProductAttribute attribute in currentProduct.attributes) {
      if (_productAttributeKey(attribute) != key) {
        continue;
      }
      for (final CatalogAttributeTerm term in attribute.terms) {
        if (_normalize(term.slug) == _normalize(selectedValue) &&
            _normalize(term.name) == normalizedVariation) {
          return true;
        }
      }
    }
    return false;
  }

  ProductOptionValue _canonicalOptionValue(String key, String rawValue) {
    final CatalogProduct? currentProduct = _product;
    if (currentProduct != null) {
      for (final CatalogProductAttribute attribute
          in currentProduct.attributes) {
        if (_productAttributeKey(attribute) != key) {
          continue;
        }
        for (final CatalogAttributeTerm term in attribute.terms) {
          if (_normalize(term.slug) == _normalize(rawValue) ||
              _normalize(term.name) == _normalize(rawValue)) {
            final String value = term.slug.trim().isNotEmpty
                ? term.slug.trim()
                : term.name.trim();
            final String label = term.name.trim().isNotEmpty
                ? term.name.trim()
                : value;
            return ProductOptionValue(value: value, label: label);
          }
        }
      }
    }
    return ProductOptionValue(value: rawValue, label: rawValue);
  }

  String _productAttributeKey(CatalogProductAttribute attribute) {
    final String taxonomy = _canonicalAttributeKey(attribute.taxonomy);
    return taxonomy.isNotEmpty
        ? taxonomy
        : _canonicalAttributeKey(attribute.name);
  }

  String _variationAttributeKey(CatalogVariationAttribute attribute) {
    final String taxonomy = _canonicalAttributeKey(attribute.taxonomy);
    final String name = _canonicalAttributeKey(attribute.name);
    final CatalogProduct? currentProduct = _product;
    if (currentProduct != null) {
      for (final CatalogProductAttribute productAttribute
          in currentProduct.attributes) {
        final String productTaxonomy = _canonicalAttributeKey(
          productAttribute.taxonomy,
        );
        final String productName = _canonicalAttributeKey(
          productAttribute.name,
        );
        if ((taxonomy.isNotEmpty && taxonomy == productTaxonomy) ||
            (name.isNotEmpty && name == productName)) {
          return _productAttributeKey(productAttribute);
        }
      }
    }
    return taxonomy.isNotEmpty ? taxonomy : name;
  }

  /// WooCommerce stores non-Latin attribute taxonomies URL encoded. Some
  /// extensions strip only the percent signs, so the same Arabic taxonomy can
  /// arrive as both `pa_المقاس` and `pa_d8a7d984...`. Canonicalizing the wire
  /// representation prevents a duplicate option group from being rendered.
  static String _canonicalAttributeKey(String source) {
    String value = _normalize(source);
    if (value.isEmpty) {
      return '';
    }
    if (value.contains('%')) {
      try {
        value = Uri.decodeComponent(value);
      } on FormatException {
        // Keep the original key when a third-party plugin sends malformed
        // escaping; it remains safe and can still match by its display name.
      }
    }

    const String prefix = 'pa_';
    if (!value.startsWith(prefix)) {
      return value;
    }
    final String compactHex = value.substring(prefix.length);
    if (compactHex.length < 4 ||
        compactHex.length.isOdd ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(compactHex)) {
      return value;
    }
    try {
      final List<int> bytes = <int>[
        for (int index = 0; index < compactHex.length; index += 2)
          int.parse(compactHex.substring(index, index + 2), radix: 16),
      ];
      final String decoded = utf8.decode(bytes).trim().toLowerCase();
      return decoded.isEmpty ? value : '$prefix$decoded';
    } on FormatException {
      return value;
    }
  }

  static String _normalize(String source) => source.trim().toLowerCase();

  bool _canCommit(int serial) => !_isDisposed && serial == _requestSerial;

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestSerial++;
    super.dispose();
  }
}

class _MutableOptionGroup {
  _MutableOptionGroup({required this.label});

  final String label;
  final LinkedHashMap<String, String> values = LinkedHashMap<String, String>();

  void add(String value, String label) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty ||
        values.keys.any(
          (String item) => item.trim().toLowerCase() == normalized,
        )) {
      return;
    }
    values[value] = label;
  }
}
