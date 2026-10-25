import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';

void main() {
  for (final type in ['product_grid', 'product_carousel']) {
    for (final image in [null, '', 'https://store.example/item.jpg']) {
      test('$type retains products with image $image', () {
        final block = HomeBlockModel.fromJson({
          'id': 'collection',
          'type': type,
          'data': {
            'items': [
              {
                'id': 10,
                'name': 'Product without a photo',
                'image_url': ?image,
                'price': '10',
                'currency_code': 'EGP',
                'currency_symbol': 'EGP',
              },
              {
                'id': 11,
                'name': 'Product with a photo',
                'image_url': 'https://store.example/item.jpg',
                'price': '20',
                'currency_code': 'EGP',
                'currency_symbol': 'EGP',
              },
            ],
          },
        });
        final items = switch (block) {
          ProductGridBlock products => products.items,
          ProductCarouselBlock products => products.items,
          _ => throw StateError('Unexpected block'),
        };
        expect(items.map((item) => item.id), [10, 11]);
        expect(items.first.imageUrl, image ?? '');
        expect(items.first.price, '10');
      });
    }
  }
}
