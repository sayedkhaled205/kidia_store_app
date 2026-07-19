import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/wishlist/application/wishlist_controller.dart';
import 'package:kidia_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({
    required this.repository,
    required this.catalogRepository,
    super.key,
    this.onProductTap,
    this.onContinueShopping,
  });

  final WishlistRepository repository;
  final CatalogRepository catalogRepository;
  final ValueChanged<CatalogProduct>? onProductTap;
  final VoidCallback? onContinueShopping;

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late WishlistController _controller;
  Timer? _snackBarTimer;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(WishlistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.catalogRepository, widget.catalogRepository)) {
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _createController();
    }
  }

  void _createController() {
    _controller = WishlistController(
      repository: widget.repository,
      catalogRepository: widget.catalogRepository,
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
    _snackBarTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _WishlistCopy copy = _WishlistCopy.of(context);
    return CmsPageLayoutLoader(
      page: 'wishlist',
      builder: (BuildContext context, CmsPageLayout layout) => Scaffold(
        appBar: CmsPageAppBar(
          layout: layout,
          defaultTitle: copy.title,
          actions: <CmsPageHeaderAction>[
            CmsPageHeaderAction(
              type: 'cart',
              icon: Icons.shopping_bag_outlined,
              tooltip: 'Cart',
              onPressed: () => context.push('/cart'),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            if (_controller.status == WishlistStatus.ready &&
                layout.header.boolean('show_count', true))
              Text('${_controller.length}', key: const Key('wishlist-count')),
            if (_controller.mutationError != null)
              _MutationErrorNotice(
                message: _controller.mutationError!,
                closeLabel: copy.dismiss,
                onClose: _controller.clearMutationError,
              ),
            Expanded(child: _buildBody(copy, layout)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(_WishlistCopy copy, CmsPageLayout layout) {
    switch (_controller.status) {
      case WishlistStatus.initial:
      case WishlistStatus.loading:
        return _WishlistLoading(copy: copy);
      case WishlistStatus.failure:
        return _WishlistFailure(
          message: _controller.loadError ?? copy.loadFailure,
          retryLabel: copy.retry,
          onRetry: _controller.load,
        );
      case WishlistStatus.empty:
        if (!layout.element('empty_state').enabled) {
          return const SizedBox.shrink();
        }
        return CmsElementFrame(component: layout.element('empty_state'), child: _WishlistEmpty(
          copy: copy,
          onRefresh: _controller.refresh,
          onContinueShopping: widget.onContinueShopping,
        ));
      case WishlistStatus.ready:
        if (!layout.element('wishlist_grid').enabled) {
          return const SizedBox.shrink();
        }
        return CmsElementFrame(component: layout.element('wishlist_grid'), child: _WishlistGrid(
          products: _controller.products,
          copy: copy,
          isMutating: _controller.isMutating,
          onRefresh: _controller.refresh,
          onProductTap: widget.onProductTap,
          onRemove: _removeProduct,
        ));
    }
  }

  Future<void> _removeProduct(CatalogProduct product) async {
    final bool removed = await _controller.remove(product.id);
    if (!mounted || !removed) {
      return;
    }
    final _WishlistCopy copy = _WishlistCopy.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(copy.removed),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: copy.undo,
            onPressed: () {
              _controller.add(product.id, product: product);
            },
          ),
        ),
      );
    _snackBarTimer?.cancel();
    _snackBarTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        messenger.hideCurrentSnackBar();
      }
    });
  }
}

class _MutationErrorNotice extends StatelessWidget {
  const _MutationErrorNotice({
    required this.message,
    required this.closeLabel,
    required this.onClose,
  });

  final String message;
  final String closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('wishlist-mutation-error'),
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: closeLabel,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistGrid extends StatelessWidget {
  const _WishlistGrid({
    required this.products,
    required this.copy,
    required this.isMutating,
    required this.onRefresh,
    required this.onRemove,
    this.onProductTap,
  });

  final List<CatalogProduct> products;
  final _WishlistCopy copy;
  final bool isMutating;
  final Future<void> Function() onRefresh;
  final ValueChanged<CatalogProduct> onRemove;
  final ValueChanged<CatalogProduct>? onProductTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columnCount = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 820
            ? 4
            : constraints.maxWidth >= 560
            ? 3
            : 2;
        final double spacing = constraints.maxWidth >= 560 ? 16 : 12;
        final double topSpacing = (constraints.maxWidth * 0.05)
            .clamp(18, 24)
            .toDouble();
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: GridView.builder(
            key: const Key('wishlist-grid'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsetsDirectional.fromSTEB(
              spacing,
              topSpacing,
              spacing,
              28,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: constraints.maxWidth >= 820 ? 0.7 : 0.62,
            ),
            itemCount: products.length,
            itemBuilder: (BuildContext context, int index) {
              final CatalogProduct product = products[index];
              return _WishlistProductCard(
                product: product,
                copy: copy,
                removeEnabled: !isMutating,
                onTap: onProductTap == null
                    ? null
                    : () => onProductTap!(product),
                onRemove: () => onRemove(product),
              );
            },
          ),
        );
      },
    );
  }
}

