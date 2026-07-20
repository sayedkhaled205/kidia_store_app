import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/product/application/product_detail_controller.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:kidia_store_app/shared/widgets/product/product_badge.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ProductWishlistToggleCallback =
    Future<bool> Function(CatalogProduct product);
typedef ProductWishlistStatusCallback = Future<bool> Function(int productId);

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    required this.productId,
    required this.repository,
    super.key,
    this.onAddToCart,
    this.onReviewsRequested,
    this.onRelatedProductsRequested,
    this.onShareRequested,
    this.onWishlistToggle,
    this.isWishlisted,
  });

  final int productId;
  final CatalogRepository repository;
  final ProductAddToCartCallback? onAddToCart;
  final ValueChanged<CatalogProduct>? onReviewsRequested;
  final ValueChanged<CatalogProduct>? onRelatedProductsRequested;
  final ValueChanged<CatalogProduct>? onShareRequested;
  final ProductWishlistToggleCallback? onWishlistToggle;
  final ProductWishlistStatusCallback? isWishlisted;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late ProductDetailController _controller;
  bool _isWishlisted = false;
  bool _isWishlistMutating = false;
	bool _footerHidden = false;

  @override
  void initState() {
    super.initState();
    _createController();
    _loadWishlistState();
  }

  @override
  void didUpdateWidget(ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        !identical(oldWidget.repository, widget.repository)) {
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _createController();
      _isWishlisted = false;
      _loadWishlistState();
    }
  }

  void _createController() {
    _controller = ProductDetailController(
      repository: widget.repository,
      productId: widget.productId,
    )..addListener(_onControllerChanged);
    _controller.load();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _ProductCopy copy = _ProductCopy.of(context);
    final CmsPageComponent footerSize =
        (ref.watch(cmsPageLayoutProvider('category')).value ??
                CmsPageLayout.fallback('category'))
            .footer;
    return CmsPageLayoutLoader(
      page: 'product',
      builder: (BuildContext context, CmsPageLayout layout) => CmsPageScaffold(
        layout: layout,
        defaultTitle: copy.description,
        actions: _buildCmsActions(context, copy),
        body: NotificationListener<ScrollUpdateNotification>(
		  onNotification: (ScrollUpdateNotification notification) {
			if (!layout.footer.boolean('hide_on_scroll', false) || notification.scrollDelta == null) return false;
			final bool hidden = notification.scrollDelta! > 0;
			if (hidden != _footerHidden) setState(() => _footerHidden = hidden);
			return false;
		  },
		  child: _buildBody(copy, layout),
		),
        bottomNavigationBar:
            layout.element('purchase_bar').enabled &&
				!(_footerHidden && layout.footer.boolean('hide_on_scroll', false)) &&
                _controller.status == ProductDetailStatus.success &&
                _controller.product != null
            ? _PurchaseBar(
                controller: _controller,
                footer: layout.footer,
                sizeReference: footerSize,
                hasCartConnection: widget.onAddToCart != null,
                copy: copy,
                onPressed: _handlePurchasePressed,
                onShare: () => _showShareSheet(_controller.product!),
                onLike: widget.onWishlistToggle == null || _isWishlistMutating ? null : () => _toggleWishlist(_controller.product!),
                isLiked: _isWishlisted,
              )
            : null,
      ),
    );
  }

  List<CmsPageHeaderAction> _buildCmsActions(BuildContext context, _ProductCopy copy) {
    final CatalogProduct? product = _controller.product;
    return <CmsPageHeaderAction>[
	  CmsPageHeaderAction(type: 'support', icon: Icons.headset_mic_outlined, tooltip: 'خدمة العملاء', onPressed: () => context.push('/support')),
      if (product != null)
        CmsPageHeaderAction(
          type: 'share',
          icon: Icons.ios_share_outlined,
          tooltip: copy.share,
          onPressed: () => _showShareSheet(product),
        ),
      if (product != null && widget.onWishlistToggle != null)
        CmsPageHeaderAction(
          key: const Key('product-wishlist-button'),
          type: 'wishlist',
          icon: _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: _isWishlisted ? Colors.red : null,
          tooltip: copy.save,
          onPressed: _isWishlistMutating ? () {} : () => _toggleWishlist(product),
        ),
      CmsPageHeaderAction(
        key: const Key('product-cart-button'),
        type: 'cart',
        icon: Icons.shopping_bag_outlined,
        tooltip: 'Cart',
        onPressed: () => context.push('/cart'),
      ),
    ];
  }

  Future<void> _showShareSheet(CatalogProduct product) async {
    widget.onShareRequested?.call(product);
    final Uri? link = product.permalink;
    if (link == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _ProductShareSheet(product: product),
    );
  }

  Widget _buildBody(_ProductCopy copy, CmsPageLayout layout) {
    switch (_controller.status) {
      case ProductDetailStatus.initial:
      case ProductDetailStatus.loading:
        return _ProductLoading(copy: copy);
      case ProductDetailStatus.empty:
        return _ProductEmpty(copy: copy);
      case ProductDetailStatus.failure:
        return _ProductFailure(
          message: _controller.loadError ?? copy.loadFailure,
          retryLabel: copy.retry,
          onRetry: _controller.load,
        );
      case ProductDetailStatus.success:
        final CatalogProduct? product = _controller.product;
        if (product == null) {
          return _ProductEmpty(copy: copy);
        }
        return _ProductContent(
          controller: _controller,
          product: product,
          copy: copy,
          pageLayout: layout,
          onReviewsRequested: widget.onReviewsRequested,
          onRelatedProductsRequested: widget.onRelatedProductsRequested,
        );
    }
  }

  Future<void> _handlePurchasePressed() async {
    final CatalogProduct? product = _controller.product;
    if (product == null) {
      return;
    }
    if (product.hasVariations && !_controller.canAddToCart) {
      _controller.clearAddError();
      final bool chooseComplete =
          await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (BuildContext context) => _ProductOptionsSheet(
              controller: _controller,
              copy: _ProductCopy.of(context),
            ),
          ) ??
          false;
      if (!mounted || !chooseComplete) {
        return;
      }
    }
    await _addToCart();
  }

  Future<void> _addToCart() async {
    await _controller.addToCart(widget.onAddToCart);
  }

  Future<void> _loadWishlistState() async {
    final ProductWishlistStatusCallback? lookup = widget.isWishlisted;
    if (lookup == null) {
      return;
    }
    try {
      final bool saved = await lookup(widget.productId);
      if (mounted) {
        setState(() => _isWishlisted = saved);
      }
    } catch (_) {
      // Wishlist availability must never block product browsing.
    }
  }

  Future<void> _toggleWishlist(CatalogProduct product) async {
    final ProductWishlistToggleCallback? toggle = widget.onWishlistToggle;
    if (toggle == null || _isWishlistMutating) {
      return;
    }
    final bool previous = _isWishlisted;
    setState(() {
      _isWishlistMutating = true;
      _isWishlisted = !previous;
    });
    try {
      final bool saved = await toggle(product);
      if (mounted) {
        setState(() => _isWishlisted = saved);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isWishlisted = previous);
      }
    } finally {
      if (mounted) {
        setState(() => _isWishlistMutating = false);
      }
    }
  }
}

