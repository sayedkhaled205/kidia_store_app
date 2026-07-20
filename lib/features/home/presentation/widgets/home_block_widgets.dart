import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_frame.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:kidia_store_app/shared/widgets/product/product_badge.dart';
import 'package:kidia_store_app/shared/widgets/product/product_card.dart';
import 'package:video_player/video_player.dart';

class AppHeaderBlockWidget extends StatelessWidget {
  const AppHeaderBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final AppHeaderBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final double responsive = HomeResponsiveScope.of(context);
    final Color titleColor = _parseHexColor(
      block.titleColor,
      fallback: Theme.of(context).colorScheme.onSurface,
    );
    final Color iconColor = _parseHexColor(
      block.iconColor,
      fallback: Theme.of(context).colorScheme.onSurface,
    );
    final Widget identity = block.logoUrl != null
        ? AppNetworkImage(
            imageUrl: block.logoUrl!,
            height: block.logoHeight * responsive,
            fit: BoxFit.contain,
            semanticLabel: block.title,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: block.layout == 'center'
                ? CrossAxisAlignment.center
                : block.layout == 'end'
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                block.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (block.subtitle != null)
                Text(
                  block.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: titleColor.withValues(alpha: 0.72),
                  ),
                ),
            ],
          );

    final Color iconBackground = _parseHexColor(
      block.iconBackground,
      fallback: Colors.transparent,
    );
    Widget actionButton({
      required String tooltip,
      required IconData icon,
      required VoidCallback onTap,
      double? size,
      String? label,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: iconBackground,
          borderRadius: BorderRadius.circular(block.iconRadius * responsive),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(block.iconRadius * responsive),
            child: Padding(
              padding: EdgeInsets.all(7 * responsive),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: (size ?? block.iconSize) * responsive, color: iconColor),
                  if (label != null && label.isNotEmpty)
                    Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: iconColor,
                        fontSize: 9 * responsive,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final List<Widget> actions = <Widget>[];
    void addAction(Widget action) {
      if (actions.isNotEmpty) {
        actions.add(SizedBox(width: block.iconGap * responsive));
      }
      actions.add(action);
    }
    if (block.showAccount) {
      addAction(
        actionButton(
          tooltip: 'حسابي',
          icon: block.accountStyle == 'filled'
              ? Icons.person_rounded
              : block.accountStyle == 'avatar'
              ? Icons.account_circle_rounded
              : Icons.person_outline_rounded,
          size: block.accountIconSize,
          label: block.showAccountLabel ? block.accountLabel : null,
          onTap: () => onAction(
            const HomeAction(type: 'account', value: 'account'),
          ),
        ),
      );
    }
    if (block.showWishlist) {
      addAction(
        actionButton(
          tooltip: 'المفضلة',
          icon: Icons.favorite_border_rounded,
          onTap: () => onAction(
            const HomeAction(type: 'wishlist', value: 'wishlist'),
          ),
        ),
      );
    }
    if (block.showSearch && block.searchStyle == 'icon') {
      addAction(
        actionButton(
          tooltip: 'البحث',
          icon: Icons.search_rounded,
          onTap: () => onAction(
            const HomeAction(type: 'search', value: ''),
          ),
        ),
      );
    }
    if (block.showCart) {
      addAction(
        actionButton(
          tooltip: 'السلة',
          icon: Icons.shopping_bag_outlined,
          onTap: () => onAction(
            const HomeAction(type: 'cart', value: 'cart'),
          ),
        ),
      );
    }

    final Widget topRow = block.layout == 'center'
        ? Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 112 * responsive),
                child: identity,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: block.layout == 'end'
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: <Widget>[
              Expanded(child: identity),
              ...actions,
            ],
          );
    final Color backgroundColor = _parseHexColor(
      block.backgroundColor,
      fallback: Theme.of(context).colorScheme.surface,
    );
    final double configuredHeight = block.height * responsive;
    final double effectiveHeight = block.showSearch && block.searchStyle == 'bar'
        ? configuredHeight < 96 * responsive
              ? 96 * responsive
              : configuredHeight
        : configuredHeight;

    final List<BoxShadow> shadows = block.shadow == 'none'
        ? const <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: block.shadow == 'strong' ? 0.18 : 0.08,
              ),
              blurRadius: block.shadow == 'strong' ? 14 : 7,
              offset: const Offset(0, 3),
            ),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(block.borderRadius * responsive),
        boxShadow: shadows,
      ),
      child: SizedBox(
        key: Key('app-header-${block.id}'),
        height: effectiveHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: block.horizontalPadding * responsive,
          ),
          child: Column(
            children: <Widget>[
              Expanded(child: topRow),
              if (block.showSearch && block.searchStyle == 'bar')
                Padding(
                  padding: EdgeInsets.only(bottom: 10 * responsive),
                  child: Material(
                    color: _parseHexColor(block.searchBackground, fallback: Theme.of(context).colorScheme.surfaceContainerHighest),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(block.searchRadius * responsive),
                      side: BorderSide(
                        color: _parseHexColor(block.searchBorderColor, fallback: Colors.transparent),
                        width: block.searchBorderWidth * responsive,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(block.searchRadius * responsive),
                      onTap: () => onAction(
                        const HomeAction(type: 'search', value: ''),
                      ),
                      child: SizedBox(
                        height: block.searchHeight * responsive,
                        child: Row(
                          children: <Widget>[
                            SizedBox(width: 12 * responsive),
                            Icon(
                              Icons.search_rounded,
                              size: 21 * responsive,
                              color: _parseHexColor(block.searchIconColor, fallback: iconColor),
                            ),
                            SizedBox(width: 8 * responsive),
                            Expanded(
                              child: Text(
                                block.searchPlaceholder,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _parseHexColor(
                                        block.searchTextColor,
                                        fallback: iconColor,
                                      ),
                                    ),
                              ),
                            ),
                            if (block.showVoiceSearch)
                              Icon(
                                Icons.mic_none_rounded,
                                size: 20 * responsive,
                                color: _parseHexColor(block.searchIconColor, fallback: iconColor),
                              ),
                            if (block.showVoiceSearch)
                              SizedBox(width: 10 * responsive),
                          ],
                        ),
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
        if (!mounted || !_pageController.hasClients) {
          return;
        }

        final int nextPage = (_currentPage + 1) % widget.block.items.length;

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
      padding: EdgeInsets.fromLTRB(
        widget.block.horizontalPadding,
        12,
        widget.block.horizontalPadding,
        8,
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: widget.block.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.block.borderRadius),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.block.items.length,
                    onPageChanged: (int page) {
                      if (_currentPage == page) return;
                      setState(() => _currentPage = page);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final HeroSlide slide = widget.block.items[index];
                      return _HeroSlideCard(
                        slide: slide,
                        block: widget.block,
                        onAction: widget.onAction,
                      );
                    },
                  ),
                  if (widget.block.showIndicators &&
                      widget.block.items.length > 1 &&
                      widget.block.indicatorPosition == 'image_bottom')
                    Positioned(
                      right: 0,
                      bottom: 12,
                      left: 0,
                      child: _indicators(colorScheme, insideImage: true),
                    ),
                ],
              ),
            ),
          ),
          if (widget.block.showIndicators &&
              widget.block.items.length > 1 &&
              widget.block.indicatorPosition == 'below') ...[
            const SizedBox(height: 10),
            _indicators(colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _indicators(ColorScheme colors, {bool insideImage = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List<Widget>.generate(widget.block.items.length, (int index) {
      final bool selected = index == _currentPage;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: selected && widget.block.indicatorStyle == 'pill' ? 22 : 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: selected
              ? (insideImage ? Colors.white : colors.primary)
              : (insideImage
                    ? Colors.white.withValues(alpha: 0.55)
                    : colors.outlineVariant),
          borderRadius: BorderRadius.circular(999),
          boxShadow: insideImage
              ? const <BoxShadow>[
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ]
              : null,
        ),
      );
    }),
  );
}

