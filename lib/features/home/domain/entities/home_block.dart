enum HomeBlockType {
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

abstract class HomeBlock {
  const HomeBlock({
    required this.id,
    required this.type,
    required this.enabled,
  });

  final String id;
  final HomeBlockType type;
  final bool enabled;
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
    required this.items,
    required this.aspectRatio,
    required this.autoPlay,
    required this.intervalMilliseconds,
    required this.loop,
    required this.showArrows,
    required this.showDots,
    required this.transition,
    required this.slideDirection,
  }) : super(type: HomeBlockType.heroSlider);

  final List<HeroSlide> items;
  final double aspectRatio;
  final bool autoPlay;
  final int intervalMilliseconds;
  final bool loop;
  final bool showArrows;
  final bool showDots;
  final String transition;
  final String slideDirection;
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.count,
    required this.action,
  });

  final int id;
  final String name;
  final String imageUrl;
  final int count;
  final HomeAction? action;
}

class CategoryGridBlock extends HomeBlock {
  const CategoryGridBlock({
    required super.id,
    required super.enabled,
    required this.items,
    required this.columns,
    required this.layout,
    required this.style,
    required this.gap,
    required this.imageRatio,
    required this.showNames,
    required this.showCount,
  }) : super(type: HomeBlockType.categoryGrid);

  final List<CategoryItem> items;
  final int columns;
  final String layout;
  final String style;
  final double gap;
  final double imageRatio;
  final bool showNames;
  final bool showCount;
}

class ImageBannerBlock extends HomeBlock {
  const ImageBannerBlock({
    required super.id,
    required super.enabled,
    required this.imageUrl,
    required this.aspectRatio,
    required this.borderRadius,
    required this.semanticLabel,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.imageFit,
    required this.focalX,
    required this.focalY,
    required this.overlayColor,
    required this.overlayOpacity,
    required this.action,
  }) : super(type: HomeBlockType.imageBanner);

  final String imageUrl;
  final double aspectRatio;
  final double borderRadius;
  final String? semanticLabel;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;
  final String imageFit;
  final double focalX;
  final double focalY;
  final String overlayColor;
  final double overlayOpacity;
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
    required this.stockStatus,
    required this.badge,
    required this.rating,
    required this.ratingCount,
    required this.reviewCount,
    required this.category,
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
  final String stockStatus;
  final String? badge;
  final double rating;
  final int ratingCount;
  final int reviewCount;
  final String? category;
  final HomeAction? action;
}

class ProductDisplaySettings {
  const ProductDisplaySettings({
    required this.cardsVisible,
    required this.gap,
    required this.cardStyle,
    required this.imageRatio,
    required this.showRating,
    required this.showCategory,
    required this.showBadge,
    required this.showStock,
    required this.showArrows,
    required this.showDots,
  });

  final double cardsVisible;
  final double gap;
  final String cardStyle;
  final double imageRatio;
  final bool showRating;
  final bool showCategory;
  final bool showBadge;
  final bool showStock;
  final bool showArrows;
  final bool showDots;
}

class ProductCarouselBlock extends HomeBlock {
  const ProductCarouselBlock({
    required super.id,
    required super.enabled,
    required this.title,
    required this.items,
    required this.showViewAll,
    required this.viewAllAction,
    required this.display,
  }) : super(type: HomeBlockType.productCarousel);

  final String? title;
  final List<HomeProductItem> items;
  final bool showViewAll;
  final HomeAction? viewAllAction;
  final ProductDisplaySettings display;
}

class ProductGridBlock extends HomeBlock {
  const ProductGridBlock({
    required super.id,
    required super.enabled,
    required this.title,
    required this.items,
    required this.columns,
    required this.gap,
    required this.cardStyle,
    required this.imageRatio,
    required this.showRating,
    required this.showBadge,
    required this.showStock,
    required this.showViewAll,
    required this.viewAllAction,
  }) : super(type: HomeBlockType.productGrid);

  final String? title;
  final List<HomeProductItem> items;
  final int columns;
  final double gap;
  final String cardStyle;
  final double imageRatio;
  final bool showRating;
  final bool showBadge;
  final bool showStock;
  final bool showViewAll;
  final HomeAction? viewAllAction;
}

class SectionHeaderBlock extends HomeBlock {
  const SectionHeaderBlock({
    required super.id,
    required super.enabled,
    required this.title,
    required this.subtitle,
    required this.showViewAll,
    required this.viewAllLabel,
    required this.alignment,
    required this.icon,
    required this.dividerStyle,
    required this.action,
  }) : super(type: HomeBlockType.sectionHeader);

