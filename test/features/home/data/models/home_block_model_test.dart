import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/home/data/models/home_block_model.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';

void main() {
  const String image = 'https://example.com/image.jpg';
  const String video = 'https://example.com/video.mp4';

  Map<String, dynamic> block(String type, Map<String, dynamic> data) {
    return <String, dynamic>{
      'id': 'test_$type',
      'type': type,
      'enabled': true,
      'data': data,
    };
  }

  final Map<String, Map<String, dynamic>> fixtures =
      <String, Map<String, dynamic>>{
        'hero_slider': block('hero_slider', <String, dynamic>{
          'aspect_ratio': 1.8,
          'auto_play': true,
          'interval_ms': 3000,
          'loop': false,
          'show_arrows': false,
          'show_dots': true,
          'transition': 'fade',
          'slide_direction': 'vertical',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'slide_1', 'image_url': image},
          ],
        }),
        'category_grid': block('category_grid', <String, dynamic>{
          'columns_mobile': 3,
          'layout': 'carousel',
          'style': 'card',
          'show_names': true,
          'show_count': true,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 2,
              'name': 'Category',
              'image_url': image,
              'count': 8,
            },
          ],
        }),
        'image_banner': block('image_banner', <String, dynamic>{
          'image_url': image,
          'title': 'Banner',
          'image_fit': 'contain',
          'focal_x': 20,
          'focal_y': 80,
          'overlay_opacity': 0.4,
        }),
        'product_carousel': block('product_carousel', <String, dynamic>{
          'title': 'Products',
          'items': <Map<String, dynamic>>[_product(image)],
          'layout': <String, dynamic>{
            'cards_visible': 2.2,
            'gap': 8,
            'show_rating': true,
          },
        }),
        'product_grid': block('product_grid', <String, dynamic>{
          'items': <Map<String, dynamic>>[_product(image)],
          'columns_mobile': 2,
          'gap': 9,
          'show_rating': true,
        }),
        'section_header': block('section_header', <String, dynamic>{
          'title': 'Header',
          'show_view_all': true,
          'view_all_label': 'All',
          'alignment': 'center',
          'divider_style': 'underline',
        }),
        'brand_carousel': block('brand_carousel', <String, dynamic>{
          'title': 'Brands',
          'layout': 'grid',
          'columns_mobile': 3,
          'show_names': true,
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'id': 7, 'name': 'Brand', 'logo_url': image},
          ],
        }),
        'promo_strip': block('promo_strip', <String, dynamic>{
          'text': 'Promotion',
          'dismissible': true,
          'button_label': 'Shop',
        }),
        'coupon_banner': block('coupon_banner', <String, dynamic>{
          'title': 'Coupon',
          'coupon_code': 'SAVE10',
          'copy_button_label': 'Copy',
        }),
        'countdown': block('countdown', <String, dynamic>{
          'title': 'Offer',
          'ends_at': '2030-01-01T00:00:00Z',
          'end_behavior': 'message',
        }),
        'video_banner': block('video_banner', <String, dynamic>{
          'video_url': video,
          'poster_url': image,
          'show_controls': true,
          'loop': true,
        }),
        'text_block': block('text_block', <String, dynamic>{
          'title': 'Text',
          'content': '<p>Hello <strong>world</strong></p>',
          'font_size': 18,
        }),
        'divider': block('divider', <String, dynamic>{
          'style': 'dashed',
          'width_percent': 70,
          'thickness': 2,
        }),
        'spacer': block('spacer', <String, dynamic>{
          'height': 10,
          'height_tablet': 20,
          'height_desktop': 30,
        }),
      };

  test('parses every registered CMS block type without skipping', () {
    final List<HomeBlock> parsed = fixtures.values
        .map(HomeBlockModel.fromJson)
        .toList(growable: false);

    expect(parsed, hasLength(HomeBlockType.values.length));
    expect(
      parsed.map((HomeBlock value) => value.type).toSet(),
      HomeBlockType.values.toSet(),
    );
  });

  test('preserves expanded UX layout settings', () {
    final HeroSliderBlock hero =
        HomeBlockModel.fromJson(fixtures['hero_slider']!) as HeroSliderBlock;
    final CategoryGridBlock category =
        HomeBlockModel.fromJson(fixtures['category_grid']!)
            as CategoryGridBlock;
    final ProductCarouselBlock products =
        HomeBlockModel.fromJson(fixtures['product_carousel']!)
            as ProductCarouselBlock;
    final BrandCarouselBlock brands =
        HomeBlockModel.fromJson(fixtures['brand_carousel']!)
            as BrandCarouselBlock;

    expect(hero.transition, 'fade');
    expect(hero.slideDirection, 'vertical');
    expect(hero.loop, isFalse);
    expect(category.layout, 'carousel');
    expect(category.style, 'card');
    expect(category.items.single.count, 8);
    expect(products.display.cardsVisible, 2.2);
    expect(products.items.single.rating, 4.5);
    expect(products.items.single.reviewCount, 2);
    expect(products.items.single.stockStatus, 'instock');
    expect(products.items.single.category, 'Category');
    expect(brands.layout, 'grid');
    expect(brands.showNames, isTrue);

    final ImageBannerBlock banner =
        HomeBlockModel.fromJson(fixtures['image_banner']!) as ImageBannerBlock;
    expect(banner.focalX, 0.2);
    expect(banner.focalY, 0.8);
  });

  test('accepts square and card category styles', () {
    for (final String style in <String>['square', 'card']) {
      final CategoryGridBlock category =
          HomeBlockModel.fromJson(
                block('category_grid', <String, dynamic>{
                  'style': style,
                  'items': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 2,
                      'name': 'Category',
                      'image_url': image,
                    },
                  ],
                }),
              )
              as CategoryGridBlock;
      expect(category.style, style);
    }
  });

  test('supports legacy flat actions and ignores incomplete actions', () {
    final PromoStripBlock promo =
        HomeBlockModel.fromJson(
              block('promo_strip', <String, dynamic>{
                'text': 'Promotion',
                'action_type': 'category',
                'action_value': '12',
              }),
            )
            as PromoStripBlock;
    final ImageBannerBlock banner =
        HomeBlockModel.fromJson(
              block('image_banner', <String, dynamic>{
                'image_url': image,
                'action': <String, dynamic>{'type': 'product', 'value': ''},
              }),
            )
            as ImageBannerBlock;

    expect(promo.action?.type, 'category');
    expect(promo.action?.value, '12');
    expect(banner.action, isNull);
  });
}

Map<String, dynamic> _product(String image) {
  return <String, dynamic>{
    'id': 10,
    'name': 'Product',
    'image_url': image,
    'price': '99',
    'regular_price': '120',
    'currency_code': 'EGP',
    'currency_symbol': 'ج.م',
    'in_stock': true,
    'rating': 4.5,
    'rating_count': 3,
    'review_count': 2,
    'stock_status': 'instock',
    'category': 'Category',
  };
}
