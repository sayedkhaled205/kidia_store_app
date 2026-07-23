import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/wishlist/application/wishlist_controller.dart';
import 'package:kidia_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:kidia_store_app/features/product/presentation/widgets/product_quick_add.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

const List<CatalogProduct> _previewWishlistProducts = <CatalogProduct>[
  CatalogProduct(
    id: 900001,
    name: 'Kidia everyday set',
    slug: 'kidia-everyday-set',
    type: 'simple',
    isPurchasable: true,
    isInStock: true,
    stockStatus: CatalogStockStatus.inStock,
    prices: CatalogMoney(
      currencyCode: 'EGP',
      currencySymbol: 'ج.م',
      currencyMinorUnit: 2,
      priceMinor: '45000',
      regularPriceMinor: '52000',
      salePriceMinor: '45000',
    ),
  ),
  CatalogProduct(
    id: 900002,
    name: 'Kidia summer outfit',
    slug: 'kidia-summer-outfit',
    type: 'simple',
    isPurchasable: true,
    isInStock: true,
    stockStatus: CatalogStockStatus.inStock,
    prices: CatalogMoney(
      currencyCode: 'EGP',
      currencySymbol: 'ج.م',
      currencyMinorUnit: 2,
      priceMinor: '39000',
    ),
  ),
  CatalogProduct(
    id: 900003,
    name: 'Kids essentials',
    slug: 'kids-essentials',
    type: 'simple',
    isPurchasable: true,
    isInStock: true,
    stockStatus: CatalogStockStatus.inStock,
    prices: CatalogMoney(
      currencyCode: 'EGP',
      currencySymbol: 'ج.م',
      currencyMinorUnit: 2,
      priceMinor: '32000',
    ),
  ),
  CatalogProduct(
    id: 900004,
    name: 'Special offer',
    slug: 'special-offer',
    type: 'simple',
    isPurchasable: true,
    isInStock: true,
    stockStatus: CatalogStockStatus.inStock,
    prices: CatalogMoney(
      currencyCode: 'EGP',
      currencySymbol: 'ج.م',
      currencyMinorUnit: 2,
      priceMinor: '27500',
    ),
  ),
];

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({
    required this.repository,
    required this.catalogRepository,
    super.key,
    this.onProductTap,
    this.onContinueShopping,
    this.onSignIn,
    this.signedIn = false,
    this.requiresSignIn = false,
  });

  final WishlistRepository repository;
  final CatalogRepository catalogRepository;
  final ValueChanged<CatalogProduct>? onProductTap;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onSignIn;
  final bool signedIn;
  final bool requiresSignIn;

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
      builder: (BuildContext context, CmsPageLayout layout) {
        final String previewState = AppConfig.isCmsPreview
            ? layout.string('wishlist_preview_state', 'products')
            : '';
        return CmsPageScaffold(
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
          body:
              widget.requiresSignIn &&
                  !widget.signedIn &&
                  previewState.isEmpty
              ? _WishlistSignInGate(
                  repository: widget.catalogRepository,
                  onSignIn: widget.onSignIn,
                  onProductTap: widget.onProductTap,
                )
              : Column(
                  children: <Widget>[
                    if (_controller.status == WishlistStatus.ready &&
                        layout.header.boolean('show_count', true))
                      Text(
                        '${previewState == 'products' && _controller.length == 0 ? _previewWishlistProducts.length : _controller.length}',
                        key: const Key('wishlist-count'),
                      ),
                    if (_controller.mutationError != null)
                      _MutationErrorNotice(
                        message: _controller.mutationError!,
                        closeLabel: copy.dismiss,
                        onClose: _controller.clearMutationError,
                      ),
                    Expanded(child: _buildBody(copy, layout, previewState)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildBody(
    _WishlistCopy copy,
    CmsPageLayout layout, [
    String previewState = '',
  ]) {
    if (previewState == 'empty') {
      return _buildEmptyState(copy, layout);
    }
    if (previewState == 'products') {
      return _buildProductState(
        copy,
        layout,
        _controller.products.isEmpty
            ? _previewWishlistProducts
            : _controller.products,
        previewOnly: _controller.products.isEmpty,
      );
    }
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
        return _buildEmptyState(copy, layout);
      case WishlistStatus.ready:
        return _buildProductState(copy, layout, _controller.products);
    }
  }

  Widget _buildEmptyState(_WishlistCopy copy, CmsPageLayout layout) {
    final CmsPageComponent settings = layout.element('empty_state');
    if (!settings.enabled) {
      return const SizedBox.shrink();
    }
    return CmsElementFrame(
      component: settings,
      child: _WishlistEmpty(
        copy: copy,
        settings: settings,
        onRefresh: _controller.refresh,
        onContinueShopping: widget.onContinueShopping,
        onSignIn: widget.onSignIn,
      ),
    );
  }

  Widget _buildProductState(
    _WishlistCopy copy,
    CmsPageLayout layout,
    List<CatalogProduct> products, {
    bool previewOnly = false,
  }) {
    final CmsPageComponent settings = layout.element('wishlist_grid');
    if (!settings.enabled) {
      return const SizedBox.shrink();
    }
    return CmsElementFrame(
      component: settings,
      child: _WishlistGrid(
        products: products,
        copy: copy,
        settings: settings,
        isMutating: previewOnly || _controller.isMutating,
        onRefresh: previewOnly ? () async {} : _controller.refresh,
        onProductTap: previewOnly ? null : widget.onProductTap,
        onRemove: previewOnly ? (_) {} : _removeProduct,
      ),
    );
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

class _WishlistSignInGate extends StatelessWidget {
  const _WishlistSignInGate({
    required this.repository,
    this.onSignIn,
    this.onProductTap,
  });

  final CatalogRepository repository;
  final VoidCallback? onSignIn;
  final ValueChanged<CatalogProduct>? onProductTap;

  @override
  Widget build(BuildContext context) {
    final bool arabic = Localizations.localeOf(context).languageCode == 'ar';
    return ListView(
      key: const Key('wishlist-sign-in-required'),
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
      children: <Widget>[
        Icon(Icons.shopping_bag_outlined, size: 112, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 36),
        Text(arabic ? 'سجّل الدخول لعرض المفضلة' : 'Sign in to view your wishlist', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        Center(child: OutlinedButton(
          key: const Key('wishlist-sign-in-button'),
          onPressed: onSignIn,
          style: OutlinedButton.styleFrom(minimumSize: const Size(220, 58), side: BorderSide(color: Theme.of(context).colorScheme.onSurface), shape: const StadiumBorder()),
          child: Text(arabic ? 'تسجيل الدخول' : 'Sign In'),
        )),
        const SizedBox(height: 110),
        Text(arabic ? 'قد يعجبك أيضًا' : 'You may also like', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        FutureBuilder(
          future: repository.getProducts(CatalogProductQuery(perPage: 2, sort: CatalogSort.popularity)),
          builder: (BuildContext context, snapshot) {
            final List<CatalogProduct> products = snapshot.data?.items ?? const <CatalogProduct>[];
            if (products.isEmpty) return const SizedBox(height: 180);
            return Row(
              children: products.map((CatalogProduct product) => Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: InkWell(
                    onTap: onProductTap == null ? null : () => onProductTap!(product),
                    child: AspectRatio(
                      aspectRatio: 0.9,
                      child: AppNetworkImage(
                        imageUrl: product.primaryImage?.source.toString() ?? '',
                        fit: BoxFit.contain,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                      ),
                    ),
                  ),
                ),
              )).toList(growable: false),
            );
          },
        ),
      ],
    );
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
    required this.settings,
    required this.isMutating,
    required this.onRefresh,
    required this.onRemove,
    this.onProductTap,
  });

  final List<CatalogProduct> products;
  final _WishlistCopy copy;
  final CmsPageComponent settings;
  final bool isMutating;
  final Future<void> Function() onRefresh;
  final ValueChanged<CatalogProduct> onRemove;
  final ValueChanged<CatalogProduct>? onProductTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columnCount = settings
            .number('columns', 2)
            .round()
            .clamp(1, 4)
            .toInt();
        final double spacing = settings
            .number('gap', 12)
            .clamp(0, 32)
            .toDouble();
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
              childAspectRatio: settings
                  .number('image_ratio', 1)
                  .clamp(0.6, 1.8)
                  .toDouble() *
                  0.62,
            ),
            itemCount: products.length,
            itemBuilder: (BuildContext context, int index) {
              final CatalogProduct product = products[index];
              return _WishlistProductCard(
                product: product,
                copy: copy,
                settings: settings,
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
    required this.settings,
    required this.removeEnabled,
    required this.onRemove,
    this.onTap,
  });

  final CatalogProduct product;
  final _WishlistCopy copy;
  final CmsPageComponent settings;
  final bool removeEnabled;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String imageUrl = product.primaryImage?.source.toString() ?? '';
    final String cardStyle = settings.string('card_style', 'outlined');
    return Card(
      key: Key('wishlist-product-${product.id}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: cardStyle == 'elevated' ? null : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(settings.number('card_radius', 16)),
        side: cardStyle == 'outlined'
            ? BorderSide(color: colors.outlineVariant)
            : BorderSide.none,
      ),
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
                  if (product.isInStock &&
                      settings.boolean('quick_add_enabled', true))
					_positionedWishlistAction(
					  settings.string('quick_add_position', 'bottom_end'),
					  AbsorbPointer(
					    absorbing: !removeEnabled,
					    child: ProductQuickAddButton(
                          productId: product.id,
                          iconVariant: settings.string('quick_add_icon_variant', 'bag'),
                          iconStyle: settings.string('quick_add_icon_style', 'outline'),
                          iconSize: settings.number('quick_add_icon_size', 22).clamp(10, 36).toDouble(),
                          iconColor: _wishlistHexColor(settings.string('quick_add_icon_color', '#1F2933')),
                          showBackground: settings.boolean('quick_add_show_background', true),
                          backgroundColor: _wishlistHexColor(settings.string('quick_add_background_color', '#FFFFFF')),
                          backgroundRadius: settings.number('quick_add_radius', 24).clamp(0, 40).toDouble(),
						  backgroundSize: settings.number('quick_add_background_size', 40).clamp(10, 64).toDouble(),
                        ),
                      ),
                    ),
                  if (settings.boolean('show_badge', true) && product.isOnSale)
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
                  if (settings.boolean('show_price', true)) ...<Widget>[
                    const SizedBox(height: 7),
                    _WishlistPrice(
                      money: product.prices,
                      showRegularPrice: settings.boolean('show_regular_price', true),
                    ),
                  ],
                  if (settings.boolean('show_rating', true) && product.averageRating > 0) ...<Widget>[
                    const SizedBox(height: 5),
                    Row(children: <Widget>[
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(product.averageRating.toStringAsFixed(1)),
                    ]),
                  ],
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

Widget _positionedWishlistAction(String position, Widget child) {
  final bool top = position.startsWith('top_');
  final bool start = position.endsWith('_start');
  return PositionedDirectional(
    top: top ? 8 : null,
    bottom: top ? null : 8,
    start: start ? 8 : null,
    end: start ? null : 8,
    child: child,
  );
}

Color? _wishlistHexColor(String value) {
  final String hex = value.replaceFirst('#', '');
  final int? parsed = int.tryParse(hex, radix: 16);
  return parsed == null || hex.length != 6 ? null : Color(0xFF000000 | parsed);
}

class _WishlistPrice extends StatelessWidget {
  const _WishlistPrice({required this.money, required this.showRegularPrice});

  final CatalogMoney money;
  final bool showRegularPrice;

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
        if (showRegularPrice && money.isDiscounted && regular.isNotEmpty)
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
    required this.settings,
    required this.onRefresh,
    this.onContinueShopping,
    this.onSignIn,
  });

  final _WishlistCopy copy;
  final CmsPageComponent settings;
  final Future<void> Function() onRefresh;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final bool signsIn = settings.string('button_action', 'shopping') == 'sign_in';
    final VoidCallback? action = signsIn ? onSignIn : onContinueShopping;
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
            settings.string('title', copy.emptyTitle),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(settings.string('description', copy.emptyBody), textAlign: TextAlign.center),
          if (action != null && settings.boolean('show_button', true)) ...<Widget>[
            const SizedBox(height: 22),
            Center(
              child: FilledButton.icon(
                key: const Key('wishlist-continue-shopping'),
                onPressed: action,
                icon: Icon(signsIn ? Icons.login_rounded : Icons.storefront_outlined),
                label: Text(settings.string('button_label', copy.continueShopping)),
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
