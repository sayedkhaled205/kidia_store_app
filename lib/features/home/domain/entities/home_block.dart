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
  spacer('spacer'),
  quickLinks('quick_links'),
  bannerGrid('banner_grid');

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
    this.backgroundColor = '#FFFFFF',
    this.searchStyle = 'icon',
    this.searchPlaceholder = 'Search products',
    this.searchBackground = '#F1F3F4',
    this.searchTextColor = '#5F6368',
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
  final String backgroundColor;
  final String searchStyle;
  final String searchPlaceholder;
  final String searchBackground;
  final String searchTextColor;
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
    required this.buttonLabel,
    required this.action,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;
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
    required this.borderRadius,
    required this.horizontalPadding,
    required this.imageFit,
    required this.overlayPosition,
    required this.overlayStrength,
    required this.textColor,
    required this.showIndicators,
    required this.indicatorStyle,
  }) : super(type: HomeBlockType.heroSlider);

  final List<HeroSlide> items;
  final double aspectRatio;
  final bool autoPlay;
  final int intervalMilliseconds;
  final double borderRadius;
  final double horizontalPadding;
  final String imageFit;
  final String overlayPosition;
  final double overlayStrength;
  final String textColor;
  final bool showIndicators;
  final String indicatorStyle;
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
    required this.layout,
    required this.imageShape,
    required this.imageSize,
    required this.gap,
    required this.labelSize,
    required this.labelColor,
  }) : super(type: HomeBlockType.categoryGrid);

  final String? title;
  final String? subtitle;
  final List<CategoryItem> items;
  final int columns;
  final bool showNames;
  final String layout;
  final String imageShape;
  final double imageSize;
  final double gap;
  final double labelSize;
  final String labelColor;
}

class QuickLinkItem {
  const QuickLinkItem({
    required this.id,
    required this.imageUrl,
    required this.label,
    required this.subtitle,
    required this.action,
  });

  final String id;
  final String imageUrl;
  final String label;
  final String? subtitle;
  final HomeAction? action;
}

class QuickLinksBlock extends HomeBlock {
  const QuickLinksBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.layout,
    required this.columns,
    required this.imageShape,
    required this.itemSize,
    required this.gap,
    required this.showLabels,
    required this.labelColor,
    required this.labelSize,
    required this.items,
  }) : super(type: HomeBlockType.quickLinks);

  final String? title;
  final String? subtitle;
  final String layout;
  final int columns;
  final String imageShape;
  final double itemSize;
  final double gap;
  final bool showLabels;
  final String labelColor;
  final double labelSize;
  final List<QuickLinkItem> items;
}

class BannerGridItem {
  const BannerGridItem({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.action,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;
  final HomeAction? action;
}

class BannerGridBlock extends HomeBlock {
  const BannerGridBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.layout,
    required this.columns,
    required this.gap,
    required this.aspectRatio,
    required this.borderRadius,
    required this.imageFit,
    required this.overlayStrength,
    required this.textColor,
    required this.items,
  }) : super(type: HomeBlockType.bannerGrid);

  final String? title;
  final String? subtitle;
  final String layout;
  final int columns;
  final double gap;
  final double aspectRatio;
  final double borderRadius;
  final String imageFit;
  final double overlayStrength;
  final String textColor;
  final List<BannerGridItem> items;
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
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.imageFit,
    required this.overlayStrength,
    required this.textColor,
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
  final double overlayStrength;
  final String textColor;
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
    required this.rating,
    required this.reviewCount,
    required this.discountPercent,
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
  final double rating;
  final int reviewCount;
  final int discountPercent;
  final HomeAction? action;
}

class ProductCarouselBlock extends HomeBlock {
  const ProductCarouselBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.showViewAll,
    required this.viewAllLabel,
    required this.viewAllAction,
    required this.cardStyle,
    required this.itemWidth,
    required this.imageRatio,
    required this.cardRadius,
    required this.showName,
    required this.showPrice,
    required this.showRegularPrice,
    required this.showBadge,
    required this.showRating,
  }) : super(type: HomeBlockType.productCarousel);

  final String? title;
  final String? subtitle;
  final List<HomeProductItem> items;
  final bool showViewAll;
  final String? viewAllLabel;
  final HomeAction? viewAllAction;
  final String cardStyle;
  final double itemWidth;
  final double imageRatio;
  final double cardRadius;
  final bool showName;
  final bool showPrice;
  final bool showRegularPrice;
  final bool showBadge;
  final bool showRating;
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
    required this.cardStyle,
    required this.imageRatio,
    required this.cardRadius,
    required this.showName,
    required this.showPrice,
    required this.showRegularPrice,
    required this.showBadge,
    required this.showRating,
  }) : super(type: HomeBlockType.productGrid);

  final String? title;
  final String? subtitle;
  final List<HomeProductItem> items;
  final int columns;
  final bool showViewAll;
  final String? viewAllLabel;
  final HomeAction? viewAllAction;
  final String cardStyle;
  final double imageRatio;
  final double cardRadius;
  final bool showName;
  final bool showPrice;
  final bool showRegularPrice;
  final bool showBadge;
  final bool showRating;
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
    required this.subtitle,
    required this.items,
    required this.itemWidth,
    required this.layout,
    required this.columns,
    required this.imageShape,
    required this.showNames,
    required this.gap,
  }) : super(type: HomeBlockType.brandCarousel);

  final String? title;
  final String? subtitle;
  final List<BrandItem> items;
  final double itemWidth;
  final String layout;
  final int columns;
  final String imageShape;
  final bool showNames;
  final double gap;
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
    this.backgroundColor = '#DCEEE8',
    this.textColor = '#1F2933',
    this.accentColor = '#2F806E',
    this.borderRadius = 20,
    this.action,
  }) : super(type: HomeBlockType.couponBanner);

  final String? title;
  final String? description;
  final String? couponCode;
  final String? imageUrl;
  final String backgroundColor;
  final String textColor;
  final String accentColor;
  final double borderRadius;
  final HomeAction? action;
}

class CountdownBlock extends HomeBlock {
  const CountdownBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.endsAt,
    required this.expiredText,
    this.backgroundColor = '#FFFFFF',
    this.textColor = '#1F2933',
    this.boxColor = '#E9EEEC',
    this.action,
  }) : super(type: HomeBlockType.countdown);

  final String? title;
  final DateTime? endsAt;
  final String expiredText;
  final String backgroundColor;
  final String textColor;
  final String boxColor;
  final HomeAction? action;
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
    this.titleSize = 22,
    this.contentSize = 15,
    this.fontWeight = 'normal',
  }) : super(type: HomeBlockType.textBlock);

  final String? title;
  final String? content;
  final HomeTextAlignment alignment;
  final String? backgroundColor;
  final String textColor;
  final double titleSize;
  final double contentSize;
  final String fontWeight;
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
