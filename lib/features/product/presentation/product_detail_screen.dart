import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/product/application/product_detail_controller.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:kidia_store_app/shared/widgets/product/product_badge.dart';

typedef ProductWishlistToggleCallback =
    Future<bool> Function(CatalogProduct product);
typedef ProductWishlistStatusCallback = Future<bool> Function(int productId);

class ProductDetailScreen extends StatefulWidget {
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
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductDetailController _controller;
  bool _isWishlisted = false;
  bool _isWishlistMutating = false;

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
    return CmsPageLayoutLoader(
      page: 'product',
      builder: (BuildContext context, CmsPageLayout layout) => Scaffold(
        appBar: CmsPageAppBar(
          layout: layout,
          defaultTitle: copy.description,
          actions: _buildCmsActions(copy),
        ),
        body: _buildBody(copy, layout),
        bottomNavigationBar:
            layout.element('purchase_bar').enabled &&
                _controller.status == ProductDetailStatus.success &&
                _controller.product != null
            ? _PurchaseBar(
                controller: _controller,
                footer: layout.footer,
                hasCartConnection: widget.onAddToCart != null,
                copy: copy,
                onPressed: _addToCart,
                onShare: widget.onShareRequested == null ? null : () => widget.onShareRequested!(_controller.product!),
                onLike: widget.onWishlistToggle == null || _isWishlistMutating ? null : () => _toggleWishlist(_controller.product!),
                isLiked: _isWishlisted,
              )
            : null,
      ),
    );
  }

  List<CmsPageHeaderAction> _buildCmsActions(_ProductCopy copy) {
    final CatalogProduct? product = _controller.product;
    return <CmsPageHeaderAction>[
      if (product != null && widget.onShareRequested != null)
        CmsPageHeaderAction(
          type: 'share',
          icon: Icons.ios_share_outlined,
          tooltip: copy.share,
          onPressed: () => widget.onShareRequested!(product),
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

  Future<void> _addToCart() async {
    final bool added = await _controller.addToCart(widget.onAddToCart);
    if (!mounted || !added) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_ProductCopy.of(context).addedToCart)),
    );
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
            child: _ProductGallery(images: images, productName: product.name),
          ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 12),
          sliver: SliverList.list(
            children: <Widget>[
              if (pageLayout.element('product_summary').enabled &&
                  pageLayout.element('product_summary').boolean('show_badge', true) &&
                  (product.isOnSale || !inStock)) ...<Widget>[
                _ProductBadges(
                  product: product,
                  variation: variation,
                  copy: copy,
                ),
                const SizedBox(height: 12),
              ],
              if (pageLayout.element('product_summary').enabled &&
                  pageLayout.element('product_summary').boolean('show_name', true))
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (pageLayout.element('product_summary').enabled &&
                  pageLayout.element('product_summary').boolean('show_sku', true) &&
                  product.sku.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '${copy.sku}: ${product.sku}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (pageLayout.element('product_summary').enabled &&
                  pageLayout.element('product_summary').boolean('show_price', true))
                _MoneyPrice(money: money),
              if (pageLayout.element('variations').enabled && controller.optionGroups.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                for (final ProductOptionGroup group in controller.optionGroups)
                  _ProductOptionPicker(
                    group: group,
                    controller: controller,
                    copy: copy,
                  ),
              ],
              const SizedBox(height: 18),
              if (pageLayout.element('purchase_bar').enabled &&
                  pageLayout.element('purchase_bar').boolean('show_quantity', true))
                _QuantitySelector(controller: controller, copy: copy),
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
                _DetailsSection(product: product, copy: copy),
              const SizedBox(height: 18),
              if (pageLayout.element('related_products').enabled)
              OutlinedButton.icon(
                key: const Key('related-products-button'),
                onPressed: onRelatedProductsRequested == null
                    ? null
                    : () => onRelatedProductsRequested!(product),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(copy.relatedProducts),
              ),
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
  const _ProductGallery({required this.images, required this.productName});

  final List<CatalogImage> images;
  final String productName;

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
        aspectRatio: 0.86,
        child: AppNetworkImageError(
          backgroundColor: colors.surfaceContainerLow,
          iconSize: 54,
        ),
      );
    }

    return Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 0.86,
          child: PageView.builder(
            key: ValueKey<String>(widget.images.first.source.toString()),
            controller: _pageController,
            itemCount: widget.images.length == 1 ? 1 : null,
            onPageChanged: (int page) =>
                setState(() => _page = page % widget.images.length),
            itemBuilder: (BuildContext context, int index) {
              final int imageIndex = index % widget.images.length;
              final CatalogImage image = widget.images[imageIndex];
              return InteractiveViewer(
                key: Key('product-image-$imageIndex'),
                minScale: 1,
                maxScale: 4,
                clipBehavior: Clip.hardEdge,
                child: AppNetworkImage(
                  imageUrl: image.source.toString(),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  backgroundColor: colors.surfaceContainerLow,
                  semanticLabel: image.alt.isEmpty
                      ? widget.productName
                      : image.alt,
                ),
              );
            },
          ),
        ),
        if (widget.images.length > 1)
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
  const _MoneyPrice({required this.money});

  final CatalogMoney money;

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
        if (money.isDiscounted && regular.isNotEmpty)
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
  });

  final ProductOptionGroup group;
  final ProductDetailController controller;
  final _ProductCopy copy;

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
  const _DetailsSection({required this.product, required this.copy});

  final CatalogProduct product;
  final _ProductCopy copy;

  @override
  Widget build(BuildContext context) {
    final String description = _plainText(product.description);
    if (description.isEmpty) {
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
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(description, style: const TextStyle(height: 1.6)),
        ),
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
    required this.hasCartConnection,
    required this.copy,
    required this.onPressed,
    required this.onShare,
    required this.onLike,
    required this.isLiked,
  });

  final ProductDetailController controller;
  final CmsPageComponent footer;
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
    } else if (!product.isInStock) {
      reason = copy.outOfStock;
    } else if (product.hasVariations && !controller.selectionComplete) {
      reason = copy.chooseOptionsFirst;
    } else if (product.hasVariations && !controller.canAddToCart) {
      reason = copy.unavailableCombination;
    } else if (!product.isPurchasable) {
      reason = copy.notPurchasable;
    }

    if (!footer.enabled || !footer.boolean('show_add_to_cart', true)) { return const SizedBox.shrink(); }
    final Color background = _cmsColor(footer.string('background_color', '#FFFFFF'), Theme.of(context).colorScheme.surface);
    final Color buttonColor = _cmsColor(footer.string('button_color', '#1F2933'), Theme.of(context).colorScheme.primary);
    final Color buttonText = _cmsColor(footer.string('button_text_color', '#FFFFFF'), Colors.white);
    return Material(
      elevation: footer.string('shadow', 'subtle') == 'none' ? 0 : footer.string('shadow', 'subtle') == 'strong' ? 18 : 8,
      color: background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(footer.number('top_radius', 0))),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(footer.number('horizontal_padding', 16), 10, footer.number('horizontal_padding', 16), 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (controller.addError != null) ...<Widget>[
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
            Row(children: <Widget>[
              if (footer.boolean('show_share', true)) _FooterAction(icon: Icons.ios_share_outlined, label: footer.string('share_label', copy.share), color: _cmsColor(footer.string('share_color', '#1F2933'), Colors.black87), size: footer.number('share_icon_size', 24), onPressed: onShare),
              if (footer.boolean('show_like', true)) _FooterAction(icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: footer.string('like_label', 'Like'), color: isLiked ? Colors.red : _cmsColor(footer.string('like_color', '#1F2933'), Colors.black87), size: footer.number('like_icon_size', 24), onPressed: onLike),
              SizedBox(width: footer.number('item_gap', 10)),
              Expanded(child: FilledButton.icon(key: const Key('add-to-cart-button'), style: FilledButton.styleFrom(backgroundColor: buttonColor, foregroundColor: buttonText, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(footer.number('button_radius', 28)))), onPressed: hasCartConnection && controller.canAddToCart ? onPressed : null, icon: controller.isAdding ? const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.shopping_bag_outlined), label: Text(controller.isAdding ? copy.adding : footer.string('add_to_cart_label', copy.addToCart)))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget { const _FooterAction({required this.icon,required this.label,required this.color,required this.size,required this.onPressed}); final IconData icon; final String label; final Color color; final double size; final VoidCallback? onPressed; @override Widget build(BuildContext context)=>InkWell(onTap:onPressed,child:Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:color,size:size),Text(label,style:TextStyle(color:color,fontSize:11))]))); }
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
  String get addedToCart => arabic ? 'تمت الإضافة إلى السلة' : 'Added to cart';
  String get cartNotConnected => arabic
      ? 'ربط السلة غير متاح في هذه النسخة بعد.'
      : 'Cart connection is not available in this build yet.';
  String get chooseOptionsFirst => arabic
      ? 'اختر خيارات المنتج أولاً.'
      : 'Choose the product options first.';
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