class _WishlistProductCard extends StatelessWidget {
  const _WishlistProductCard({
    required this.product,
    required this.copy,
    required this.removeEnabled,
    required this.onRemove,
    this.onTap,
  });

  final CatalogProduct product;
  final _WishlistCopy copy;
  final bool removeEnabled;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String imageUrl = product.primaryImage?.source.toString() ?? '';
    return Card(
      key: Key('wishlist-product-${product.id}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (imageUrl.isEmpty)
                    AppNetworkImageError(
                      backgroundColor: colors.surfaceContainerLow,
                    )
                  else
                    AppNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      semanticLabel: product.name,
                    ),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: Material(
                      color: colors.surface.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: Key('wishlist-remove-${product.id}'),
                        tooltip: copy.remove,
                        onPressed: removeEnabled ? onRemove : null,
                        icon: Icon(Icons.favorite_rounded, color: colors.error),
                      ),
                    ),
                  ),
                  if (product.isOnSale)
                    PositionedDirectional(
                      top: 10,
                      start: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            copy.sale,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _WishlistPrice(money: product.prices),
                  const SizedBox(height: 6),
                  Text(
                    product.isInStock ? copy.inStock : copy.outOfStock,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: product.isInStock ? colors.primary : colors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistPrice extends StatelessWidget {
  const _WishlistPrice({required this.money});

  final CatalogMoney money;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String current = money.displayAmount(money.priceMinor);
    final String regular = money.displayAmount(money.regularPriceMinor);
    return Wrap(
      spacing: 7,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          current,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (money.isDiscounted && regular.isNotEmpty)
          Text(
            regular,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

class _WishlistLoading extends StatelessWidget {
  const _WishlistLoading({required this.copy});

  final _WishlistCopy copy;

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

class _WishlistEmpty extends StatelessWidget {
  const _WishlistEmpty({
    required this.copy,
    required this.onRefresh,
    this.onContinueShopping,
  });

  final _WishlistCopy copy;
  final Future<void> Function() onRefresh;
  final VoidCallback? onContinueShopping;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('wishlist-empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          Icon(
            Icons.favorite_border_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 18),
          Text(
            copy.emptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(copy.emptyBody, textAlign: TextAlign.center),
          if (onContinueShopping != null) ...<Widget>[
            const SizedBox(height: 22),
            Center(
              child: FilledButton.icon(
                key: const Key('wishlist-continue-shopping'),
                onPressed: onContinueShopping,
                icon: const Icon(Icons.storefront_outlined),
                label: Text(copy.continueShopping),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WishlistFailure extends StatelessWidget {
  const _WishlistFailure({
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
              size: 58,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              key: const Key('wishlist-load-error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              key: const Key('wishlist-retry'),
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistCopy {
  const _WishlistCopy._(this.arabic);

  final bool arabic;

  static _WishlistCopy of(BuildContext context) {
    return _WishlistCopy._(
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
    );
  }

  String get title => arabic ? 'المفضلة' : 'Wishlist';
  String get localOnly => arabic
      ? 'محفوظة على هذا الجهاز لهذا المتجر فقط.'
      : 'Saved on this device for this store only.';
  String get loading => arabic ? 'جارٍ تحميل المفضلة…' : 'Loading wishlist…';
  String get emptyTitle => arabic ? 'المفضلة فارغة' : 'Your wishlist is empty';
  String get emptyBody => arabic
      ? 'اضغط على القلب بجوار أي منتج لحفظه هنا.'
      : 'Tap the heart on any product to save it here.';
  String get continueShopping => arabic ? 'متابعة التسوق' : 'Continue shopping';
  String get loadFailure => arabic
      ? 'تعذر تحميل المفضلة. حاول مرة أخرى.'
      : 'Unable to load your wishlist. Please try again.';
  String get retry => arabic ? 'إعادة المحاولة' : 'Retry';
  String get remove => arabic ? 'إزالة من المفضلة' : 'Remove from wishlist';
  String get removed =>
      arabic ? 'تمت الإزالة من المفضلة' : 'Removed from wishlist';
  String get undo => arabic ? 'تراجع' : 'Undo';
  String get sale => arabic ? 'خصم' : 'Sale';
  String get inStock => arabic ? 'متوفر' : 'In stock';
  String get outOfStock => arabic ? 'غير متوفر' : 'Out of stock';
  String get dismiss => arabic ? 'إغلاق' : 'Dismiss';

}
