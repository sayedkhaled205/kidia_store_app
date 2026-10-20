import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';

import 'app_design_fixture58.dart';

Map<String, dynamic> _hero(String position) => {
  'id': 'central_builder_hero',
  'type': 'hero_slider',
  'enabled': true,
  'data': {
    'aspect_ratio': 1,
    'auto_play': true,
    'interval_ms': 4500,
    'border_radius': 12,
    'horizontal_padding': 16,
    'image_fit': 'cover',
    'overlay_position': 'start',
    'overlay_strength': 18,
    'text_color': '#FFFFFF',
    'show_indicators': true,
    'indicator_style': 'pill',
    'indicator_position': position,
    'items': [
      for (var i = 1; i <= 3; i++)
        {
          'id': 'setup_theme_hero_$i',
          'enabled': true,
          'image_url': 'https://builder.example/assets/hero-$i.webp',
          'title': 'Saved banner $i',
          'subtitle': 'Saved design',
          'button_label': 'Shop now',
          'action': null,
        },
    ],
  },
};

void main() {
  for (final position in ['inside', 'image_bottom', 'below']) {
    test('saved hero $position keeps its intended renderer position', () {
      final hero = HomeBlockModel.fromJson(_hero(position)) as HeroSliderBlock;
      expect(
        hero.indicatorPosition,
        position == 'inside' ? 'image_bottom' : position,
      );
      expect(hero.items, hasLength(3));
      expect(hero.aspectRatio, 1);
    });
  }
  test('unknown hero positions are still rejected', () {
    expect(
      () => HomeBlockModel.fromJson(_hero('arbitrary')),
      throwsFormatException,
    );
  });
  for (final platform in CommercePlatform.values) {
    test(
      'central Builder hero alias works for ${platform.name} public designs',
      () {
        final origin = platform == CommercePlatform.shopify
            ? 'https://example-shop.myshopify.com'
            : 'https://store.example';
        final fixture = appDesignFixture58()
          ..['platform'] = switch (platform) {
            CommercePlatform.wooCommerce => 'woocommerce',
            CommercePlatform.shopify => 'shopify',
            CommercePlatform.odoo => 'odoo',
          }
          ..['store_origin'] = origin;
        (fixture['home'] as Map)['blocks'] = [_hero('inside')];
        final encoded = appDesignRawEncoded58(fixture);
        final bundle = AppDesignBundle58.fromEncoded(
          encoded,
          platform: platform,
          storeOrigin: Uri.parse(origin),
        );
        expect((bundle.toJson()['home']['blocks'] as List).length, 1);
        expect(
          () => AppDesignBundle58.fromEncoded(
            encoded,
            platform: platform,
            storeOrigin: Uri.parse('https://another.example'),
          ),
          throwsFormatException,
        );
      },
    );
  }
}
