import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';

void main() {
  for (final type in ['product_grid', 'product_carousel']) {
    test('$type accepts the saved No shadow option', () {
      final json = <String, dynamic>{
        'id': 'saved-$type',
        'type': type,
        'enabled': true,
        'data': <String, dynamic>{'card_style': 'no_shadow', 'items': []},
      };
      final block = HomeBlockModel.fromJson(json);
      final style = block is ProductGridBlock
          ? block.cardStyle
          : (block as ProductCarouselBlock).cardStyle;
      expect(style, 'no_shadow');
      (json['data'] as Map)['card_style'] = 'unknown-style';
      expect(() => HomeBlockModel.fromJson(json), throwsFormatException);
    });
  }
}