class _ProductContent extends StatelessWidget {
  const _ProductContent({
    required this.controller,
    required this.product,
    required this.copy,
    required this.pageLayout,
    this.onReviewsRequested,
    this.onRelatedProductsRequested,
  });

  final ProductDetailController controller;
  final CatalogProduct product;
  final _ProductCopy copy;
  final CmsPageLayout pageLayout;
  final ValueChanged<CatalogProduct>? onReviewsRequested;
  final ValueChanged<CatalogProduct>? onRelatedProductsRequested;

  @override
  Widget build(BuildContext context) {
    final CatalogVariation? variation = controller.selectedVariation;
    final List<CatalogImage> images = _displayImages(
      product.images,
      controller.selectedImage,
    );
    final CatalogMoney money = controller.displayedPrice ?? product.prices;
    final bool inStock = variation?.isInStock ?? product.isInStock;

    return CustomScrollView(
      key: const Key('product-detail-scroll'),
      slivers: <Widget>[
        if (pageLayout.element('image_gallery').enabled)
          SliverToBoxAdapter(
            child: CmsElementFrame(
              component: pageLayout.element('image_gallery'),
              child: _ProductGallery(
                images: images,
                productName: product.name,
                settings: pageLayout.element('image_gallery'),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 12),
          sliver: SliverList.list(
            children: <Widget>[
              if (pageLayout.element('product_summary').enabled)
                CmsElementFrame(
                  component: pageLayout.element('product_summary'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (pageLayout.element('product_summary').boolean('show_badge', true) &&
                          (product.isOnSale || !inStock)) ...<Widget>[
                        _ProductBadges(product: product, variation: variation, copy: copy),
                        const SizedBox(height: 12),
                      ],
                      if (pageLayout.element('product_summary').boolean('show_name', true))
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (pageLayout.element('product_summary').boolean('show_sku', true) &&
                          product.sku.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          '${copy.sku}: ${product.sku}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (pageLayout.element('product_summary').boolean('show_price', true)) ...<Widget>[
                        const SizedBox(height: 14),
                        _MoneyPrice(
                          money: money,
                          showRegularPrice: pageLayout
                              .element('product_summary')
                              .boolean('show_regular_price', true),
                        ),
                      ],
                      if (pageLayout.element('product_summary').boolean('show_rating', true) &&
                          product.averageRating > 0) ...<Widget>[
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.star_rounded, size: 19),
                            const SizedBox(width: 4),
                            Text(
                              '${product.averageRating.toStringAsFixed(1)} ${copy.reviewCount(product.reviewCount)}',
                            ),
                          ],
                        ),
                      ],
                      if (pageLayout.element('product_summary').boolean('show_stock', true)) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          inStock ? copy.inStock : copy.outOfStock,
                          key: const Key('product-stock-status'),
                          style: TextStyle(
                            color: inStock
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (pageLayout.element('variations').enabled && controller.optionGroups.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                CmsElementFrame(
                  component: pageLayout.element('variations'),
                  child: Column(
                    children: <Widget>[
                      for (final ProductOptionGroup group in controller.optionGroups)
                        _ProductOptionPicker(
                          group: group,
                          controller: controller,
                          copy: copy,
                          settings: pageLayout.element('variations'),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (pageLayout.element('purchase_bar').enabled &&
                  pageLayout.element('purchase_bar').boolean('show_quantity', true))
                CmsElementFrame(
                  component: pageLayout.element('purchase_bar'),
                  child: _QuantitySelector(controller: controller, copy: copy),
                ),
              if (product.hasVariations &&
                  controller.selectionComplete &&
                  controller.selectedVariation == null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  copy.unavailableCombination,
                  key: const Key('variation-unavailable-message'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (product.brands.isNotEmpty) ...<Widget>[
                _BrandSection(product: product, copy: copy),
                const SizedBox(height: 12),
              ],
              if (pageLayout.element('description').enabled)
                CmsElementFrame(
                  component: pageLayout.element('description'),
                  child: _DetailsSection(
                    product: product,
                    copy: copy,
                    settings: pageLayout.element('description'),
                  ),
                ),
              const SizedBox(height: 18),
              if (pageLayout.element('reviews').enabled)
                CmsElementFrame(
                  component: pageLayout.element('reviews'),
                  child: OutlinedButton.icon(
                    key: const Key('product-reviews-button'),
                    onPressed: onReviewsRequested == null
                        ? null
                        : () => onReviewsRequested!(product),
                    icon: const Icon(Icons.star_outline_rounded),
                    label: Text(
                      '${product.averageRating.toStringAsFixed(1)} (${product.reviewCount})',
                    ),
                  ),
                ),
              if (pageLayout.element('reviews').enabled)
                const SizedBox(height: 18),
              if (pageLayout.element('related_products').enabled)
              CmsElementFrame(component: pageLayout.element('related_products'), child: OutlinedButton.icon(
                key: const Key('related-products-button'),
                onPressed: onRelatedProductsRequested == null
                    ? null
                    : () => onRelatedProductsRequested!(product),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(copy.relatedProducts),
              )),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  static List<CatalogImage> _displayImages(
    List<CatalogImage> productImages,
    CatalogImage? selectedImage,
  ) {
    final Map<String, CatalogImage> images = <String, CatalogImage>{};
    if (selectedImage != null) {
      images[selectedImage.source.toString()] = selectedImage;
    }
    for (final CatalogImage image in productImages) {
      images.putIfAbsent(image.source.toString(), () => image);
    }
    return List<CatalogImage>.unmodifiable(images.values);
  }
}

class _ProductGallery extends StatefulWidget {
  const _ProductGallery({
    required this.images,
    required this.productName,
    required this.settings,
  });

  final List<CatalogImage> images;
  final String productName;
  final CmsPageComponent settings;

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  int _page = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage());
  }

  int _initialPage() {
    if (widget.images.length <= 1) {
      return 0;
    }
    const int middle = 10000;
    return middle - (middle % widget.images.length);
  }

  @override
  void didUpdateWidget(_ProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.isNotEmpty &&
        widget.images.isNotEmpty &&
        oldWidget.images.first.source != widget.images.first.source) {
      _page = 0;
      _pageController.dispose();
      _pageController = PageController(initialPage: _initialPage());
    } else if (_page >= widget.images.length) {
      _page = 0;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: widget.settings.number('aspect_ratio', 1).clamp(0.6, 1.8),
        child: AppNetworkImageError(
          backgroundColor: colors.surfaceContainerLow,
          iconSize: 54,
        ),
      );
    }

    final double aspectRatio = widget.settings
        .number('aspect_ratio', 1)
        .clamp(0.6, 1.8);
    final BoxFit fit = widget.settings.string('fit', 'contain') == 'cover'
        ? BoxFit.cover
        : BoxFit.contain;
    final bool enableZoom = widget.settings.boolean('enable_zoom', true);
    final Widget pager = AspectRatio(
          aspectRatio: aspectRatio,
          child: PageView.builder(
            key: ValueKey<String>(widget.images.first.source.toString()),
            controller: _pageController,
            itemCount: widget.images.length == 1 ? 1 : null,
            onPageChanged: (int page) =>
                setState(() => _page = page % widget.images.length),
            itemBuilder: (BuildContext context, int index) {
              final int imageIndex = index % widget.images.length;
              final CatalogImage image = widget.images[imageIndex];
              final Widget imageWidget = AppNetworkImage(
                  key: Key('product-image-$imageIndex'),
                  imageUrl: image.source.toString(),
                  width: double.infinity,
                  height: double.infinity,
                  fit: fit,
                  backgroundColor: colors.surfaceContainerLow,
                  semanticLabel: image.alt.isEmpty
                      ? widget.productName
                      : image.alt,
                );
              return enableZoom
                  ? InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      clipBehavior: Clip.hardEdge,
                      child: imageWidget,
                    )
                  : imageWidget;
            },
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: <Widget>[
            pager,
        if (widget.images.length > 1 &&
            widget.settings.boolean('show_indicators', true))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  '${_page + 1} / ${widget.images.length}',
                  key: const Key('product-gallery-counter'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
        if (widget.images.length > 1 &&
            widget.settings.boolean('show_thumbnails', true))
          SizedBox(
            height: 62,
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) => InkWell(
                onTap: () {
                  final int current = _pageController.page?.round() ?? 0;
                  final int cycleStart = current - (current % widget.images.length);
                  _pageController.animateToPage(
                    cycleStart + index,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                },
                child: AppNetworkImage(
                  imageUrl: widget.images[index].source.toString(),
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductBadges extends StatelessWidget {
  const _ProductBadges({
    required this.product,
    required this.variation,
    required this.copy,
  });

  final CatalogProduct product;
  final CatalogVariation? variation;
  final _ProductCopy copy;

  @override
  Widget build(BuildContext context) {
    final bool inStock = variation?.isInStock ?? product.isInStock;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (product.isOnSale)
          ProductBadge(label: copy.sale, type: ProductBadgeType.offer),
        if (!inStock)
          ProductBadge(
            label: copy.outOfStock,
            type: ProductBadgeType.outOfStock,
          ),
      ],
    );
  }
}

class _MoneyPrice extends StatelessWidget {
  const _MoneyPrice({required this.money, this.showRegularPrice = true});

  final CatalogMoney money;
  final bool showRegularPrice;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String price = money.displayAmount(money.priceMinor);
    final String regular = money.displayAmount(money.regularPriceMinor);
    if (price.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: <Widget>[
        Text(
          price,
          key: const Key('product-current-price'),
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (showRegularPrice && money.isDiscounted && regular.isNotEmpty)
          Text(
            regular,
            key: const Key('product-regular-price'),
            style: textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

class _ProductOptionPicker extends StatelessWidget {
  const _ProductOptionPicker({
    required this.group,
    required this.controller,
    required this.copy,
    this.settings,
  });

  final ProductOptionGroup group;
  final ProductDetailController controller;
  final _ProductCopy copy;
  final CmsPageComponent? settings;

  @override
  Widget build(BuildContext context) {
    final String? selected = controller.selectedAttributes[group.key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${copy.choose} ${group.label}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (settings?.string('style', 'chips') == 'dropdown')
            DropdownButtonFormField<String>(
              value: selected,
              decoration: InputDecoration(labelText: group.label),
              items: group.values
                  .where(
                    (ProductOptionValue option) => controller.isOptionAvailable(
                      group.key,
                      option.value,
                    ),
                  )
                  .map(
                    (ProductOptionValue option) => DropdownMenuItem<String>(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) {
                if (value != null) controller.selectOption(group.key, value);
              },
            )
          else
          Wrap(
            spacing: 9,
            runSpacing: 6,
            children: group.values
                .map((ProductOptionValue option) {
                  final bool available = controller.isOptionAvailable(
                    group.key,
                    option.value,
                  );
                  return ChoiceChip(
                    key: Key('product-option-${group.key}-${option.value}'),
                    label: Text(option.label),
                    selected: selected == option.value,
                    onSelected: available
                        ? (_) =>
                              controller.selectOption(group.key, option.value)
                        : null,
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ProductOptionsSheet extends StatelessWidget {
  const _ProductOptionsSheet({
    required this.controller,
    required this.copy,
  });

  final ProductDetailController controller;
  final _ProductCopy copy;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final bool invalidSelection =
            controller.selectionComplete &&
            controller.selectedVariation == null;
        return Padding(
          key: const Key('product-options-sheet'),
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        copy.chooseOptionsTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('product-options-sheet-close'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final ProductOptionGroup group in controller.optionGroups)
                  _ProductOptionPicker(
                    group: group,
                    controller: controller,
                    copy: copy,
                  ),
                if (invalidSelection) ...<Widget>[
                  Text(
                    copy.unavailableCombination,
                    key: const Key('product-options-sheet-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  key: const Key('product-options-sheet-add'),
                  onPressed: controller.canAddToCart
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(copy.addToCart),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({required this.controller, required this.copy});

  final ProductDetailController controller;
  final _ProductCopy copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            copy.quantity,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  key: const Key('quantity-decrement'),
                  tooltip: copy.decreaseQuantity,
                  onPressed: controller.quantity > 1
                      ? controller.decrementQuantity
                      : null,
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${controller.quantity}',
                    key: const Key('product-quantity'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  key: const Key('quantity-increment'),
                  tooltip: copy.increaseQuantity,
                  onPressed: controller.quantity < 99
                      ? controller.incrementQuantity
                      : null,
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.product,
    required this.copy,
    required this.settings,
  });

  final CatalogProduct product;
  final _ProductCopy copy;
  final CmsPageComponent settings;

  @override
  Widget build(BuildContext context) {
    final String description = _plainText(product.description);
    final bool showDescription = settings.boolean('show_description', true);
    final bool showAttributes = settings.boolean('show_attributes', true);
    if ((!showDescription || description.isEmpty) &&
        (!showAttributes || product.attributes.isEmpty)) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      key: const Key('product-description-section'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      initiallyExpanded: true,
      title: Text(
        copy.description,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      children: <Widget>[
        if (showDescription && description.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(description, style: const TextStyle(height: 1.6)),
          ),
        if (showAttributes && product.attributes.isNotEmpty) ...<Widget>[
          if (showDescription && description.isNotEmpty)
            const Divider(height: 24),
          for (final CatalogProductAttribute attribute in product.attributes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(attribute.name)),
                  Flexible(
                    child: Text(
                      attribute.terms
                          .map((CatalogAttributeTerm term) => term.name)
                          .join('، '),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _BrandSection extends StatelessWidget {
  const _BrandSection({required this.product, required this.copy});

  final CatalogProduct product;
  final _ProductCopy copy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('product-brand-section'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            Text(
              '${copy.brand}:',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                product.brands.map((brand) => brand.name).join('، '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({
    required this.controller,
    required this.footer,
    required this.sizeReference,
    required this.hasCartConnection,
    required this.copy,
    required this.onPressed,
    required this.onShare,
    required this.onLike,
    required this.isLiked,
  });

  final ProductDetailController controller;
  final CmsPageComponent footer;
  final CmsPageComponent sizeReference;
  final bool hasCartConnection;
  final _ProductCopy copy;
  final VoidCallback onPressed;
  final VoidCallback? onShare;
  final VoidCallback? onLike;
  final bool isLiked;

  @override
  Widget build(BuildContext context) {
    final CatalogProduct product = controller.product!;
    String? reason;
    if (!hasCartConnection) {
      reason = copy.cartNotConnected;
    } else if (!product.hasVariations && !product.isInStock) {
      reason = copy.outOfStock;
    } else if (!product.hasVariations && !product.isPurchasable) {
      reason = copy.notPurchasable;
    }

    if (!footer.enabled) { return const SizedBox.shrink(); }
    final Color background = _cmsColor(footer.string('background_color', '#FFFFFF'), Theme.of(context).colorScheme.surface);
    final Color buttonColor = _cmsColor(footer.string('button_color', '#1F2933'), Theme.of(context).colorScheme.primary);
    final Color buttonText = _cmsColor(footer.string('button_text_color', '#FFFFFF'), Colors.white);
    final Color buttonBorderColor = _cmsColor(
      footer.string('button_border_color', '#1F2933'),
      buttonColor,
    );
    final double configuredFooterHeight = sizeReference
        .number('height', 64)
        .clamp(48, 100);
    final double footerIconSize = sizeReference
        .number('icon_size', 24)
        .clamp(14, 40);
    final double footerIconBoxSize = (footerIconSize + 8).clamp(32, 48).toDouble();
    final double footerLabelSize = sizeReference.number('label_size', 11).clamp(8, 20).toDouble();
    final double footerIconLabelGap = footer.number('icon_label_gap', 3).clamp(0, 12).toDouble();
	final Map<String, dynamic> footerLayout = footer.json('layout_json');
	final dynamic rawRows = footerLayout['rows'];
	final List<(String, double)> placements = <(String, double)>[];
	final bool hasStructuredRows = rawRows is List && rawRows.isNotEmpty;
	if (rawRows is List) {
	  for (final dynamic rawRow in rawRows.take(3)) {
		if (rawRow is! Map || rawRow['columns'] is! List) continue;
		final List<dynamic> columns = rawRow['columns'] as List<dynamic>;
		for (final dynamic rawColumn in columns.take(6)) {
		  if (rawColumn is! Map || rawColumn['items'] is! List) continue;
		  final List<dynamic> columnItems = rawColumn['items'] as List<dynamic>;
		  final double width = (rawColumn['width'] as num?)?.toDouble() ?? 100 / columns.length;
		  final double itemWidth = columnItems.isEmpty ? width : width / columnItems.length;
		  placements.addAll(columnItems.map((item) => ('$item', itemWidth)));
		}
	  }
	}
	final dynamic legacyItems = footerLayout['items'];
	if (placements.isEmpty) {
	  final List<String> items = legacyItems is List ? legacyItems.map((item) => '$item').toList() : <String>['share', 'like', 'add_to_cart'];
	  placements.addAll(items.map((item) => (item, 100 / items.length)));
	}
	final bool hasAddToCart = placements.any(
	  ((String, double) placement) => placement.$1 == 'add_to_cart',
	);
	final double configuredButtonWidth = footer
	    .number('button_width_percent', 58)
	    .clamp(20, 95);
	final double otherWidthTotal = placements
	    .where(((String, double) placement) => placement.$1 != 'add_to_cart')
	    .fold<double>(0, (double total, (String, double) placement) => total + placement.$2);
	final String buttonStyle = footer.string('button_style', 'filled');
	final double configuredButtonHeight = footer
	    .number('button_height', 52)
	    .clamp(36, 80);
	// A configured product action must never be silently squeezed back to the
	// category footer height. Grow the product footer when the button is taller.
	final double footerHeight = configuredButtonHeight > configuredFooterHeight
	    ? configuredButtonHeight
	    : configuredFooterHeight;
	final double buttonHeight = configuredButtonHeight;
	final String buttonShape = footer.string('button_shape', 'custom');
	final double buttonRadius = switch (buttonShape) {
	  'rectangle' => 0,
	  'rounded' => 12,
	  'pill' => buttonHeight / 2,
	  _ => footer.number('button_radius', 28).clamp(0, 40),
	};
	final double configuredBorderWidth = footer
	    .number('button_border_width', 0)
	    .clamp(0, 6);
	final double buttonBorderWidth = buttonStyle == 'outline' && configuredBorderWidth < 1
	    ? 1
	    : configuredBorderWidth;
	final Color buttonBackground = switch (buttonStyle) {
	  'outline' => Colors.transparent,
	  'soft' => buttonColor.withValues(alpha: 0.14),
	  _ => buttonColor,
	};
	final bool awaitingProductOptions =
	    product.hasVariations && !controller.canAddToCart;
	final Color purchaseButtonBackground = product.hasVariations
	    ? awaitingProductOptions
	        ? buttonColor.withValues(alpha: 0.48)
	        : buttonColor
	    : buttonBackground;
	final bool purchaseFlowAvailable = product.hasVariations ||
	    (hasCartConnection && product.isPurchasable && product.isInStock);
	final List<(String, double, Widget)> footerItems =
	    <(String, double, Widget)>[];
	for (final (String item, double width) in placements) {
	  final double effectiveWidth = hasAddToCart && !hasStructuredRows
	      ? item == 'add_to_cart'
	          ? configuredButtonWidth
	          : otherWidthTotal > 0
	          ? (100 - configuredButtonWidth) * width / otherWidthTotal
	          : 0
	      : width;
	  Widget? child;
	  if (item == 'share') {
		child = _FooterAction(id: 'share', icon: _footerActionIcon('share', footer.string('share_icon_variant', 'upload'), false), label: footer.boolean('show_labels', true) ? _arabicFooterLabel(footer.string('share_label', ''), 'مشاركة') : '', color: _cmsColor(footer.string('share_color', '#1F2933'), Colors.black87), size: footerIconSize, iconBoxSize: footerIconBoxSize, style: footer.string('share_icon_style', 'outline'), labelSize: footerLabelSize, iconLabelGap: footerIconLabelGap, onPressed: onShare);
	  } else if (item == 'like') {
		child = _FooterAction(id: 'like', iconKey: const Key('product-wishlist-button'), icon: _footerActionIcon('like', footer.string('like_icon_variant', 'heart'), isLiked), label: footer.boolean('show_labels', true) ? _arabicFooterLabel(footer.string('like_label', ''), 'المفضلة') : '', color: isLiked ? Colors.red : _cmsColor(footer.string('like_color', '#1F2933'), Colors.black87), size: footerIconSize, iconBoxSize: footerIconBoxSize, style: footer.string('like_icon_style', 'outline'), labelSize: footerLabelSize, iconLabelGap: footerIconLabelGap, onPressed: onLike);
	  } else if (item == 'add_to_cart') {
		child = Align(
		  alignment: Alignment.center,
		  child: SizedBox(
		    key: const Key('product-add-to-cart-size'),
		    width: double.infinity,
		    height: buttonHeight,
		    child: FilledButton.icon(
		      key: const Key('add-to-cart-button'),
		      style: FilledButton.styleFrom(
		        backgroundColor: purchaseButtonBackground,
		        foregroundColor: buttonText,
		        disabledBackgroundColor: purchaseButtonBackground.withValues(
		          alpha: 0.42,
		        ),
		        disabledForegroundColor: buttonText.withValues(alpha: 0.62),
		        textStyle: TextStyle(fontSize: footerLabelSize),
		        side: BorderSide(
		          color: buttonBorderColor,
		          width: buttonBorderWidth,
		        ),
		        shape: RoundedRectangleBorder(
		          borderRadius: BorderRadius.circular(buttonRadius),
		        ),
		      ),
		      onPressed: purchaseFlowAvailable
		          ? controller.isAdding
		              ? () {}
		              : onPressed
		          : null,
		      icon: controller.isAdding
		          ? SizedBox.square(
		              dimension: footerIconSize,
		              child: const CircularProgressIndicator(strokeWidth: 2),
		            )
		          : Icon(Icons.shopping_bag_outlined, size: footerIconSize),
		      label: Text(
		        controller.isAdding
		            ? 'جارٍ الإضافة…'
		            : _arabicFooterLabel(
		                footer.string('add_to_cart_label', ''),
		                'أضف إلى السلة',
		              ),
		      ),
		    ),
		  ),
		);
	  }
	  if (child != null && effectiveWidth > 0) {
	    footerItems.add((item, effectiveWidth, child));
	  }
	}
	final double footerWidthTotal = footerItems.fold<double>(
	  0,
	  (double total, (String, double, Widget) placement) =>
	      total + placement.$2,
	);
    return Material(
      elevation: footer.string('shadow', 'subtle') == 'none' ? 0 : footer.string('shadow', 'subtle') == 'strong' ? 18 : 8,
      color: background,
	  shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(footer.number('top_radius', 0))), side: BorderSide(color: _cmsColor(footer.string('border_color', '#E2E6E4'), Colors.transparent), width: footer.number('border_width', 1))),
      child: SafeArea(
        top: false,
		bottom: footer.boolean('safe_area', true),
		minimum: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width * footer.number('side_spacing_percent', 5).clamp(0, 25) / 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (controller.addError != null && !awaitingProductOptions) ...<Widget>[
              Text(
                controller.addError!,
                key: const Key('add-to-cart-error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ] else if (reason != null) ...<Widget>[
              Text(
                reason,
                key: const Key('add-to-cart-disabled-reason'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
			SizedBox(
			  key: const Key('product-footer-size'),
			  height: footerHeight,
			  child: LayoutBuilder(
			    builder: (BuildContext context, BoxConstraints constraints) {
			      final double availableWidth = constraints.maxWidth;
			      return Row(
			        children: footerItems.map(
			          ((String, double, Widget) placement) => SizedBox(
			            key: Key('product-footer-column-${placement.$1}'),
			            width: footerWidthTotal <= 0
			                ? 0
			                : availableWidth * placement.$2 / footerWidthTotal,
			            child: placement.$3,
			          ),
			        ).toList(growable: false),
			      );
			    },
			  ),
			),
          ],
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    required this.iconBoxSize,
    required this.style,
    required this.labelSize,
    required this.iconLabelGap,
    required this.onPressed,
    this.iconKey,
  });

  final String id;
  final Key? iconKey;
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final double iconBoxSize;
  final String style;
  final double labelSize;
  final double iconLabelGap;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool decorated = style == 'filled' || style == 'circle';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox.square(
            key: Key('product-footer-icon-box-$id'),
            dimension: iconBoxSize,
            child: IconButton(
              key: iconKey,
              onPressed: onPressed,
              color: decorated ? Colors.white : color,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                backgroundColor: decorated ? color : Colors.transparent,
                shape: style == 'circle'
                    ? const CircleBorder()
                    : RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
              ),
              icon: Icon(icon, size: size),
            ),
          ),
          if (label.isNotEmpty) ...<Widget>[
            SizedBox(
              key: Key('product-footer-icon-label-gap-$id'),
              height: iconLabelGap,
            ),
            SizedBox(
              height: labelSize * 1.25,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: labelSize, height: 1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _footerActionIcon(String type, String variant, bool selected) => switch (type) { 'share' => variant == 'send' ? Icons.send_outlined : variant == 'share' ? Icons.share_outlined : Icons.ios_share_outlined, 'like' => variant == 'bookmark' ? (selected ? Icons.bookmark : Icons.bookmark_border) : selected ? Icons.favorite_rounded : Icons.favorite_border_rounded, _ => Icons.circle_outlined };
Color _cmsColor(String value, Color fallback) { final hex=value.replaceFirst('#',''); return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)?Color(int.parse('FF$hex',radix:16)):fallback; }

class _ProductLoading extends StatelessWidget {
  const _ProductLoading({required this.copy});

  final _ProductCopy copy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(copy.loading),
        ],
      ),
    );
  }
}

class _ProductEmpty extends StatelessWidget {
  const _ProductEmpty({required this.copy});

  final _ProductCopy copy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inventory_2_outlined, size: 56),
            const SizedBox(height: 14),
            Text(copy.notFound, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProductFailure extends StatelessWidget {
  const _ProductFailure({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              key: const Key('product-load-error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              key: const Key('product-retry-button'),
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductShareSheet extends StatelessWidget {
  const _ProductShareSheet({required this.product});

  final CatalogProduct product;

  String get _link => product.permalink.toString();
  String get _message => '${product.name}\n$_link';

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('product-share-sheet'),
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  key: const Key('product-share-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
                const Expanded(
                  child: Text(
                    'شارك المنتج مع أصدقائك',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                if (product.primaryImage != null)
                  AppNetworkImage(
                    imageUrl: product.primaryImage!.src.toString(),
                    width: 76,
                    height: 92,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(10),
                  )
                else
                  Container(
                    width: 76,
                    height: 92,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_outlined),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1),
            ),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              children: <Widget>[
                _ShareAction(
                  key: const Key('share-facebook'),
                  label: 'Facebook',
                  icon: Icons.facebook_rounded,
                  color: const Color(0xFF1877F2),
                  onTap: () => _open(
                    Uri.parse(
                      'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_link)}',
                    ),
                  ),
                ),
                _ShareAction(
                  key: const Key('share-whatsapp'),
                  label: 'WhatsApp',
                  icon: Icons.chat_rounded,
                  color: const Color(0xFF25D366),
                  onTap: () => _open(
                    Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(_message)}',
                    ),
                  ),
                ),
                _ShareAction(
                  key: const Key('share-messenger'),
                  label: 'Messenger',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF8A3FFC),
                  onTap: () async {
                    await Share.share(_message, subject: product.name);
                  },
                ),
                _ShareAction(
                  key: const Key('share-copy-link'),
                  label: 'نسخ الرابط',
                  icon: Icons.link_rounded,
                  color: colors.onSurface,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: _link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ رابط المنتج')),
                    );
                  },
                ),
                _ShareAction(
                  key: const Key('share-more'),
                  label: 'المزيد',
                  icon: Icons.more_horiz_rounded,
                  color: colors.onSurface,
                  onTap: () async {
                    await Share.share(_message, subject: product.name);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Share.share(_message, subject: product.name);
    }
  }
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 82,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: <Widget>[
            CircleAvatar(
              radius: 30,
              backgroundColor: color,
              foregroundColor: Colors.white,
              child: Icon(icon, size: 32),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    ),
  );
}

String _plainText(String source) {
  return source
      .replaceAll(
        RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n')
      .trim();
}

class _ProductCopy {
  const _ProductCopy._({required this.arabic});

  final bool arabic;

  static _ProductCopy of(BuildContext context) => _ProductCopy._(
    arabic: Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
  );

  String get share => arabic ? 'مشاركة' : 'Share';
  String get save => arabic ? 'حفظ' : 'Save';
  String get sku => arabic ? 'رمز المنتج' : 'SKU';
  String get sale => arabic ? 'خصم' : 'Sale';
  String get inStock => arabic ? 'متوفر' : 'In stock';
  String get outOfStock => arabic ? 'غير متوفر' : 'Out of stock';
  String get choose => arabic ? 'اختر' : 'Choose';
  String get quantity => arabic ? 'الكمية' : 'Quantity';
  String get decreaseQuantity => arabic ? 'تقليل الكمية' : 'Decrease quantity';
  String get increaseQuantity => arabic ? 'زيادة الكمية' : 'Increase quantity';
  String get description => arabic ? 'تفاصيل المنتج' : 'Product details';
  String get brand => arabic ? 'العلامة التجارية' : 'Brand';
  String get relatedProducts => arabic ? 'منتجات مشابهة' : 'Related products';
  String get addToCart => arabic ? 'أضف إلى السلة' : 'Add to cart';
  String get adding => arabic ? 'جارٍ الإضافة…' : 'Adding…';
  String get cartNotConnected => arabic
      ? 'ربط السلة غير متاح في هذه النسخة بعد.'
      : 'Cart connection is not available in this build yet.';
  String get chooseOptionsTitle =>
      arabic ? 'اختر خيارات المنتج' : 'Choose product options';
  String get unavailableCombination =>
      arabic ? 'هذه المجموعة غير متوفرة.' : 'This combination is unavailable.';
  String get notPurchasable => arabic
      ? 'هذا المنتج غير متاح للشراء حالياً.'
      : 'This product cannot be purchased right now.';
  String get loading => arabic ? 'جارٍ تحميل المنتج…' : 'Loading product…';
  String get notFound =>
      arabic ? 'لم يتم العثور على المنتج.' : 'Product not found.';
  String get loadFailure => arabic
      ? 'تعذر تحميل المنتج. حاول مرة أخرى.'
      : 'Unable to load this product. Please try again.';
  String get retry => arabic ? 'إعادة المحاولة' : 'Retry';

  String reviewCount(int count) =>
      arabic ? '($count مراجعة)' : '($count reviews)';
}

String _arabicFooterLabel(
  String configured,
  String arabicFallback,
) {
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(configured)) {
    return configured;
  }
  return arabicFallback;
}
