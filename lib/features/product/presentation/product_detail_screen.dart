import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/product/application/product_detail_controller.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:kidia_store_app/shared/widgets/product/product_badge.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.productId,
    required this.repository,
    super.key,
    this.onAddToCart,
    this.onReviewsRequested,
    this.onRelatedProductsRequested,
    this.onShareRequested,
    this.onWishlistRequested,
  });

  final int productId;
  final CatalogRepository repository;
  final ProductAddToCartCallback? onAddToCart;
  final ValueChanged<CatalogProduct>? onReviewsRequested;
  final ValueChanged<CatalogProduct>? onRelatedProductsRequested;
  final ValueChanged<CatalogProduct>? onShareRequested;
  final ValueChanged<CatalogProduct>? onWishlistRequested;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductDetailController _controller;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        !identical(oldWidget.repository, widget.repository)) {
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _createController();
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
    return Scaffold(
      appBar: AppBar(title: Text(copy.product), actions: _buildActions(copy)),
      body: _buildBody(copy),
      bottomNavigationBar:
          _controller.status == ProductDetailStatus.success &&
              _controller.product != null
          ? _PurchaseBar(
              controller: _controller,
              hasCartConnection: widget.onAddToCart != null,
              copy: copy,
              onPressed: _addToCart,
            )
          : null,
    );
  }

  List<Widget> _buildActions(_ProductCopy copy) {
    final CatalogProduct? product = _controller.product;
    return <Widget>[
      IconButton(
        tooltip: 'السلة',
        onPressed: () => context.push('/cart'),
        icon: const Icon(Icons.shopping_bag_outlined),
      ),
      if (product != null && widget.onShareRequested != null)
        IconButton(
          tooltip: copy.share,
          onPressed: () => widget.onShareRequested!(product),
          icon: const Icon(Icons.ios_share_outlined),
        ),
      if (product != null && widget.onWishlistRequested != null)
        IconButton(
          tooltip: copy.save,
          onPressed: () => widget.onWishlistRequested!(product),
          icon: const Icon(Icons.favorite_border_rounded),
        ),
    ];
  }

  Widget _buildBody(_ProductCopy copy) {
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
}

class _ProductContent extends StatelessWidget {
  const _ProductContent({
    required this.controller,
    required this.product,
    required this.copy,
    this.onReviewsRequested,
    this.onRelatedProductsRequested,
  });

  final ProductDetailController controller;
  final CatalogProduct product;
  final _ProductCopy copy;
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

    return CustomScrollView(
      key: const Key('product-detail-scroll'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _ProductGallery(images: images, productName: product.name),
        ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 12),
          sliver: SliverList.list(
            children: <Widget>[
              _ProductBadges(
                product: product,
                variation: variation,
                copy: copy,
              ),
              const SizedBox(height: 12),
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (product.sku.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '${copy.sku}: ${product.sku}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _MoneyPrice(money: money),
              if (controller.optionGroups.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                for (final ProductOptionGroup group in controller.optionGroups)
                  _ProductOptionPicker(
                    group: group,
                    controller: controller,
                    copy: copy,
                  ),
              ],
              const SizedBox(height: 18),
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
              _DetailsSection(product: product, copy: copy),
              if (product.brands.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _BrandSection(product: product, copy: copy),
              ],
              const SizedBox(height: 18),
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
        ProductBadge(
          label: inStock ? copy.inStock : copy.outOfStock,
          type: inStock ? ProductBadgeType.custom : ProductBadgeType.outOfStock,
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
            runSpacing: 9,
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
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                key: const Key('quantity-decrement'),
                tooltip: copy.decreaseQuantity,
                onPressed: controller.quantity > 1
                    ? controller.decrementQuantity
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 36,
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
                icon: const Icon(Icons.add_rounded),
              ),
            ],
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
    return ExpansionTile(
      key: const Key('product-brand-section'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        copy.brand,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: product.brands
                .map(
                  (brand) => Chip(
                    avatar: const Icon(Icons.verified_outlined, size: 18),
                    label: Text(brand.name),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({
    required this.controller,
    required this.hasCartConnection,
    required this.copy,
    required this.onPressed,
  });

  final ProductDetailController controller;
  final bool hasCartConnection;
  final _ProductCopy copy;
  final VoidCallback onPressed;

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

    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
            FilledButton.icon(
              key: const Key('add-to-cart-button'),
              onPressed: hasCartConnection && controller.canAddToCart
                  ? onPressed
                  : null,
              icon: controller.isAdding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_bag_outlined),
              label: Text(controller.isAdding ? copy.adding : copy.addToCart),
            ),
          ],
        ),
      ),
    );
  }
}

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

  String get product => arabic ? 'المنتج' : 'Product';
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
