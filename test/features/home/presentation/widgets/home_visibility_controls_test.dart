import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_widgets.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/shared/widgets/product/shared_product_card_provider.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card.dart';

void main() {
  for (final grid in [false, true]) {
    testWidgets(
      'section controls override visibility, preserve shared appearance: grid=$grid',
      (tester) async {
        HomeAction? chosen;
        final block = HomeBlockModel.fromJson({
          'id': 'picks',
          'type': grid ? 'product_grid' : 'product_carousel',
          'enabled': true,
          'data': {
            'show_name': true,
            'show_view_all': true,
            'view_all_label': 'MORE',
            'view_all_action': {'type': 'collection', 'value': 'latest'},
            'items': [
              {
                'id': 8,
                'name': 'Kids outfit',
                'price': '25',
                'currency_code': 'EGP',
                'currency_symbol': 'EGP',
                'image_url': 'https://example.com/outfit.jpg',
              },
            ],
          },
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedProductCardProvider.overrideWithValue(
                const CmsPageComponent(
                  id: 'shared',
                  type: 'product_grid',
                  enabled: true,
                  settings: {
                    'show_name': false,
                    'card_outline_width': .5,
                    'price_color': '#4EA999',
                  },
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: grid
                    ? ProductGridBlockWidget(
                        block: block as ProductGridBlock,
                        onAction: (a) => chosen = a,
                      )
                    : ProductCarouselBlockWidget(
                        block: block as ProductCarouselBlock,
                        onAction: (a) => chosen = a,
                      ),
              ),
            ),
          ),
        );
        expect(find.text('Kids outfit'), findsOneWidget);
        final card = tester.widget<StoreProductCard>(
          find.byType(StoreProductCard),
        );
        expect(card.settings!.number('card_outline_width', 0), .5);
        expect(card.settings!.string('price_color', ''), '#4EA999');
        await tester.tap(find.text('MORE'));
        expect(chosen?.type, 'collection');
        expect(chosen?.value, 'latest');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