class _HeroSlideCard extends StatelessWidget {
  const _HeroSlideCard({
    required this.slide,
    required this.block,
    required this.onAction,
  });

  final HeroSlide slide;
  final HeroSliderBlock block;
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
                fit: block.imageFit == 'contain' ? BoxFit.contain : BoxFit.cover,
                semanticLabel: slide.title ?? slide.subtitle,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: block.overlayPosition == 'end'
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    end: block.overlayPosition == 'end'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    colors: <Color>[
                      Colors.black.withValues(
                        alpha: block.overlayStrength / 100,
                      ),
                      Colors.black.withValues(
                        alpha: block.overlayStrength / 220,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              if (slide.title != null ||
                  slide.subtitle != null ||
                  slide.buttonLabel != null)
                Align(
                  alignment: switch (block.overlayPosition) {
                    'center' => Alignment.center,
                    'end' => Alignment.centerLeft,
                    _ => Alignment.centerRight,
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 255),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: block.overlayPosition == 'center'
                            ? CrossAxisAlignment.center
                            : block.overlayPosition == 'end'
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (slide.title != null)
                            Text(
                              slide.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: _parseHexColor(
                                      block.textColor,
                                      fallback: Colors.white,
                                    ),
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
                                    color: _parseHexColor(
                                      block.textColor,
                                      fallback: const Color(0xFFF3F3F3),
                                    ).withValues(alpha: 0.92),
                                    height: 1.4,
                                  ),
                            ),
                          ],
                          if (slide.buttonLabel != null) ...<Widget>[
                            const SizedBox(height: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: _parseHexColor(
                                  block.textColor,
                                  fallback: Colors.white,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 8,
                                ),
                                child: Text(
                                  slide.buttonLabel!,
                                  style: const TextStyle(
                                    color: Color(0xFF1F2933),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
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
    final bool compact = block.layout == 'compact';
    final bool cards = block.layout == 'cards';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
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
          if (block.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                block.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          if (block.layout == 'carousel')
            SizedBox(
              height: block.imageSize + (block.showNames ? 48 : 8),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: block.items.length,
                separatorBuilder: (_, _) => SizedBox(width: block.gap),
                itemBuilder: (BuildContext context, int index) {
                  return SizedBox(
                    width: block.imageSize + 12,
                    child: _CategoryBlockCard(
                      item: block.items[index],
                      block: block,
                      imageSize: block.imageSize,
                      onAction: onAction,
                    ),
                  );
                },
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double itemWidth =
					  (constraints.maxWidth - ((columns - 1) * (compact ? block.gap / 2 : block.gap))) /
                      columns;
                  final double imageSize = block.imageSize < itemWidth - 8
                      ? block.imageSize
                      : itemWidth - 8;
                  return GridView.builder(
                    itemCount: block.items.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
					  crossAxisSpacing: compact ? block.gap / 2 : block.gap,
					  mainAxisSpacing: compact ? block.gap / 2 : block.gap,
					  mainAxisExtent: imageSize + (block.showNames ? (compact ? 36 : 45) : 4),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      return _CategoryBlockCard(
                        item: block.items[index],
                        block: block,
						imageSize: compact ? imageSize * .82 : imageSize,
						forceRounded: cards,
                        onAction: onAction,
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBlockCard extends StatelessWidget {
  const _CategoryBlockCard({
    required this.item,
    required this.block,
    required this.imageSize,
    required this.onAction,
    this.forceRounded = false,
  });

  final CategoryItem item;
  final CategoryGridBlock block;
  final double imageSize;
  final ValueChanged<HomeAction> onAction;
  final bool forceRounded;

  @override
  Widget build(BuildContext context) {
	final BorderRadius radius = forceRounded ? BorderRadius.circular(18) : switch (block.imageShape) {
      'circle' => BorderRadius.circular(imageSize / 2),
      'square' => BorderRadius.zero,
      _ => BorderRadius.circular(18),
    };
    return InkWell(
      borderRadius: radius,
      onTap: item.action == null ? null : () => onAction(item.action!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: radius,
            child: AppNetworkImage(
              imageUrl: item.imageUrl,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.cover,
              semanticLabel: item.name,
            ),
          ),
          if (block.showNames) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _parseHexColor(
                  block.labelColor,
                  fallback: Theme.of(context).colorScheme.onSurface,
                ),
                fontSize: block.labelSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class QuickLinksBlockWidget extends StatelessWidget {
  const QuickLinksBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final QuickLinksBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final double responsive = HomeResponsiveScope.of(context);
    final double itemSize = block.itemSize * responsive;
    final double gap = block.gap * responsive;
    final Widget content = block.layout == 'grid'
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double availableItemWidth =
                    (constraints.maxWidth -
                        ((block.columns - 1) * gap)) /
                    block.columns;
                final double gridItemSize = availableItemWidth < 1
                    ? 1
                    : availableItemWidth < itemSize
                    ? availableItemWidth
                    : itemSize;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: block.items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: block.columns,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    mainAxisExtent:
                        gridItemSize + (block.showLabels ? 48 : 4),
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return _QuickLinkCard(
                      item: block.items[index],
                      block: block,
                      itemSize: gridItemSize,
                      onAction: onAction,
                    );
                  },
                );
              },
            ),
          )
        : SizedBox(
            height: itemSize + (block.showLabels ? 54 : 8),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: block.items.length,
              separatorBuilder: (_, _) => SizedBox(width: gap),
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                  width: itemSize + 12,
                  child: _QuickLinkCard(
                    item: block.items[index],
                    block: block,
                    itemSize: itemSize,
                    onAction: onAction,
                  ),
                );
              },
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (block.title != null)
            HomeBlockTitle(
              title: block.title!,
              showAction: false,
              actionLabel: '',
              onPressed: null,
            ),
          if (block.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                block.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          content,
        ],
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard({
    required this.item,
    required this.block,
    required this.itemSize,
    required this.onAction,
  });

  final QuickLinkItem item;
  final QuickLinksBlock block;
  final double itemSize;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = switch (block.imageShape) {
      'circle' => BorderRadius.circular(itemSize / 2),
      'square' => BorderRadius.zero,
      _ => BorderRadius.circular(18),
    };
    final Color labelColor = _parseHexColor(
      block.labelColor,
      fallback: Theme.of(context).colorScheme.onSurface,
    );
    return Semantics(
      button: item.action != null,
      label: item.label,
      child: InkWell(
        borderRadius: radius,
        onTap: item.action == null ? null : () => onAction(item.action!),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: AppNetworkImage(
                  imageUrl: item.imageUrl,
                  width: itemSize,
                  height: itemSize,
                  fit: BoxFit.cover,
                  semanticLabel: item.label,
                ),
              ),
            ),
            if (block.showLabels) ...<Widget>[
              const SizedBox(height: 7),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: labelColor,
                  fontSize: block.labelSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.subtitle != null)
                Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class BannerGridBlockWidget extends StatelessWidget {
  const BannerGridBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final BannerGridBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (block.layout) {
      'featured' => _buildFeatured(),
      'mosaic' => _buildMosaic(),
      _ => _buildEqualGrid(),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (block.title != null)
            HomeBlockTitle(
              title: block.title!,
              showAction: false,
              actionLabel: '',
              onPressed: null,
            ),
          if (block.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(block.subtitle!),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildEqualGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: block.items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: block.columns,
        crossAxisSpacing: block.gap,
        mainAxisSpacing: block.gap,
        childAspectRatio: block.aspectRatio,
      ),
      itemBuilder: (_, int index) => _tile(block.items[index]),
    );
  }

  Widget _buildFeatured() {
    if (block.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: block.aspectRatio * 2,
          child: _tile(block.items.first),
        ),
        if (block.items.length > 1) ...<Widget>[
          SizedBox(height: block.gap),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: block.items.length - 1,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: block.columns,
              crossAxisSpacing: block.gap,
              mainAxisSpacing: block.gap,
              childAspectRatio: block.aspectRatio,
            ),
            itemBuilder: (_, int index) => _tile(block.items[index + 1]),
          ),
        ],
      ],
    );
  }

  Widget _buildMosaic() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double halfWidth = (constraints.maxWidth - block.gap) / 2;
        return Wrap(
          spacing: block.gap,
          runSpacing: block.gap,
          children: List<Widget>.generate(block.items.length, (int index) {
            final bool wide = index % 3 == 0;
            return SizedBox(
              width: wide ? constraints.maxWidth : halfWidth,
              child: AspectRatio(
                aspectRatio: wide
                    ? block.aspectRatio * 2
                    : block.aspectRatio,
                child: _tile(block.items[index]),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _tile(BannerGridItem item) {
    return _BannerGridTile(
      item: item,
      block: block,
      onAction: onAction,
    );
  }
}

class _BannerGridTile extends StatelessWidget {
  const _BannerGridTile({
    required this.item,
    required this.block,
    required this.onAction,
  });

  final BannerGridItem item;
  final BannerGridBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final Color textColor = _parseHexColor(
      block.textColor,
      fallback: Colors.white,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(block.borderRadius),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: item.action == null ? null : () => onAction(item.action!),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AppNetworkImage(
                imageUrl: item.imageUrl,
                fit: block.imageFit == 'contain' ? BoxFit.contain : BoxFit.cover,
                semanticLabel: item.title ?? item.subtitle,
              ),
              if (item.title != null ||
                  item.subtitle != null ||
                  item.buttonLabel != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: block.overlayStrength / 100,
                        ),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (item.title != null)
                            Text(
                              item.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          if (item.subtitle != null)
                            Text(
                              item.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textColor),
                            ),
                          if (item.buttonLabel != null) ...<Widget>[
                            const SizedBox(height: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: textColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Text(
                                  item.buttonLabel!,
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.82),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
    final Color textColor = _parseHexColor(
      block.textColor,
      fallback: Colors.white,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(block.borderRadius),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: action == null ? null : () => onAction(action),
            child: AspectRatio(
              aspectRatio: block.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  AppNetworkImage(
                    imageUrl: block.imageUrl,
                    fit: block.imageFit == 'contain'
                        ? BoxFit.contain
                        : BoxFit.cover,
                    semanticLabel: block.semanticLabel,
                  ),
                  if (block.title != null ||
                      block.subtitle != null ||
                      block.buttonLabel != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Colors.black.withValues(
                              alpha: block.overlayStrength / 100,
                            ),
                          ],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (block.title != null)
                                Text(
                                  block.title!,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              if (block.subtitle != null)
                                Text(
                                  block.subtitle!,
                                  style: TextStyle(color: textColor),
                                ),
                              if (block.buttonLabel != null) ...<Widget>[
                                const SizedBox(height: 10),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: textColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    child: Text(
                                      block.buttonLabel!,
                                      style: const TextStyle(
                                        color: Color(0xFF1F2933),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
        ),
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
              actionLabel: block.viewAllLabel ?? 'عرض الكل',
              onPressed: block.viewAllAction == null
                  ? null
                  : () {
                      onAction(block.viewAllAction!);
                    },
            ),
          if (block.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                block.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          SizedBox(
            height:
                (block.itemWidth / block.imageRatio) +
                (block.showName || block.showPrice || block.showRating
                    ? 126
                    : 8),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: block.items.length,
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(width: 12);
              },
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                  width: block.itemWidth,
                  child: _HomeProductCardAdapter(
                    product: block.items[index],
                    onAction: onAction,
                    compact: true,
                    cardStyle: block.cardStyle,
                    imageRatio: block.imageRatio,
                    cardRadius: block.cardRadius,
                    showName: block.showName,
                    showPrice: block.showPrice,
                    showRegularPrice: block.showRegularPrice,
                    showBadge: block.showBadge,
                    showRating: block.showRating,
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
              actionLabel: block.viewAllLabel ?? 'عرض الكل',
              onPressed: block.viewAllAction == null
                  ? null
                  : () {
                      onAction(block.viewAllAction!);
                    },
            ),
          if (block.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                block.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double spacing = 12;
                final double itemWidth =
                    (constraints.maxWidth - ((columns - 1) * spacing)) /
                    columns;
                final bool showsInformation =
                    block.showName || block.showPrice || block.showRating;
                final double itemHeight =
                    (itemWidth / block.imageRatio) +
                    (showsInformation ? 126 : 0);

                return GridView.builder(
                  itemCount: block.items.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: itemHeight,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return _HomeProductCardAdapter(
                      product: block.items[index],
                      onAction: onAction,
                      cardStyle: block.cardStyle,
                      imageRatio: block.imageRatio,
                      cardRadius: block.cardRadius,
                      showName: block.showName,
                      showPrice: block.showPrice,
                      showRegularPrice: block.showRegularPrice,
                      showBadge: block.showBadge,
                      showRating: block.showRating,
                    );
                  },
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
          if (block.actionLabel != null && block.action != null)
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
          if (block.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(block.subtitle!),
            ),
          if (block.layout == 'grid')
            Padding(
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
                itemBuilder: (_, int index) => _BrandTile(
                  item: block.items[index],
                  block: block,
                  onAction: onAction,
                ),
              ),
            )
          else
            SizedBox(
              height: block.itemWidth + (block.showNames ? 42 : 16),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: block.items.length,
                separatorBuilder: (_, _) => SizedBox(width: block.gap),
                itemBuilder: (BuildContext context, int index) {
                  return SizedBox(
                    width: block.itemWidth,
                    child: _BrandTile(
                      item: block.items[index],
                      block: block,
                      onAction: onAction,
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

class _BrandTile extends StatelessWidget {
  const _BrandTile({
    required this.item,
    required this.block,
    required this.onAction,
  });

  final BrandItem item;
  final BrandCarouselBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = switch (block.imageShape) {
      'circle' => BorderRadius.circular(999),
      'square' => BorderRadius.zero,
      _ => BorderRadius.circular(18),
    };
    return Column(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: item.action != null,
            label: item.name,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: item.action == null
                    ? null
                    : () => onAction(item.action!),
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
        ),
        if (block.showNames) ...<Widget>[
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
    );
  }
}

class PromoStripBlockWidget extends StatelessWidget {
  const PromoStripBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final PromoStripBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final HomeAction? action = block.action;
    final Color backgroundColor = _parseHexColor(
      block.backgroundColor,
      fallback: Theme.of(context).colorScheme.primary,
    );
    final Color textColor = _parseHexColor(
      block.textColor,
      fallback: Theme.of(context).colorScheme.onPrimary,
    );

    return Semantics(
      button: action != null,
      label: block.text,
      child: ExcludeSemantics(
        child: Material(
          color: backgroundColor,
          child: InkWell(
            onTap: action == null
                ? null
                : () {
                    onAction(action);
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  block.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CouponBannerBlockWidget extends StatelessWidget {
  const CouponBannerBlockWidget({
    required this.block,
    this.onAction,
    super.key,
  });

  final CouponBannerBlock block;
  final ValueChanged<HomeAction>? onAction;

  @override
  Widget build(BuildContext context) {
    if (block.title == null &&
        block.description == null &&
        block.couponCode == null &&
        block.imageUrl == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool hasImage = block.imageUrl != null;
    final Color foregroundColor = _parseHexColor(
      block.textColor,
      fallback: hasImage ? Colors.white : colorScheme.onSecondaryContainer,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Semantics(
        container: true,
        label: block.title ?? 'كوبون خصم',
        child: Material(
          color: _parseHexColor(
            block.backgroundColor,
            fallback: colorScheme.secondaryContainer,
          ),
          borderRadius: BorderRadius.circular(block.borderRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: block.action == null || onAction == null
                ? null
                : () => onAction!(block.action!),
            child: Stack(
            children: [
              if (hasImage) ...[
                Positioned.fill(
                  child: AppNetworkImage(
                    imageUrl: block.imageUrl!,
                    fit: BoxFit.cover,
                    semanticLabel: block.title,
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0xD9000000), Color(0x8A000000)],
                      ),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (block.title != null)
                      Text(
                        block.title!,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (block.description != null) ...[
                      if (block.title != null) const SizedBox(height: 6),
                      Text(
                        block.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foregroundColor,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (block.couponCode != null) ...[
                      if (block.title != null || block.description != null)
                        const SizedBox(height: 14),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Semantics(
                          button: true,
                          label: 'نسخ كود الخصم ${block.couponCode}',
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              await _copyCouponCode(context, block.couponCode!);
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: Text(block.couponCode!),
                            style: FilledButton.styleFrom(
                              backgroundColor: _parseHexColor(
                                block.accentColor,
                                fallback: colorScheme.primary,
                              ),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyCouponCode(BuildContext context, String couponCode) async {
    await Clipboard.setData(ClipboardData(text: couponCode));

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('تم نسخ كود الخصم')));
  }
}

class CountdownBlockWidget extends StatefulWidget {
  const CountdownBlockWidget({
    required this.block,
    this.onAction,
    super.key,
  });

  final CountdownBlock block;
  final ValueChanged<HomeAction>? onAction;

  @override
  State<CountdownBlockWidget> createState() {
    return _CountdownBlockWidgetState();
  }
}

class _CountdownBlockWidgetState extends State<CountdownBlockWidget> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _configureTimer();
  }

  @override
  void didUpdateWidget(covariant CountdownBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.block.endsAt != widget.block.endsAt) {
      _configureTimer();
    }
  }

  void _configureTimer() {
    _timer?.cancel();
    _remaining = _calculateRemaining();

    if (_remaining == Duration.zero) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final Duration nextRemaining = _calculateRemaining();

      if (nextRemaining == _remaining) {
        return;
      }

      setState(() {
        _remaining = nextRemaining;
      });

      if (nextRemaining == Duration.zero) {
        timer.cancel();
      }
    });
  }

  Duration _calculateRemaining() {
    final DateTime? endsAt = widget.block.endsAt;

    if (endsAt == null) {
      return Duration.zero;
    }

    final Duration difference = endsAt.difference(DateTime.now().toUtc());

    return difference.isNegative ? Duration.zero : difference;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool expired = _remaining == Duration.zero;

    if (expired) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Semantics(
          liveRegion: true,
          label: widget.block.expiredText,
          child: Text(
            widget.block.expiredText,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final int days = _remaining.inDays;
    final int hours = _remaining.inHours.remainder(24);
    final int minutes = _remaining.inMinutes.remainder(60);
    final int seconds = _remaining.inSeconds.remainder(60);
    final String semanticsLabel = [
      if (widget.block.title != null) widget.block.title!,
      '$days يوم',
      '$hours ساعة',
      '$minutes دقيقة',
      '$seconds ثانية',
    ].join('، ');

    final Color textColor = _parseHexColor(
      widget.block.textColor,
      fallback: colorScheme.onSurface,
    );
    final Color boxColor = _parseHexColor(
      widget.block.boxColor,
      fallback: colorScheme.surfaceContainerHigh,
    );

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Material(
          color: _parseHexColor(
            widget.block.backgroundColor,
            fallback: colorScheme.surface,
          ),
          child: InkWell(
            onTap: widget.block.action == null || widget.onAction == null
                ? null
                : () => widget.onAction!(widget.block.action!),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
            children: [
              if (widget.block.title != null) ...[
                Text(
                  widget.block.title!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CountdownUnit(value: days, label: 'يوم', boxColor: boxColor, textColor: textColor),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: hours, label: 'ساعة', boxColor: boxColor, textColor: textColor),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: minutes, label: 'دقيقة', boxColor: boxColor, textColor: textColor),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: seconds, label: 'ثانية', boxColor: boxColor, textColor: textColor),
                ],
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

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({
    required this.value,
    required this.label,
    required this.boxColor,
    required this.textColor,
  });

  final int value;
  final String label;
  final Color boxColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String formattedValue = value.toString().padLeft(2, '0');

    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedValue,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoBannerBlockWidget extends StatefulWidget {
  const VideoBannerBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final VideoBannerBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  State<VideoBannerBlockWidget> createState() =>
      _VideoBannerBlockWidgetState();
}

class _VideoBannerBlockWidgetState extends State<VideoBannerBlockWidget> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _configureController();
  }

  @override
  void didUpdateWidget(covariant VideoBannerBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.videoUrl != widget.block.videoUrl) {
      _configureController();
      return;
    }
    if (oldWidget.block.loop != widget.block.loop ||
        oldWidget.block.muted != widget.block.muted) {
      _applyPlaybackSettings();
    }
  }

  Future<void> _configureController() async {
    final VideoPlayerController? oldController = _controller;
    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.block.videoUrl),
    );
    _controller = controller;
    _failed = false;
    await oldController?.dispose();
    try {
      await controller.initialize();
      await _applyPlaybackSettings();
      if (widget.block.autoPlay) {
        await controller.play();
      }
      if (mounted && identical(_controller, controller)) {
        setState(() {});
      }
    } catch (_) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _failed = true);
      }
    }
  }

  Future<void> _applyPlaybackSettings() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.setLooping(widget.block.loop);
    await controller.setVolume(widget.block.muted ? 0 : 1);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final VideoPlayerController? controller = _controller;
    final bool ready = !_failed &&
        controller != null &&
        controller.value.isInitialized;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Semantics(
        button: true,
        label: 'فيديو ترويجي',
        hint: 'اضغط للتشغيل أو الإيقاف',
        child: ExcludeSemantics(
          child: AspectRatio(
            aspectRatio: widget.block.aspectRatio,
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _togglePlayback,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.block.posterUrl != null)
                      AppNetworkImage(
                        imageUrl: widget.block.posterUrl!,
                        fit: BoxFit.cover,
                        semanticLabel: 'صورة معاينة الفيديو',
                      )
                    else
                      ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 56,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (ready) VideoPlayer(controller),
                    if (!ready || !controller.value.isPlaying)
                      const DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x26000000)),
                      ),
                    if (!ready || !controller.value.isPlaying)
                      Center(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xE6FFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 36,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    if (widget.block.action != null)
                      PositionedDirectional(
                        end: 10,
                        bottom: 10,
                        child: FilledButton.tonalIcon(
                          onPressed: () =>
                              widget.onAction(widget.block.action!),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('عرض التفاصيل'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TextBlockWidget extends StatelessWidget {
  const TextBlockWidget({required this.block, super.key});

  final TextBlock block;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextAlign textAlign = switch (block.alignment) {
      HomeTextAlignment.left => TextAlign.left,
      HomeTextAlignment.center => TextAlign.center,
      HomeTextAlignment.right => TextAlign.right,
    };
    final Color textColor = _parseHexColor(
      block.textColor,
      fallback: theme.colorScheme.onSurface,
    );
    final Color backgroundColor = _parseHexColor(
      block.backgroundColor,
      fallback: Colors.transparent,
    );
    final FontWeight fontWeight = switch (block.fontWeight) {
      'bold' => FontWeight.w700,
      'medium' => FontWeight.w500,
      _ => FontWeight.w400,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (block.title != null)
                  Text(
                    block.title!,
                    textAlign: textAlign,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: textColor,
                      fontSize: block.titleSize,
                      fontWeight: fontWeight == FontWeight.w400
                          ? FontWeight.w900
                          : fontWeight,
                    ),
                  ),
                if (block.title != null && block.content != null)
                  const SizedBox(height: 8),
                if (block.content != null)
                  Text(
                    block.content!,
                    textAlign: textAlign,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontSize: block.contentSize,
                      fontWeight: fontWeight,
                      height: 1.6,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DividerBlockWidget extends StatelessWidget {
  const DividerBlockWidget({required this.block, super.key});

  final DividerBlock block;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: block.margin),
        child: SizedBox(
          height: block.thickness,
          child: ColoredBox(
            color: _parseHexColor(
              block.color,
              fallback: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}

Color _parseHexColor(String? value, {required Color fallback}) {
  if (value == null) {
    return fallback;
  }

  String normalized = value.trim().replaceFirst('#', '');

  if (normalized.length == 3) {
    normalized = normalized
        .split('')
        .map((String character) => '$character$character')
        .join();
  }

  if (normalized.length == 6) {
    normalized = 'ff$normalized';
  }

  if (normalized.length != 8) {
    return fallback;
  }

  final int? colorValue = int.tryParse(normalized, radix: 16);

  return colorValue == null ? fallback : Color(colorValue);
}

class _HomeProductCardAdapter extends StatelessWidget {
  const _HomeProductCardAdapter({
    required this.product,
    required this.onAction,
    this.compact = false,
    this.cardStyle = 'outlined',
    this.imageRatio = 1,
    this.cardRadius = 20,
    this.showName = true,
    this.showPrice = true,
    this.showRegularPrice = true,
    this.showBadge = true,
    this.showRating = false,
  });

  final HomeProductItem product;
  final ValueChanged<HomeAction> onAction;
  final bool compact;
  final String cardStyle;
  final double imageRatio;
  final double cardRadius;
  final bool showName;
  final bool showPrice;
  final bool showRegularPrice;
  final bool showBadge;
  final bool showRating;

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
      cardRadius: cardRadius,
      showBorder: cardStyle == 'outlined',
      elevation: cardStyle == 'elevated' ? 3 : 0,
      showName: showName,
      showPrice: showPrice,
      showRegularPrice: showRegularPrice,
      showBadge: showBadge,
      showRating: showRating,
      rating: product.rating,
      reviewCount: product.reviewCount,
      quickAddProductId: product.id,
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
