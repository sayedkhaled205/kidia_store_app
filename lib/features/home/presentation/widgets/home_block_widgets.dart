import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
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
      Duration(milliseconds: widget.block.intervalMilliseconds),
      (_) {
        if (!mounted ||
            (widget.block.transition != 'fade' &&
                !_pageController.hasClients)) {
          return;
        }

        if (!widget.block.loop &&
            _currentPage >= widget.block.items.length - 1) {
          return;
        }

        final int nextPage = widget.block.loop
            ? (_currentPage + 1) % widget.block.items.length
            : _currentPage + 1;

        _goToPage(nextPage);
      },
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  void _moveBy(int delta) {
    if (widget.block.items.length < 2 ||
        (widget.block.transition != 'fade' && !_pageController.hasClients)) {
      return;
    }

    int nextPage = _currentPage + delta;
    if (widget.block.loop) {
      nextPage =
          (nextPage + widget.block.items.length) % widget.block.items.length;
    } else {
      nextPage = nextPage.clamp(0, widget.block.items.length - 1).toInt();
    }

    _goToPage(nextPage);
  }

  void _goToPage(int page) {
    if (widget.block.transition == 'fade') {
      setState(() => _currentPage = page);
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
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
              child: Stack(
                children: [
                  if (widget.block.transition == 'fade')
                    GestureDetector(
                      onHorizontalDragEnd: (DragEndDetails details) {
                        final double velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() > 80) {
                          _moveBy(velocity < 0 ? 1 : -1);
                        }
                      },
                      onVerticalDragEnd: (DragEndDetails details) {
                        if (widget.block.slideDirection != 'vertical') {
                          return;
                        }
                        final double velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() > 80) {
                          _moveBy(velocity < 0 ? 1 : -1);
                        }
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _HeroSlideCard(
                          key: ValueKey<String>(
                            widget.block.items[_currentPage].id,
                          ),
                          slide: widget.block.items[_currentPage],
                          onAction: widget.onAction,
                        ),
                      ),
                    )
                  else
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: widget.block.slideDirection == 'vertical'
                          ? Axis.vertical
                          : Axis.horizontal,
                      itemCount: widget.block.items.length,
                      onPageChanged: (int page) {
                        if (_currentPage == page) {
                          return;
                        }

                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final HeroSlide slide = widget.block.items[index];

                        return _HeroSlideCard(
                          key: ValueKey<String>(slide.id),
                          slide: slide,
                          onAction: widget.onAction,
                        );
                      },
                    ),
                  if (widget.block.showArrows &&
                      widget.block.items.length > 1) ...[
                    PositionedDirectional(
                      start: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _SliderArrowButton(
                          icon: Icons.chevron_left_rounded,
                          onPressed: () => _moveBy(-1),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      end: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _SliderArrowButton(
                          icon: Icons.chevron_right_rounded,
                          onPressed: () => _moveBy(1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.block.showDots && widget.block.items.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(widget.block.items.length, (
                int index,
              ) {
                final bool selected = index == _currentPage;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: selected ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
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
    super.key,
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
                      constraints: const BoxConstraints(maxWidth: 255),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (slide.title != null)
                            Text(
                              slide.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall
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
                              style: Theme.of(context).textTheme.bodyMedium
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

class _SliderArrowButton extends StatelessWidget {
  const _SliderArrowButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.36),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        visualDensity: VisualDensity.compact,
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

    if (block.items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (block.layout == 'carousel') {
      final double imageSize = block.style == 'card' ? 104 : 82;
      return SizedBox(
        height: block.showNames || block.showCount ? 145 : 112,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: block.items.length,
          separatorBuilder: (_, __) => SizedBox(width: block.gap),
          itemBuilder: (BuildContext context, int index) {
            return SizedBox(
              width: imageSize + 18,
              child: _categoryCard(
                item: block.items[index],
                imageSize: imageSize,
                compact: false,
              ),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double spacing = block.gap;

          final double itemWidth =
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

          final double imageSize = (itemWidth - 12).clamp(54, 86).toDouble();

          return GridView.builder(
            itemCount: block.items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: block.style == 'overlay'
                  ? block.imageRatio
                  : (block.showNames || block.showCount ? 0.72 : 1),
            ),
            itemBuilder: (BuildContext context, int index) {
              return _categoryCard(
                item: block.items[index],
                imageSize: imageSize,
                compact: columns >= 4,
              );
            },
          );
        },
      ),
    );
  }

  Widget _categoryCard({
    required CategoryItem item,
    required double imageSize,
    required bool compact,
  }) {
    final HomeAction? action = item.action;
    return CategoryCard(
      name: item.name,
      imageUrl: item.imageUrl,
      imageSize: imageSize,
      showName: block.showNames,
      compact: compact,
      count: item.count,
      showCount: block.showCount,
      style: block.style,
      imageAspectRatio: block.imageRatio,
      onTap: action == null ? null : () => onAction(action),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: AspectRatio(
        aspectRatio: block.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(block.borderRadius),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: action == null ? null : () => onAction(action),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    imageUrl: block.imageUrl,
                    fit: switch (block.imageFit) {
                      'contain' => BoxFit.contain,
                      'fill' => BoxFit.fill,
                      _ => BoxFit.cover,
                    },
                    alignment: Alignment(
                      (block.focalX * 2) - 1,
                      (block.focalY * 2) - 1,
                    ),
                    semanticLabel: block.semanticLabel ?? block.title,
                  ),
                  if (block.overlayOpacity > 0)
                    ColoredBox(
                      color: _hexColor(
                        block.overlayColor,
                      ).withValues(alpha: block.overlayOpacity),
                    ),
                  if (block.title != null ||
                      block.subtitle != null ||
                      block.buttonLabel != null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (block.title != null)
                              Text(
                                block.title!,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            if (block.subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                block.subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                            if (block.buttonLabel != null &&
                                action != null) ...[
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: () => onAction(action),
                                child: Text(block.buttonLabel!),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductCarouselBlockWidget extends StatefulWidget {
  const ProductCarouselBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final ProductCarouselBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  State<ProductCarouselBlockWidget> createState() =>
      _ProductCarouselBlockWidgetState();
}

class _ProductCarouselBlockWidgetState
    extends State<ProductCarouselBlockWidget> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) {
      return;
    }
    final double target = (_controller.offset + delta)
        .clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        )
        .toDouble();
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProductCarouselBlock block = widget.block;
    final ProductDisplaySettings display = block.display;

    if (block.items.isEmpty) {
      return const SizedBox.shrink();
    }

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
                      widget.onAction(block.viewAllAction!);
                    },
            ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double viewportWidth = constraints.maxWidth;
              final double itemWidth =
                  ((viewportWidth - 32) / display.cardsVisible)
                      .clamp(126, 260)
                      .toDouble();

              return SizedBox(
                height: display.showRating ? 330 : 306,
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: block.items.length,
                      separatorBuilder: (_, __) => SizedBox(width: display.gap),
                      itemBuilder: (BuildContext context, int index) {
                        return SizedBox(
                          width: itemWidth,
                          child: _HomeProductCardAdapter(
                            product: block.items[index],
                            onAction: widget.onAction,
                            compact: display.cardStyle == 'compact',
                            imageRatio: display.imageRatio,
                            showRating: display.showRating,
                            showCategory: display.showCategory,
                            showBadge: display.showBadge,
                            showStock: display.showStock,
                            cardStyle: display.cardStyle,
                          ),
                        );
                      },
                    ),
                    if (display.showArrows && block.items.length > 1) ...[
                      PositionedDirectional(
                        start: 6,
                        top: 115,
                        child: _SliderArrowButton(
                          icon: Icons.chevron_left_rounded,
                          onPressed: () => _scrollBy(-itemWidth),
                        ),
                      ),
                      PositionedDirectional(
                        end: 6,
                        top: 115,
                        child: _SliderArrowButton(
                          icon: Icons.chevron_right_rounded,
                          onPressed: () => _scrollBy(itemWidth),
                        ),
                      ),
                    ],
                    if (display.showDots && block.items.length > 1)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
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

    if (block.items.isEmpty) {
      return const SizedBox.shrink();
    }

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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: block.gap,
                mainAxisSpacing: block.gap,
                childAspectRatio: columns == 1
                    ? 1.15
                    : (block.showRating ? 0.53 : 0.59),
              ),
              itemBuilder: (BuildContext context, int index) {
                return _HomeProductCardAdapter(
                  product: block.items[index],
                  onAction: onAction,
                  compact: block.cardStyle == 'compact',
                  imageRatio: block.imageRatio,
                  showRating: block.showRating,
                  showBadge: block.showBadge,
                  showStock: block.showStock,
                  cardStyle: block.cardStyle,
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
    final CrossAxisAlignment crossAxisAlignment = switch (block.alignment) {
      'center' => CrossAxisAlignment.center,
      'end' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    final TextAlign textAlign = switch (block.alignment) {
      'center' => TextAlign.center,
      'end' => TextAlign.end,
      _ => TextAlign.start,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: crossAxisAlignment,
                  children: [
                    Row(
                      mainAxisAlignment: block.alignment == 'center'
                          ? MainAxisAlignment.center
                          : block.alignment == 'end'
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (block.icon != null) ...[
                          Icon(
                            _iconForName(block.icon!),
                            color: colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            block.title,
                            textAlign: textAlign,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (block.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        block.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: textAlign,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (block.showViewAll &&
                  block.viewAllLabel != null &&
                  block.action != null)
                TextButton(
                  onPressed: () => onAction(block.action!),
                  child: Text(block.viewAllLabel!),
                ),
            ],
          ),
          if (block.dividerStyle == 'line') ...[
            const SizedBox(height: 10),
            Divider(color: colorScheme.outlineVariant, height: 1),
          ] else if (block.dividerStyle == 'underline') ...[
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 3,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
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
    if (block.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final Widget content = block.layout == 'grid'
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: block.items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: block.columns,
                crossAxisSpacing: block.gap,
                mainAxisSpacing: block.gap,
                childAspectRatio: block.showNames ? 0.82 : 1,
              ),
              itemBuilder: (_, int index) => _BrandCard(
                item: block.items[index],
                showName: block.showNames,
                onAction: onAction,
              ),
            ),
          )
        : SizedBox(
            height: block.showNames ? 142 : 116,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: block.items.length,
              separatorBuilder: (_, __) => SizedBox(width: block.gap),
              itemBuilder: (_, int index) => SizedBox(
                width: block.itemWidth,
                child: _BrandCard(
                  item: block.items[index],
                  showName: block.showNames,
                  onAction: onAction,
                ),
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (block.title != null)
            HomeBlockTitle(
              title: block.title!,
              showAction: false,
              actionLabel: '',
              onPressed: null,
            ),
          content,
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.item,
    required this.showName,
    required this.onAction,
  });

  final BrandItem item;
  final bool showName;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final HomeAction? action = item.action;
    return Semantics(
      button: action != null,
      label: item.name,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action == null ? null : () => onAction(action),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: AppNetworkImage(
                    imageUrl: item.logoUrl,
                    fit: BoxFit.contain,
                    semanticLabel: item.name,
                  ),
                ),
                if (showName) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeProductCardAdapter extends StatelessWidget {
  const _HomeProductCardAdapter({
    required this.product,
    required this.onAction,
    this.compact = false,
    this.imageRatio = 1,
    this.showRating = true,
    this.showCategory = false,
    this.showBadge = true,
    this.showStock = true,
    this.cardStyle = 'standard',
  });

  final HomeProductItem product;
  final ValueChanged<HomeAction> onAction;
  final bool compact;
  final double imageRatio;
  final bool showRating;
  final bool showCategory;
  final bool showBadge;
  final bool showStock;
  final String cardStyle;

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
      imageAspectRatio: imageRatio,
      rating: product.rating,
      ratingCount: product.ratingCount,
      showRating: showRating,
      category: product.category,
      showCategory: showCategory,
      showBadge: showBadge,
      showStock: showStock,
      cardStyle: cardStyle,
      onTap: action == null
          ? null
          : () {
              onAction(action);
            },
    );
  }

  ProductBadgeType _resolveBadgeType(HomeProductItem product) {
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          if (showAction && onPressed != null)
            TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

Color _hexColor(String value) {
  final String normalized = value.replaceFirst('#', '');
  final String withAlpha = normalized.length == 6
      ? 'FF$normalized'
      : normalized;
  return Color(int.tryParse(withAlpha, radix: 16) ?? 0xFF000000);
}

IconData _iconForName(String value) {
  return switch (value.trim().toLowerCase()) {
    'star' || 'favorite' => Icons.star_rounded,
    'sale' || 'offer' || 'local_offer' => Icons.local_offer_rounded,
    'new' || 'auto_awesome' => Icons.auto_awesome_rounded,
    'category' || 'grid' => Icons.grid_view_rounded,
    'shopping_bag' || 'bag' => Icons.shopping_bag_rounded,
    'bolt' || 'flash' => Icons.bolt_rounded,
    _ => Icons.circle,
  };
}