  final String title;
  final String? subtitle;
  final bool showViewAll;
  final String? viewAllLabel;
  final String alignment;
  final String? icon;
  final String dividerStyle;
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
    required this.title,
    required this.items,
    required this.itemWidth,
    required this.layout,
    required this.columns,
    required this.gap,
    required this.showNames,
  }) : super(type: HomeBlockType.brandCarousel);

  final String? title;
  final List<BrandItem> items;
  final double itemWidth;
  final String layout;
  final int columns;
  final double gap;
  final bool showNames;
}

class PromoStripBlock extends HomeBlock {
  const PromoStripBlock({
    required super.id,
    required super.enabled,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.buttonLabel,
    required this.dismissible,
    required this.borderRadius,
    required this.padding,
    required this.action,
  }) : super(type: HomeBlockType.promoStrip);

  final String text;
  final String backgroundColor;
  final String textColor;
  final String? buttonLabel;
  final bool dismissible;
  final double borderRadius;
  final double padding;
  final HomeAction? action;
}

class CouponBannerBlock extends HomeBlock {
  const CouponBannerBlock({
    required super.id,
    required super.enabled,
    required this.title,
    required this.description,
    required this.couponCode,
    required this.imageUrl,
    required this.copyButtonLabel,
    required this.expiresAt,
    required this.backgroundColor,
    required this.textColor,
    required this.buttonLabel,
    required this.action,
  }) : super(type: HomeBlockType.couponBanner);

  final String title;
  final String? description;
  final String? couponCode;
  final String? imageUrl;
  final String copyButtonLabel;
  final DateTime? expiresAt;
  final String backgroundColor;
  final String textColor;
  final String? buttonLabel;
  final HomeAction? action;
}

class CountdownBlock extends HomeBlock {
  const CountdownBlock({
    required super.id,
    required super.enabled,
    required this.title,
    required this.endsAt,
    required this.expiredText,
    required this.endBehavior,
    required this.daysLabel,
    required this.hoursLabel,
    required this.minutesLabel,
    required this.secondsLabel,
    required this.backgroundColor,
    required this.textColor,
    required this.action,
  }) : super(type: HomeBlockType.countdown);

  final String? title;
  final DateTime endsAt;
  final String expiredText;
  final String endBehavior;
  final String daysLabel;
  final String hoursLabel;
  final String minutesLabel;
  final String secondsLabel;
  final String backgroundColor;
  final String textColor;
  final HomeAction? action;
}

class VideoBannerBlock extends HomeBlock {
  const VideoBannerBlock({
    required super.id,
    required super.enabled,
    required this.videoUrl,
    required this.posterUrl,
    required this.aspectRatio,
    required this.autoPlay,
    required this.muted,
    required this.loop,
    required this.showControls,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.overlayColor,
    required this.overlayOpacity,
    required this.action,
  }) : super(type: HomeBlockType.videoBanner);

  final String videoUrl;
  final String? posterUrl;
  final double aspectRatio;
  final bool autoPlay;
  final bool muted;
  final bool loop;
  final bool showControls;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;
  final String overlayColor;
  final double overlayOpacity;
  final HomeAction? action;
}

class TextBlock extends HomeBlock {
  const TextBlock({
    required super.id,
    required super.enabled,
    required this.title,
    required this.content,
    required this.alignment,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.padding,
    required this.borderRadius,
  }) : super(type: HomeBlockType.textBlock);

  final String? title;
  final String content;
  final String alignment;
  final String? backgroundColor;
  final String textColor;
  final double fontSize;
  final double padding;
  final double borderRadius;
}

class DividerBlock extends HomeBlock {
  const DividerBlock({
    required super.id,
    required super.enabled,
    required this.color,
    required this.thickness,
    required this.margin,
    required this.style,
    required this.widthPercent,
    required this.alignment,
  }) : super(type: HomeBlockType.divider);

  final String color;
  final double thickness;
  final double margin;
  final String style;
  final double widthPercent;
  final String alignment;
}

class SpacerBlock extends HomeBlock {
  const SpacerBlock({
    required super.id,
    required super.enabled,
    required this.height,
    required this.tabletHeight,
    required this.desktopHeight,
  }) : super(type: HomeBlockType.spacer);

  final double height;
  final double tabletHeight;
  final double desktopHeight;
}
