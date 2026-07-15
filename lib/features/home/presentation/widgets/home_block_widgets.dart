import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/shared/widgets/banner/app_image_banner.dart';
import 'package:kidia_store_app/shared/widgets/category/category_card.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:kidia_store_app/shared/widgets/product/product_badge.dart';
import 'package:kidia_store_app/shared/widgets/product/product_card.dart';

class HeroSliderBlockWidget extends StatefulWidget {
  const HeroSliderBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final HeroSliderBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  State<HeroSliderBlockWidget> createState() {
    return _HeroSliderBlockWidgetState();
  }
}

class _HeroSliderBlockWidgetState extends State<HeroSliderBlockWidget> {
  late final PageController _pageController;

  Timer? _autoPlayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _configureAutoPlay();
  }

  @override
  void didUpdateWidget(covariant HeroSliderBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool configurationChanged =
        oldWidget.block.autoPlay != widget.block.autoPlay ||
            oldWidget.block.intervalMilliseconds !=
                widget.block.intervalMilliseconds ||
            oldWidget.block.items.length != widget.block.items.length;

    if (configurationChanged) {
      _configureAutoPlay();
    }

    if (_currentPage >= widget.block.items.length) {
      _currentPage = 0;
    }
  }

  void _configureAutoPlay() {
    _autoPlayTimer?.cancel();

    if (!widget.block.autoPlay || widget.block.items.length < 2) {
      return;
    }

    _autoPlayTimer = Timer.periodic(
      Duration(
        milliseconds: widget.block.intervalMilliseconds,
      ),
          (_) {
        if (!mounted || !_pageController.hasClients) {
          return;
        }

        final int nextPage =
            (_currentPage + 1) % widget.block.items.length;

        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: widget.block.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.block.items.length,
                onPageChanged: (int page) {
                  if (_currentPage == page) {
                    return;
                  }

                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (
                    BuildContext context,
                    int index,
                    ) {
                  final HeroSlide slide = widget.block.items[index];

                  return _HeroSlideCard(
                    slide: slide,
                    onAction: widget.onAction,
                  );
                },
              ),
            ),
          ),
          if (widget.block.items.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                widget.block.items.length,
                    (int index) {
                  final bool selected = index == _currentPage;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: selected ? 22 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroSlideCard extends StatelessWidget {
  const _HeroSlideCard({
    required this.slide,
    required this.onAction,
  });

  final HeroSlide slide;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final HomeAction? action = slide.action;

    return Semantics(
      button: action != null,
      label: slide.title ?? slide.subtitle,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: action == null
              ? null
              : () {
            onAction(action);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                imageUrl: slide.imageUrl,
                fit: BoxFit.cover,
                semanticLabel: slide.title ?? slide.subtitle,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Color(0xB8000000),
                      Color(0x52000000),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              if (slide.title != null || slide.subtitle != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 255,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (slide.title != null)
                            Text(
                              slide.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                          if (slide.subtitle != null) ...[
                            const SizedBox(height: 7),
                            Text(
                              slide.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                color: const Color(0xFFF3F3F3),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryGridBlockWidget extends StatelessWidget {
  const CategoryGridBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final CategoryGridBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final int columns = block.columns.clamp(2, 6).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: LayoutBuilder(
        builder: (
            BuildContext context,
            BoxConstraints constraints,
            ) {
          const double spacing = 4;

          final double itemWidth =
              (constraints.maxWidth - ((columns - 1) * spacing)) /
                  columns;

          final double imageSize = (itemWidth - 12).clamp(
            54,
            86,
          );

          return GridView.builder(
            itemCount: block.items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: 10,
              childAspectRatio: block.showNames ? 0.76 : 1,
            ),
            itemBuilder: (
                BuildContext context,
                int index,
                ) {
              final CategoryItem item = block.items[index];
              final HomeAction? action = item.action;

              return CategoryCard(
                name: item.name,
                imageUrl: item.imageUrl,
                imageSize: imageSize,
                showName: block.showNames,
                compact: columns >= 4,
                onTap: action == null
                    ? null
                    : () {
                  onAction(action);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ImageBannerBlockWidget extends StatelessWidget {
  const ImageBannerBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final ImageBannerBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final HomeAction? action = block.action;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: AppImageBanner(
        imageUrl: block.imageUrl,
        aspectRatio: block.aspectRatio,
        borderRadius: block.borderRadius,
        semanticLabel: block.semanticLabel,
        onTap: action == null
            ? null
            : () {
          onAction(action);
        },
      ),
    );
  }
}

class ProductCarouselBlockWidget extends StatelessWidget {
  const ProductCarouselBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final ProductCarouselBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          if (block.title != null)
            HomeBlockTitle(
              title: block.title!,
              showAction: block.showViewAll,
              actionLabel: 'عرض الكل',
              onPressed: block.viewAllAction == null
                  ? null
                  : () {
                onAction(block.viewAllAction!);
              },
            ),
          SizedBox(
            height: 304,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: block.items.length,
              separatorBuilder: (
                  BuildContext context,
                  int index,
                  ) {
                return const SizedBox(width: 12);
              },
              itemBuilder: (
                  BuildContext context,
                  int index,
                  ) {
                return SizedBox(
                  width: 178,
                  child: _HomeProductCardAdapter(
                    product: block.items[index],
                    onAction: onAction,
                    compact: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductGridBlockWidget extends StatelessWidget {
  const ProductGridBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final ProductGridBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final int columns = block.columns.clamp(1, 4).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          if (block.title != null)
            HomeBlockTitle(
              title: block.title!,
              showAction: block.showViewAll,
              actionLabel: 'عرض الكل',
              onPressed: block.viewAllAction == null
                  ? null
                  : () {
                onAction(block.viewAllAction!);
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              itemCount: block.items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 1.15 : 0.59,
              ),
              itemBuilder: (
                  BuildContext context,
                  int index,
                  ) {
                return _HomeProductCardAdapter(
                  product: block.items[index],
                  onAction: onAction,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeaderBlockWidget extends StatelessWidget {
  const SectionHeaderBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final SectionHeaderBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (block.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    block.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (block.actionLabel != null &&
              block.action != null)
            TextButton(
              onPressed: () {
                onAction(block.action!);
              },
              child: Text(block.actionLabel!),
            ),
        ],
      ),
    );
  }
}

class BrandCarouselBlockWidget extends StatelessWidget {
  const BrandCarouselBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final BrandCarouselBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: block.items.length,
        separatorBuilder: (
            BuildContext context,
            int index,
            ) {
          return const SizedBox(width: 12);
        },
        itemBuilder: (
            BuildContext context,
            int index,
            ) {
          final BrandItem item = block.items[index];
          final HomeAction? action = item.action;

          return SizedBox(
            width: block.itemWidth,
            child: Semantics(
              button: action != null,
              label: item.name,
              child: Material(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: action == null
                      ? null
                      : () {
                    onAction(action);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: AppNetworkImage(
                      imageUrl: item.logoUrl,
                      fit: BoxFit.contain,
                      semanticLabel: item.name,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeProductCardAdapter extends StatelessWidget {
  const _HomeProductCardAdapter({
    required this.product,
    required this.onAction,
    this.compact = false,
  });

  final HomeProductItem product;
  final ValueChanged<HomeAction> onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final HomeAction? action = product.action;

    return ProductCard(
      name: product.name,
      imageUrl: product.imageUrl,
      price: product.price,
      regularPrice: product.regularPrice,
      currencySymbol: product.currencySymbol,
      inStock: product.inStock,
      badgeLabel: product.badge,
      badgeType: _resolveBadgeType(product),
      compact: compact,
      onTap: action == null
          ? null
          : () {
        onAction(action);
      },
    );
  }

  ProductBadgeType _resolveBadgeType(
      HomeProductItem product,
      ) {
    if (!product.inStock) {
      return ProductBadgeType.outOfStock;
    }

    final String badge = product.badge?.trim().toLowerCase() ?? '';

    if (badge.contains('جديد') || badge.contains('new')) {
      return ProductBadgeType.newArrival;
    }

    if (badge.contains('عرض') ||
        badge.contains('خصم') ||
        badge.contains('offer') ||
        badge.contains('sale')) {
      return ProductBadgeType.offer;
    }

    return ProductBadgeType.custom;
  }
}

class HomeBlockTitle extends StatelessWidget {
  const HomeBlockTitle({
    required this.title,
    required this.showAction,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final bool showAction;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (showAction && onPressed != null)
            TextButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}