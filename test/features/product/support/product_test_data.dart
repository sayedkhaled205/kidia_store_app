import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';

class ProductFakeCatalogRepository implements CatalogRepository {
  ProductFakeCatalogRepository({
    CatalogProduct? product,
    List<CatalogVariation> variations = const <CatalogVariation>[],
    this.productError,
  }) : product = product ?? simpleProduct,
       variations = List<CatalogVariation>.of(variations);

  CatalogProduct product;
  List<CatalogVariation> variations;
  Object? productError;
  int productCalls = 0;
  int variationCalls = 0;

  @override
  Future<CatalogProduct> getProduct(int productId) async {
    productCalls++;
    final Object? error = productError;
    if (error != null) {
      throw error;
    }
    return product;
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) async {
    variationCalls++;
    return List<CatalogVariation>.unmodifiable(variations);
  }

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async {
    return const CatalogPage<CatalogCategory>(
      items: <CatalogCategory>[],
      page: 1,
      perPage: 20,
      totalItems: 0,
      totalPages: 0,
    );
  }

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    return const CatalogFilterData();
  }

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    return const CatalogPage<CatalogProduct>(
      items: <CatalogProduct>[],
      page: 1,
      perPage: 20,
      totalItems: 0,
      totalPages: 0,
    );
  }
}

const CatalogMoney testMoney = CatalogMoney(
  currencyCode: 'USD',
  currencySymbol: r'$',
  currencyPrefix: r'$',
  currencyMinorUnit: 2,
  priceMinor: '7999',
  regularPriceMinor: '9999',
  salePriceMinor: '7999',
);

const CatalogProduct simpleProduct = CatalogProduct(
  id: 41,
  name: 'Everyday Dress',
  slug: 'everyday-dress',
  type: 'simple',
  sku: 'DR-41',
  summary: '<p>Soft &amp; comfortable.</p>',
  description: '<p>A light dress for every day.</p>',
  isOnSale: true,
  isPurchasable: true,
  isInStock: true,
  stockStatus: CatalogStockStatus.inStock,
  averageRating: 4.6,
  reviewCount: 18,
  prices: testMoney,
  brands: <CatalogCategory>[
    CatalogCategory(id: 7, name: 'Kidia', slug: 'kidia'),
  ],
);

const CatalogProductAttribute sizeAttribute = CatalogProductAttribute(
  id: 1,
  name: 'Size',
  taxonomy: 'pa_size',
  hasVariations: true,
  terms: <CatalogAttributeTerm>[
    CatalogAttributeTerm(id: 11, name: 'Small', slug: 's'),
    CatalogAttributeTerm(id: 12, name: 'Medium', slug: 'm'),
  ],
);

const CatalogProductAttribute colorAttribute = CatalogProductAttribute(
  id: 2,
  name: 'Color',
  taxonomy: 'pa_color',
  hasVariations: true,
  terms: <CatalogAttributeTerm>[
    CatalogAttributeTerm(id: 21, name: 'Red', slug: 'red'),
    CatalogAttributeTerm(id: 22, name: 'Blue', slug: 'blue'),
  ],
);

const CatalogMoney blueMediumMoney = CatalogMoney(
  currencyCode: 'USD',
  currencySymbol: r'$',
  currencyPrefix: r'$',
  currencyMinorUnit: 2,
  priceMinor: '6999',
  regularPriceMinor: '9999',
  salePriceMinor: '6999',
);

const List<CatalogVariation> testVariations = <CatalogVariation>[
  CatalogVariation(
    id: 101,
    attributes: <CatalogVariationAttribute>[
      CatalogVariationAttribute(name: 'Size', value: 'Small'),
      CatalogVariationAttribute(name: 'Color', value: 'Red'),
    ],
    prices: testMoney,
  ),
  CatalogVariation(
    id: 102,
    attributes: <CatalogVariationAttribute>[
      CatalogVariationAttribute(name: 'Size', value: 'Medium'),
      CatalogVariationAttribute(name: 'Color', value: 'Red'),
    ],
    isInStock: false,
    prices: testMoney,
  ),
  CatalogVariation(
    id: 103,
    attributes: <CatalogVariationAttribute>[
      CatalogVariationAttribute(name: 'Size', value: 'Medium'),
      CatalogVariationAttribute(name: 'Color', value: 'Blue'),
    ],
    prices: blueMediumMoney,
  ),
];

const CatalogProduct variableProduct = CatalogProduct(
  id: 42,
  name: 'Variable Dress',
  slug: 'variable-dress',
  type: 'variable',
  summary: '<p>Pick your size and color.</p>',
  description: '<p>Available in several combinations.</p>',
  // WooCommerce can mark the variable parent as non-purchasable until a
  // concrete variation is selected. The product action must still open the
  // options picker in that state.
  isPurchasable: false,
  isInStock: true,
  stockStatus: CatalogStockStatus.inStock,
  averageRating: 4.2,
  reviewCount: 7,
  prices: testMoney,
  attributes: <CatalogProductAttribute>[sizeAttribute, colorAttribute],
  variations: testVariations,
);
