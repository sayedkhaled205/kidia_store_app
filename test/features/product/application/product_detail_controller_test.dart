import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/product/application/product_detail_controller.dart';

import '../support/product_test_data.dart';

void main() {
  group('ProductDetailController', () {
    test('loads a simple product and builds a purchase selection', () async {
      final ProductFakeCatalogRepository repository =
          ProductFakeCatalogRepository();
      final ProductDetailController controller = ProductDetailController(
        repository: repository,
        productId: simpleProduct.id,
      );
      addTearDown(controller.dispose);

      final Future<void> request = controller.load();
      expect(controller.status, ProductDetailStatus.loading);
      await request;

      expect(controller.status, ProductDetailStatus.success);
      expect(controller.product, same(simpleProduct));
      expect(repository.productCalls, 1);
      expect(repository.variationCalls, 0);
      expect(controller.canAddToCart, isTrue);

      controller.setQuantity(150);
      expect(controller.quantity, 99);
      controller.setQuantity(-4);
      expect(controller.quantity, 1);
      controller.incrementQuantity();

      ProductPurchaseSelection? captured;
      final bool added = await controller.addToCart((
        ProductPurchaseSelection selection,
      ) async {
        captured = selection;
      });

      expect(added, isTrue);
      expect(captured?.productId, simpleProduct.id);
      expect(captured?.variationId, isNull);
      expect(captured?.quantity, 2);
    });

    test(
      'matches attribute names to slugs and selects an in-stock variation',
      () async {
        final ProductFakeCatalogRepository repository =
            ProductFakeCatalogRepository(
              product: variableProduct,
              variations: testVariations,
            );
        final ProductDetailController controller = ProductDetailController(
          repository: repository,
          productId: variableProduct.id,
        );
        addTearDown(controller.dispose);

        await controller.load();

        expect(repository.variationCalls, 1);
        expect(controller.optionGroups, hasLength(2));
        expect(controller.canAddToCart, isFalse);
        expect(controller.isOptionAvailable('pa_size', 'm'), isTrue);

        controller.selectOption('pa_color', 'blue');
        controller.selectOption('pa_size', 'm');

        expect(controller.selectionComplete, isTrue);
        expect(controller.selectedVariation?.id, 103);
        expect(controller.displayedPrice, same(blueMediumMoney));
        expect(controller.canAddToCart, isTrue);

        ProductPurchaseSelection? captured;
        await controller.addToCart((ProductPurchaseSelection selection) async {
          captured = selection;
        });
        expect(captured?.variationId, 103);
        expect(captured?.selectedAttributes, <String, String>{
          'pa_color': 'blue',
          'pa_size': 'm',
        });
      },
    );

    test(
      'disables unavailable combinations and reports callback failures',
      () async {
        final ProductDetailController controller = ProductDetailController(
          repository: ProductFakeCatalogRepository(
            product: variableProduct,
            variations: testVariations,
          ),
          productId: variableProduct.id,
        );
        addTearDown(controller.dispose);
        await controller.load();

        controller.selectOption('pa_color', 'red');
        expect(controller.isOptionAvailable('pa_size', 'm'), isFalse);
        controller.selectOption('pa_size', 'm');
        expect(controller.selectedAttributes.containsKey('pa_size'), isFalse);
        expect(controller.selectedVariation, isNull);
        expect(controller.canAddToCart, isFalse);

        controller.selectOption('pa_size', 's');
        expect(controller.canAddToCart, isTrue);
        final bool added = await controller.addToCart(
          (_) async => throw StateError('Cart rejected the item'),
        );

        expect(added, isFalse);
        expect(controller.isAdding, isFalse);
        expect(controller.addError, contains('Cart rejected the item'));
      },
    );

    test(
      'merges stripped Arabic taxonomy hex with the product attribute',
      () async {
        const CatalogProduct product = CatalogProduct(
          id: 58,
          name: 'Kids shoes',
          slug: 'kids-shoes',
        type: 'variable',
        isPurchasable: true,
        isInStock: true,
        prices: testMoney,
        attributes: <CatalogProductAttribute>[
            CatalogProductAttribute(
              id: 8,
              name: 'المقاس',
              taxonomy: 'pa_المقاس',
              hasVariations: true,
              terms: <CatalogAttributeTerm>[
                CatalogAttributeTerm(id: 20, name: '20', slug: '20'),
                CatalogAttributeTerm(id: 21, name: '21', slug: '21'),
              ],
            ),
          ],
          variations: <CatalogVariation>[
            CatalogVariation(
              id: 5801,
              attributes: <CatalogVariationAttribute>[
                CatalogVariationAttribute(
                  name: 'pa_d8a7d984d985d982d8a7d8b3',
                  taxonomy: 'pa_d8a7d984d985d982d8a7d8b3',
                  value: '20',
                ),
              ],
            ),
          ],
        );
        final ProductDetailController controller = ProductDetailController(
          repository: ProductFakeCatalogRepository(
            product: product,
            variations: product.variations,
          ),
          productId: product.id,
        );
        addTearDown(controller.dispose);

        await controller.load();

        expect(controller.optionGroups, hasLength(1));
        expect(controller.optionGroups.single.label, 'المقاس');
        expect(
          controller.optionGroups.single.values.map((value) => value.label),
          <String>['20', '21'],
        );
      },
    );

    test(
      'uses empty state for invalid ids without calling the repository',
      () async {
        final ProductFakeCatalogRepository repository =
            ProductFakeCatalogRepository();
        final ProductDetailController controller = ProductDetailController(
          repository: repository,
          productId: 0,
        );
        addTearDown(controller.dispose);

        await controller.load();

        expect(controller.status, ProductDetailStatus.empty);
        expect(repository.productCalls, 0);
      },
    );

    test('keeps a retryable repository error', () async {
      final ProductFakeCatalogRepository repository =
          ProductFakeCatalogRepository(
            productError: const CatalogRepositoryException(
              kind: StoreApiFailureKind.connection,
              message: 'Store is offline.',
            ),
          );
      final ProductDetailController controller = ProductDetailController(
        repository: repository,
        productId: simpleProduct.id,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.status, ProductDetailStatus.failure);
      expect(controller.loadError, 'Store is offline.');
      repository.productError = null;
      await controller.load();
      expect(controller.status, ProductDetailStatus.success);
    });
  });
}
