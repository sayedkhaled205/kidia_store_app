import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                itemBuilder: (BuildContext context, int index) {
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
  const _HeroSlideCard({required this.slide, required this.onAction});

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
              child: Text(
                block.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double spacing = 4;
                final double itemWidth =
                    (constraints.maxWidth - ((columns - 1) * spacing)) /
                    columns;
                final double imageSize = (itemWidth - 12).clamp(54, 86);

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
                  itemBuilder: (BuildContext context, int index) {
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
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(width: 12);
              },
              itemBuilder: (BuildContext context, int index) {
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
            child: GridView.builder(
              itemCount: block.items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 1.15 : 0.59,
              ),
              itemBuilder: (BuildContext context, int index) {
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
          SizedBox(
            height: 116,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: block.items.length,
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(width: 12);
              },
              itemBuilder: (BuildContext context, int index) {
                final BrandItem item = block.items[index];
                final HomeAction? action = item.action;

                return SizedBox(
                  width: block.itemWidth,
                  child: Semantics(
                    button: action != null,
                    label: item.name,
                    child: Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
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
          ),
        ],
      ),
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
  const CouponBannerBlockWidget({required this.block, super.key});

  final CouponBannerBlock block;

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
    final Color foregroundColor = hasImage
        ? Colors.white
        : colorScheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Semantics(
        container: true,
        label: block.title ?? 'كوبون خصم',
        child: Material(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
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
  const CountdownBlockWidget({required this.block, super.key});

  final CountdownBlock block;

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

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              if (widget.block.title != null) ...[
                Text(
                  widget.block.title!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CountdownUnit(value: days, label: 'يوم'),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: hours, label: 'ساعة'),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: minutes, label: 'دقيقة'),
                  const SizedBox(width: 8),
                  _CountdownUnit(value: seconds, label: 'ثانية'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String formattedValue = value.toString().padLeft(2, '0');

    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
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
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoBannerBlockWidget extends StatelessWidget {
  const VideoBannerBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final VideoBannerBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // TODO(kidia): replace this external play action with inline native
    // playback when the app adopts a maintained video player dependency.
    final HomeAction playAction =
        block.action ?? HomeAction(type: 'external', value: block.videoUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Semantics(
        button: true,
        label: 'تشغيل الفيديو',
        hint: 'يفتح الفيديو للمشاهدة',
        child: ExcludeSemantics(
          child: AspectRatio(
            aspectRatio: block.aspectRatio,
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  onAction(playAction);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (block.posterUrl != null)
                      AppNetworkImage(
                        imageUrl: block.posterUrl!,
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
                    const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x26000000)),
                    ),
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
                      fontWeight: FontWeight.w900,
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
