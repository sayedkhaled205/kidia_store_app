import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/shared/widgets/product/shared_product_card_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_card.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_product_card.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import '../../features/product/support/product_test_data.dart';

void main() {
  test('product cards keep the full source instead of low resolution thumbnails', () {
    for (final url in ['https://shop.example.com/product.jpg', 'https://cdn.example.com/product.jpg?width=1200&v=2']) {
      final image = CatalogImage(source: Uri.parse(url), thumbnail: Uri.parse('https://shop.example.com/product-150x150.jpg'));
      expect(image.cardSource.toString(), url);
    }
  });
  testWidgets('catalog and wishlist cards render configured outline thickness', (tester) async {
    for (final width in [0.0, .5, 2.5, 6.0]) {
      await tester.pumpWidget(ProviderScope(overrides: [sharedProductCardProvider.overrideWithValue(null)], child: MaterialApp(home: Scaffold(body: SizedBox(
        width: 180, height: 340,
        child: CatalogProductCard(product: simpleProduct, onTap: () {},
          settings: CmsPageComponent(id: 'grid', type: 'product_grid', enabled: true,
            settings: {'card_style': 'outlined', 'card_outline_width': width}),
        ),
      )))));
      final material = tester.widget<Material>(find.descendant(of: find.byType(CatalogProductCard), matching: find.byType(Material)).first);
      final side = (material.shape! as RoundedRectangleBorder).side;
      expect(side.width, width == 0 ? BorderSide.none.width : width);
      expect(side.style, width == 0 ? BorderStyle.none : BorderStyle.solid);
    }
  });
  for (final type in ['product_grid', 'product_carousel']) {
    test('$type preserves fractional outline widths and validates bounds', () {
      for (final width in [null, 0, .5, 2.5, 6]) {
        final block = HomeBlockModel.fromJson({
          'id': 'outline', 'type': type, 'enabled': true,
          'data': {'items': [], 'card_outline_width': ?width},
        });
        expect(block is ProductGridBlock ? block.cardOutlineWidth : (block as ProductCarouselBlock).cardOutlineWidth, width ?? 1);
      }
      for (final width in [-1, 7, 'invalid']) {
        expect(() => HomeBlockModel.fromJson({
          'id': 'outline', 'type': type, 'enabled': true,
          'data': {'items': [], 'card_outline_width': width},
        }), throwsFormatException);
      }
    });
    test(
      '$type keeps valid outline and safely defaults missing or invalid color',
      () {
        for (final color in [null, '', 'invalid', '#DC713A']) {
          final block = HomeBlockModel.fromJson({
            'id': 'outline',
            'type': type,
            'enabled': true,
            'data': {'items': [], 'card_outline_color': ?color},
          });
          final actual = block is ProductGridBlock
              ? block.cardOutlineColor
              : (block as ProductCarouselBlock).cardOutlineColor;
          expect(actual, color == '#DC713A' ? '#dc713a' : null);
        }
      },
    );
  }
  testWidgets(
    'product border uses brand, custom override, and respects no border',
    (tester) async {
      const brand = Color(0xFF347A89);
      const custom = Color(0xFFDC713A);
      for (final option in [(true, null, 1.0), (true, custom, 2.5), (true, custom, 0.0), (false, custom, 3.0)]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: brand,
              ).copyWith(primary: brand),
            ),
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 300,
                child: ProductCard(
                  name: 'Product',
                  imageUrl: '',
                  price: '10',
                  currencySymbol: 'EGP',
                  inStock: true,
                  showBorder: option.$1,
                  outlineColor: option.$2,
                  outlineWidth: option.$3,
                  showPrice: false,
                ),
              ),
            ),
          ),
        );
        final card = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(ProductCard),
                matching: find.byType(Material),
              )
              .first,
        );
        final shape = card.shape! as RoundedRectangleBorder;
        expect(
          shape.side,
          option.$1 && option.$3 > 0 ? BorderSide(color: option.$2 ?? brand, width: option.$3) : BorderSide.none,
        );
      }
    },
  );
}
