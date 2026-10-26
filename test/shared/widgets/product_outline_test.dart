import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_card.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';

void main() {
  for (final type in ['product_grid', 'product_carousel']) {
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
      for (final option in [(true, null), (true, custom), (false, custom)]) {
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
          option.$1 ? BorderSide(color: option.$2 ?? brand) : BorderSide.none,
        );
      }
    },
  );
}
