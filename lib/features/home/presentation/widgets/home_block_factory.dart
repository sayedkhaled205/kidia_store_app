import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_widgets.dart';

abstract final class HomeBlockFactory {
  const HomeBlockFactory._();

  static Widget create({
    required HomeBlock block,
    required ValueChanged<HomeAction> onAction,
  }) {
    return switch (block) {
      HeroSliderBlock heroSliderBlock => HeroSliderBlockWidget(
        block: heroSliderBlock,
        onAction: onAction,
      ),
      CategoryGridBlock categoryGridBlock => CategoryGridBlockWidget(
        block: categoryGridBlock,
        onAction: onAction,
      ),
      ImageBannerBlock imageBannerBlock => ImageBannerBlockWidget(
        block: imageBannerBlock,
        onAction: onAction,
      ),
      ProductCarouselBlock productCarouselBlock =>
          ProductCarouselBlockWidget(
            block: productCarouselBlock,
            onAction: onAction,
          ),
      ProductGridBlock productGridBlock => ProductGridBlockWidget(
        block: productGridBlock,
        onAction: onAction,
      ),
      SectionHeaderBlock sectionHeaderBlock =>
          SectionHeaderBlockWidget(
            block: sectionHeaderBlock,
            onAction: onAction,
          ),
      BrandCarouselBlock brandCarouselBlock =>
          BrandCarouselBlockWidget(
            block: brandCarouselBlock,
            onAction: onAction,
          ),
      SpacerBlock spacerBlock => SizedBox(
        height: spacerBlock.height,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}