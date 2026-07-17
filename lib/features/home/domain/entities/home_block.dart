enum HomeBlockType {
  appHeader('app_header'),
  heroSlider('hero_slider'),
  categoryGrid('category_grid'),
  imageBanner('image_banner'),
  productCarousel('product_carousel'),
  productGrid('product_grid'),
  sectionHeader('section_header'),
  brandCarousel('brand_carousel'),
  promoStrip('promo_strip'),
  couponBanner('coupon_banner'),
  countdown('countdown'),
  videoBanner('video_banner'),
  textBlock('text_block'),
  divider('divider'),
  spacer('spacer');

  const HomeBlockType(this.apiValue);

  final String apiValue;

  static HomeBlockType? tryParse(String value) {
    for (final HomeBlockType type in HomeBlockType.values) {
      if (type.apiValue == value) {
        return type;
      }
    }

    return null;
  }
}

class AppHeaderBlock extends HomeBlock {
  const AppHeaderBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.logoUrl,
    required this.title,
    required this.subtitle,
    required this.layout,
    required this.height,
    required this.logoHeight,
    required this.showSearch,
    required this.showCart,
    required this.showAccount,
    required this.titleColor,
    required this.iconColor,
  }) : super(type: HomeBlockType.appHeader);

  final String? logoUrl;
  final String title;
  final String? subtitle;
  final String layout;
  final double height;
  final double logoHeight;
  final bool showSearch;
  final bool showCart;
  final bool showAccount;
  final String titleColor;
  final String iconColor;
}

abstract class HomeBlock {
  const HomeBlock({
    required this.id,
    required this.type,
    required this.enabled,
    this.presentation = const HomeBlockPresentation(),
  });

  final String id;
  final HomeBlockType type;
  final bool enabled;
  final HomeBlockPresentation presentation;
}

class HomeBlockPresentation {
  const HomeBlockPresentation({
    this.marginTop = 0,
    this.marginBottom = 0,
    this.marginHorizontal = 0,
    this.paddingVertical = 0,
    this.paddingHorizontal = 0,
    this.backgroundColor,
    this.borderRadius = 0,
    this.contentScale = 1,
  });

  final double marginTop;
  final double marginBottom;
  final double marginHorizontal;
  final double paddingVertical;
  final double paddingHorizontal;
  final String? backgroundColor;
  final double borderRadius;
  final double contentScale;
}

class HomeAction {
  const HomeAction({required this.type, required this.value});

  final String type;
  final String value;
}

class HeroSlide {
  const HeroSlide({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final HomeAction? action;
}

class HeroSliderBlock extends HomeBlock {
  const HeroSliderBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.items,
    required this.aspectRatio,
    required this.autoPlay,
    required this.intervalMilliseconds,
  }) : super(type: HomeBlockType.heroSlider);

  final List<HeroSlide> items;
  final double aspectRatio;
  final bool autoPlay;
  final int intervalMilliseconds;
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.action,
  });

  final int id;
  final String name;
  final String imageUrl;
  final HomeAction? action;
}

class CategoryGridBlock extends HomeBlock {
  const CategoryGridBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.columns,
    required this.showNames,
  }) : super(type: HomeBlockType.categoryGrid);

  final String? title;
  final String? subtitle;
  final List<CategoryItem> items;
  final int columns;
  final bool showNames;
}

class ImageBannerBlock extends HomeBlock {
  const ImageBannerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.imageUrl,
    required this.aspectRatio,
    required this.borderRadius,
    required this.semanticLabel,
    required this.action,
  }) : super(type: HomeBlockType.imageBanner);

  final String imageUrl;
  final double aspectRatio;
  final double borderRadius;
  final String? semanticLabel;
  final HomeAction? action;
}

class HomeProductItem {
  const HomeProductItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.regularPrice,
    required this.currencyCode,
    required this.currencySymbol,
    required this.inStock,
    required this.badge,
    required this.action,
  });

  final int id;
  final String name;
  final String imageUrl;
  final String price;
  final String? regularPrice;
  final String currencyCode;
  final String currencySymbol;
  final bool inStock;
  final String? badge;
  final HomeAction? action;
}

class ProductCarouselBlock extends HomeBlock {
  const ProductCarouselBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.items,
    required this.showViewAll,
    required this.viewAllAction,
  }) : super(type: HomeBlockType.productCarousel);

  final String? title;
  final List<HomeProductItem> items;
  final bool showViewAll;
  final HomeAction? viewAllAction;
}

class ProductGridBlock extends HomeBlock {
  const ProductGridBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.columns,
    required this.showViewAll,
    required this.viewAllLabel,
    required this.viewAllAction,
  }) : super(type: HomeBlockType.productGrid);

  final String? title;
  final String? subtitle;
  final List<HomeProductItem> items;
  final int columns;
  final bool showViewAll;
  final String? viewAllLabel;
  final HomeAction? viewAllAction;
}

class SectionHeaderBlock extends HomeBlock {
  const SectionHeaderBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.action,
  }) : super(type: HomeBlockType.sectionHeader);

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final HomeAction? action;
}

class BrandItem {
  const BrandItem({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.action,
  });

  final int id;
  final String name;
  final String logoUrl;
  final HomeAction? action;
}

class BrandCarouselBlock extends HomeBlock {
  const BrandCarouselBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.items,
    required this.itemWidth,
  }) : super(type: HomeBlockType.brandCarousel);

  final String? title;
  final List<BrandItem> items;
  final double itemWidth;
}

class PromoStripBlock extends HomeBlock {
  const PromoStripBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.action,
  }) : super(type: HomeBlockType.promoStrip);

  final String text;
  final String backgroundColor;
  final String textColor;
  final HomeAction? action;
}

class CouponBannerBlock extends HomeBlock {
  const CouponBannerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.description,
    required this.couponCode,
    required this.imageUrl,
  }) : super(type: HomeBlockType.couponBanner);

  final String? title;
  final String? description;
  final String? couponCode;
  final String? imageUrl;
}

class CountdownBlock extends HomeBlock {
  const CountdownBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.endsAt,
    required this.expiredText,
  }) : super(type: HomeBlockType.countdown);

  final String? title;
  final DateTime? endsAt;
  final String expiredText;
}

class VideoBannerBlock extends HomeBlock {
  const VideoBannerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.videoUrl,
    required this.posterUrl,
    required this.aspectRatio,
    required this.autoPlay,
    required this.muted,
    required this.loop,
    required this.action,
  }) : super(type: HomeBlockType.videoBanner);

  final String videoUrl;
  final String? posterUrl;
  final double aspectRatio;
  final bool autoPlay;
  final bool muted;
  final bool loop;
  final HomeAction? action;
}

enum HomeTextAlignment {
  left,
  center,
  right;

  static HomeTextAlignment? tryParse(String value) {
    for (final HomeTextAlignment alignment in values) {
      if (alignment.name == value) {
        return alignment;
      }
    }

    return null;
  }
}

class TextBlock extends HomeBlock {
  const TextBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.content,
    required this.alignment,
    required this.backgroundColor,
    required this.textColor,
  }) : super(type: HomeBlockType.textBlock);

  final String? title;
  final String? content;
  final HomeTextAlignment alignment;
  final String? backgroundColor;
  final String textColor;
}

class DividerBlock extends HomeBlock {
  const DividerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.color,
    required this.thickness,
    required this.margin,
  }) : super(type: HomeBlockType.divider);

  final String color;
  final double thickness;
  final double margin;
}

class SpacerBlock extends HomeBlock {
  const SpacerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.height,
  }) : super(type: HomeBlockType.spacer);

  final double height;
}
