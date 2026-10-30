import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/product/application/product_detail_controller.dart';
import 'package:mobishop_store_app/features/product/presentation/widgets/product_option_tiles.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';
import '../support/product_test_data.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final width in [320.0, 360.0, 390.0, 844.0, 768.0, 1024.0]) {
      for (final scale in [1.0, 1.8]) {
        testWidgets('compact sizes $width $scale $direction', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final sizes = ['0-3m', '3-6m', '6-9m', '9-12m', '12-18m', '18-24m'];
          final product = CatalogProduct(
            id: 88,
            name: 'Baby set',
            prices: testMoney,
            isInStock: true,
            isPurchasable: true,
            slug: 'baby',
            type: 'variable',
            attributes: [
              CatalogProductAttribute(
                id: 1,
                name: 'Size',
                taxonomy: 'pa_size',
                hasVariations: true,
                terms: [
                  for (var i = 0; i < sizes.length; i++)
                    CatalogAttributeTerm(
                      id: i + 1,
                      name: sizes[i],
                      slug: sizes[i],
                    ),
                ],
              ),
            ],
          );
          final controller = ProductDetailController(
            productId: 88,
            repository: ProductFakeCatalogRepository(
              product: product,
              variations: [
                for (var i = 0; i < sizes.length; i++)
                  CatalogVariation(
                    id: i + 100,
                    isInStock: i != 5,
                    attributes: [
                      CatalogVariationAttribute(name: 'Size', value: sizes[i]),
                    ],
                  ),
              ],
            ),
          );
          addTearDown(controller.dispose);
          await controller.load();
          await tester.pump();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Directionality(
                    textDirection: direction,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (_, _) => ProductOptionTiles(
                          controller: controller,
                          group: controller.optionGroups.single,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final first = find.byKey(
            Key('product-option-pa_size-${sizes.first}'),
          );
          final last = find.byKey(Key('product-option-pa_size-${sizes.last}'));
          expect(tester.getSize(first).width, greaterThanOrEqualTo(44));
          expect(
            tester.getSize(first).height,
            greaterThan(tester.getSize(first).width),
          );
          if ((width >= 360 && scale == 1) || width >= 768) {
            expect(tester.getTopLeft(first).dy, tester.getTopLeft(last).dy);
          } else {
            expect(
              tester.getTopLeft(last).dy,
              greaterThan(tester.getTopLeft(first).dy),
            );
          }
          for (final name in sizes) {
            final text = tester.widget<Text>(find.text(name).first);
            expect(text.maxLines, 1);
            expect(text.softWrap, false);
            expect(find.ancestor(of: find.text(name).first, matching: find.byType(FittedBox)), findsOneWidget);
          }
          await tester.tap(last);
          expect(controller.selectedAttributes, isEmpty);
          await tester.tap(first);
          await tester.pump();
          expect(controller.selectedVariation?.id, 100);
          ProductPurchaseSelection? purchase;
          await controller.addToCart((value) async {
            purchase = value;
          });
          expect(purchase?.variationId, 100);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'color photos match the selected combination; missing photos keep labels',
    (tester) async {
      final redSmall = CatalogImage(
        source: Uri.parse('https://example.com/red-small.jpg'),
      );
      final redMedium = CatalogImage(
        source: Uri.parse('https://example.com/red-medium.jpg'),
        thumbnail: Uri.parse('https://example.com/red-medium-small.jpg'),
      );
      final variants = [
        for (var i = 0; i < testVariations.length; i++)
          CatalogVariation(
            id: testVariations[i].id,
            attributes: testVariations[i].attributes,
            isInStock: testVariations[i].isInStock,
            image: i == 0
                ? redSmall
                : i == 1
                ? redMedium
                : null,
          ),
      ];
      final controller = ProductDetailController(
        productId: 42,
        repository: ProductFakeCatalogRepository(
          product: variableProduct,
          variations: variants,
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pump();
      expect(controller.imageForOption('pa_color', 'red'), same(redSmall));
      expect(controller.imageForOption('pa_color', 'blue'), isNull);
      controller.selectOption('pa_size', 'm');
      expect(controller.imageForOption('pa_color', 'red'), same(redMedium));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductOptionTiles(
              controller: controller,
              group: controller.optionGroups.firstWhere(
                (g) => g.key == 'pa_color',
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).imageUrl,
        redMedium.thumbnail.toString(),
      );
      expect(find.text('Red'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Red')).dy,
        lessThan(tester.getTopLeft(find.byType(AppNetworkImage)).dy),
      );
      expect(find.text('Blue'), findsOneWidget);
      await tester.tap(find.byKey(const Key('product-option-pa_color-red')));
      expect(controller.selectedAttributes['pa_color'], 'red');
      expect(controller.selectedAttributes['pa_size'], isNull);
      expect(controller.canAddToCart, isFalse);
      await tester.tap(find.byKey(const Key('product-option-pa_color-blue')));
      expect(controller.selectedAttributes['pa_color'], 'blue');
      expect(controller.selectedAttributes['pa_size'], isNull);
      expect(controller.canAddToCart, isFalse);
      controller.selectOption('pa_size', 'm');
      expect(controller.selectedVariation?.id, 103);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

