import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_product_card.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_controller.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_footer_label.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:mobishop_store_app/features/product/presentation/widgets/product_quick_add.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_image_swiper.dart';

/// Null means no configured navigation. Invalid category IDs and unsafe URL
/// schemes never become an accidental product action.
String? wishlistRecommendationRoute(CmsPageComponent settings, int productId) {
  final String type = settings.string('action_type', 'product');
  final String value = settings.string('action_value', '').trim();
  if (type == 'category') {
    final int? id = int.tryParse(value);
    return id != null && id > 0 ? '/categories/$id' : null;
  }
  return type == 'product' ? '/product/$productId' : null;
}

Uri? wishlistRecommendationUrl(CmsPageComponent settings) {
  if (settings.string('action_type', 'product') != 'url') return null;
  final Uri? uri = Uri.tryParse(settings.string('action_value', '').trim());
  return uri != null &&
          <String>{'https', 'http'}.contains(uri.scheme) &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

/// Presentation-only removal control. The screen still owns persistence and
/// busy state; changing icon appearance never switches the wishlist repository.
class WishlistRemoveButton extends StatelessWidget {
  const WishlistRemoveButton({
    required this.settings,
    required this.tooltip,
    required this.onPressed,
    this.buttonKey,
    super.key,
  });

  final CmsPageComponent settings;
  final String tooltip;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    if (!settings.boolean('show_wishlist', true)) {
      return const SizedBox.shrink();
    }
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool filled =
        settings.string('product_wishlist_icon_style', 'outline') == 'filled';
    final IconData icon = switch (settings.string(
      'product_wishlist_icon_variant',
      'heart',
    )) {
      'bookmark' => filled ? Icons.bookmark : Icons.bookmark_border,
      'rounded' =>
        filled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      _ => filled ? Icons.favorite : Icons.favorite_border,
    };
    return SizedBox.square(
      dimension: settings
          .number('product_wishlist_background_size', 40)
          .clamp(20, 64)
          .toDouble(),
      child: Material(
        color: settings.boolean('product_wishlist_show_background', true)
            ? _wishlistHexColor(
                    settings.string(
                      'product_wishlist_background_color',
                      '#FFFFFF',
                    ),
                  ) ??
                  colors.surface
            : Colors.transparent,
        borderRadius: BorderRadius.circular(
          settings
              .number('product_wishlist_radius', 24)
              .clamp(0, 40)
              .toDouble(),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          key: buttonKey,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: settings
                .number('product_wishlist_icon_size', 20)
                .clamp(10, 36)
                .toDouble(),
            color:
                _wishlistHexColor(
                  settings.string('product_wishlist_icon_color', ''),
                ) ??
                colors.error,
          ),
        ),
      ),
    );
  }
}

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
        final bool signedOutGate = widget.requiresSignIn && !widget.signedIn;
        return CmsPageScaffold(
          layout: layout,
          defaultTitle: copy.title,
          actions: <CmsPageHeaderAction>[
            CmsPageHeaderAction(
              type: 'cart',
              icon: Icons.shopping_bag_outlined,
              tooltip: copy.arabic ? 'السلة' : 'Cart',
              onPressed: () => context.push('/cart'),
            ),
          ],
          body: Column(
            children: <Widget>[
              if (_controller.status == WishlistStatus.ready &&
                  layout.header.boolean('show_count', false) &&
                  (previewState == 'products' ||
                      previewState.isEmpty && !signedOutGate))
                Text('${_controller.length}', key: const Key('wishlist-count')),
              if (_controller.mutationError != null)
                _MutationErrorNotice(
                  message: _controller.mutationError!,
                  closeLabel: copy.dismiss,
                  onClose: _controller.clearMutationError,
                ),
              Expanded(
                child: _buildBody(
                  copy,
                  layout,
                  previewState.isNotEmpty
                      ? previewState
                      : signedOutGate
                      ? 'sign_in'
                      : '',
                ),
              ),
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
    if (previewState == 'sign_in') {
      return _buildSignInState(copy, layout);
    }
    if (previewState == 'empty') {
      return _buildEmptyState(copy, layout);
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

  Widget _buildSignInState(_WishlistCopy copy, CmsPageLayout layout) {
    return _WishlistStatePage(
      key: const Key('wishlist-sign-in-required'),
      layout: layout,
      state: 'sign_in',
      copy: copy,
      catalogRepository: widget.catalogRepository,
      onProductTap: widget.onProductTap,
      onSignIn: widget.onSignIn,
      onContinueShopping: widget.onContinueShopping,
      products: const <CatalogProduct>[],
      isMutating: true,
      onRefresh: () async {},
      onRemove: (_) {},
    );
  }

  Widget _buildEmptyState(_WishlistCopy copy, CmsPageLayout layout) {
    return _WishlistStatePage(
      key: const Key('wishlist-empty'),
      layout: layout,
      state: 'empty',
      copy: copy,
      catalogRepository: widget.catalogRepository,
      onProductTap: widget.onProductTap,
      onSignIn: widget.onSignIn,
      onContinueShopping: widget.onContinueShopping,
      products: const <CatalogProduct>[],
      isMutating: _controller.isMutating,
      onRefresh: _controller.refresh,
      onRemove: (_) {},
    );
  }

  Widget _buildProductState(
    _WishlistCopy copy,
    CmsPageLayout layout,
    List<CatalogProduct> products,
  ) {
    return _WishlistStatePage(
      layout: layout,
      state: 'products',
      copy: copy,
      catalogRepository: widget.catalogRepository,
      onProductTap: widget.onProductTap,
      onSignIn: widget.onSignIn,
      onContinueShopping: widget.onContinueShopping,
      products: products,
      isMutating: _controller.isMutating,
      onRefresh: _controller.refresh,
      onRemove: _removeProduct,
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

class _WishlistStatePage extends StatelessWidget {
  const _WishlistStatePage({
    required this.layout,
    required this.state,
    required this.copy,
    required this.catalogRepository,
    required this.products,
    required this.isMutating,
    required this.onRefresh,
    required this.onRemove,
    this.onProductTap,
    this.onContinueShopping,
    this.onSignIn,
    super.key,
  });

  final CmsPageLayout layout;
  final String state;
  final _WishlistCopy copy;
  final CatalogRepository catalogRepository;
  final List<CatalogProduct> products;
  final bool isMutating;
  final Future<void> Function() onRefresh;
  final ValueChanged<CatalogProduct> onRemove;
  final ValueChanged<CatalogProduct>? onProductTap;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onSignIn;

  String _stateFor(String id) {
    if (id.startsWith('sign_in_')) return 'sign_in';
    if (id.startsWith('empty_') || id == 'empty_state') return 'empty';
    if (id == 'wishlist_grid' || id.startsWith('products_')) return 'products';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final List<CmsPageComponent> components = layout.elements
        .where(
          (CmsPageComponent component) =>
              component.enabled && _stateFor(component.type) == state,
        )
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: components
            .map((CmsPageComponent component) => _element(context, component))
            .toList(growable: false),
      ),
    );
  }

  Widget _element(BuildContext context, CmsPageComponent component) {
    if (component.type == 'sign_in_state' || component.type == 'empty_state') {
      final bool signIn = component.type == 'sign_in_state';
      return CmsElementFrame(
        component: component,
        child: _WishlistMessage(
          instanceId: component.id,
          settings: component,
          copy: copy,
          signIn: signIn,
          horizontalPadding: cmsContentHorizontalPadding(layout),
          onContinueShopping: onContinueShopping,
          onSignIn: onSignIn,
        ),
      );
    }
    if (component.type == 'wishlist_grid') {
      return CmsElementFrame(
        component: component,
        child: _WishlistGrid(
          instanceId: component.id,
          products: products,
          copy: copy,
          settings: component,
          horizontalPadding: cmsContentHorizontalPadding(
            layout,
            component: component,
          ),
          isMutating: isMutating,
          onProductTap: onProductTap,
          onRemove: onRemove,
        ),
      );
    }
    if (component.type.endsWith('_recommendations')) {
      return CmsElementFrame(
        component: component,
        child: _WishlistRecommendations(
          key: ValueKey<String>(component.id),
          repository: catalogRepository,
          settings: wishlistRecommendationAppearance(component, layout),
          horizontalPadding: cmsContentHorizontalPadding(
            layout,
            component: component,
            componentKey: 'section_padding',
          ),
          onProductTap: onProductTap,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _WishlistMessage extends StatelessWidget {
  const _WishlistMessage({
    required this.instanceId,
    required this.settings,
    required this.copy,
    required this.signIn,
    required this.horizontalPadding,
    this.onContinueShopping,
    this.onSignIn,
  });

  final String instanceId;
  final CmsPageComponent settings;
  final _WishlistCopy copy;
  final bool signIn;
  final double horizontalPadding;
  final VoidCallback? onContinueShopping;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final String action = settings.string(
      'button_action',
      signIn ? 'sign_in' : 'shopping',
    );
    final VoidCallback? onPressed = action == 'sign_in'
        ? onSignIn
        : onContinueShopping;
    final double imageSize = settings
        .number('illustration_size', 104)
        .clamp(56, 180)
        .toDouble();
    final String imageUrl = settings.string('illustration_url', '');
    final Color buttonColor =
        _wishlistHexColor(settings.string('button_color', '#FFFFFF')) ??
        Colors.white;
    final Color textColor =
        _wishlistHexColor(settings.string('button_text_color', '#1D1D1D')) ??
        const Color(0xFF1D1D1D);
    final Color borderColor =
        _wishlistHexColor(settings.string('button_border_color', '#1D1D1D')) ??
        const Color(0xFF1D1D1D);
    final bool filled = settings.string('button_style', 'outline') == 'filled';
    return Padding(
      padding: EdgeInsets.only(
        top: settings.number('top_spacing', 56).clamp(0, 180).toDouble(),
        bottom: settings.number('bottom_spacing', 96).clamp(0, 220).toDouble(),
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: imageSize,
            height: imageSize,
            child: imageUrl.isEmpty
                ? CustomPaint(painter: const _WishlistBagPainter())
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        CustomPaint(painter: const _WishlistBagPainter()),
                  ),
          ),
          SizedBox(
            height: settings.number('content_gap', 18).clamp(0, 48).toDouble(),
          ),
          Text(
            cmsFooterLabel(
              settings.string('title', ''),
              signIn ? copy.signInTitle : copy.emptyTitle,
              signIn
                  ? const [
                      'Sign in to view your wishlist',
                      'سجّل الدخول لعرض المفضلة',
                    ]
                  : const ['Your wishlist is empty', 'المفضلة فارغة'],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: settings
                  .number('title_size', 18)
                  .clamp(12, 36)
                  .toDouble(),
              fontWeight: _wishlistFontWeight(
                settings.string('title_weight', '700'),
              ),
              height: 1.2,
            ),
          ),
          if (settings.boolean('show_description', !signIn)) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              cmsFooterLabel(
                settings.string('description', ''),
                copy.emptyBody,
                const [
                  'Add items here by clicking the little heart!',
                  'Tap the heart on any product to save it here.',
                  'اضغط على القلب بجوار أي منتج لحفظه هنا.',
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: settings
                    .number('description_size', 14)
                    .clamp(11, 26)
                    .toDouble(),
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ],
          if (settings.boolean('show_button', true)) ...<Widget>[
            SizedBox(
              height: settings
                  .number('content_gap', 18)
                  .clamp(0, 48)
                  .toDouble(),
            ),
            SizedBox(
              width: settings
                  .number('button_width', 220)
                  .clamp(120, 360)
                  .toDouble(),
              height: settings
                  .number('button_height', 52)
                  .clamp(36, 84)
                  .toDouble(),
              child: OutlinedButton(
                key: instanceId == (signIn ? 'sign_in_state' : 'empty_state')
                    ? signIn
                          ? const Key('wishlist-sign-in-button')
                          : const Key('wishlist-continue-shopping')
                    : ValueKey<String>('$instanceId-button'),
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  backgroundColor: filled ? buttonColor : Colors.transparent,
                  foregroundColor: textColor,
                  side: BorderSide(
                    color: borderColor,
                    width: settings
                        .number('button_border_width', 1.5)
                        .clamp(0, 6)
                        .toDouble(),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      settings
                          .number('button_radius', 26)
                          .clamp(0, 42)
                          .toDouble(),
                    ),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                child: Text(
                  cmsFooterLabel(
                    settings.string('button_label', ''),
                    signIn ? copy.signIn : copy.continueShopping,
                    signIn
                        ? const ['Sign In', 'تسجيل الدخول']
                        : const [
                            'Go Shopping',
                            'Continue shopping',
                            'متابعة التسوق',
                          ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WishlistRecommendations extends StatefulWidget {
  const _WishlistRecommendations({
    super.key,
    required this.repository,
    required this.settings,
    required this.horizontalPadding,
    this.onProductTap,
  });

  final CatalogRepository repository;
  final CmsPageComponent settings;
  final double horizontalPadding;
  final ValueChanged<CatalogProduct>? onProductTap;

  @override
  State<_WishlistRecommendations> createState() =>
      _WishlistRecommendationsState();
}

class _WishlistRecommendationsState extends State<_WishlistRecommendations> {
  late Future<List<CatalogProduct>> _products;

  @override
  void initState() {
    super.initState();
    _products = _load();
  }

  @override
  void didUpdateWidget(_WishlistRecommendations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.settings.number('limit', 4) !=
            widget.settings.number('limit', 4)) {
      _products = _load();
    }
  }

  Future<List<CatalogProduct>> _load() async {
    final int limit = widget.settings
        .number('limit', 4)
        .round()
        .clamp(2, 12)
        .toInt();
    final page = await widget.repository
        .getProducts(
          CatalogProductQuery(perPage: limit, sort: CatalogSort.popularity),
        )
        .timeout(const Duration(seconds: 8));
    return page.items.take(limit).toList(growable: false);
  }

  void _retry() {
    setState(() {
      _products = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double padding = widget.horizontalPadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 14, padding, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            cmsFooterLabel(
              widget.settings.string('title', ''),
              _WishlistCopy.of(context).recommendations,
              const ['You may also like', 'قد يعجبك أيضًا'],
            ),
            style: TextStyle(
              fontSize: widget.settings
                  .number('title_size', 20)
                  .clamp(14, 36)
                  .toDouble(),
              fontWeight: _wishlistFontWeight(
                widget.settings.string('title_weight', '700'),
              ),
              height: 1.2,
            ),
          ),
          SizedBox(
            height: widget.settings
                .number('title_bottom_spacing', 18)
                .clamp(0, 48)
                .toDouble(),
          ),
          FutureBuilder<List<CatalogProduct>>(
            future: _products,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<CatalogProduct>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 92,
                      child: Center(
                        child: TextButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ),
                    );
                  }
                  final List<CatalogProduct> products =
                      snapshot.data ?? const <CatalogProduct>[];
                  if (products.isEmpty) return const SizedBox.shrink();
                  final String layoutStyle = widget.settings.string(
                    'layout_style',
                    'grid',
                  );
                  final int columns = widget.settings
                      .number('columns', 2)
                      .round()
                      .clamp(1, 3)
                      .toInt();
                  final double gap = widget.settings
                      .number('gap', 8)
                      .clamp(0, 24)
                      .toDouble();
                  if (layoutStyle == 'carousel') {
                    return SizedBox(
                      height: 250,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: products.length,
                        separatorBuilder: (_, _) => SizedBox(width: gap),
                        itemBuilder: (BuildContext context, int index) =>
                            SizedBox(
                              width: 168,
                              child: _WishlistRecommendationCard(
                                product: products[index],
                                settings: widget.settings,
                                onTap: widget.onProductTap == null
                                    ? null
                                    : () =>
                                          widget.onProductTap!(products[index]),
                              ),
                            ),
                      ),
                    );
                  }
                  return GridView.builder(
                    key: const Key('wishlist-recommendations-grid'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: layoutStyle == 'compact'
                          ? (columns + 1).clamp(2, 3).toInt()
                          : columns,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      childAspectRatio:
                          widget.settings
                              .number('image_ratio', .82)
                              .clamp(.6, 1.8)
                              .toDouble() *
                          (widget.settings.boolean('show_price', true)
                              ? .78
                              : 1),
                    ),
                    itemCount: products.length,
                    itemBuilder: (BuildContext context, int index) {
                      final CatalogProduct product = products[index];
                      return _WishlistRecommendationCard(
                        product: product,
                        settings: widget.settings,
                        onTap: widget.onProductTap == null
                            ? null
                            : () => widget.onProductTap!(product),
                      );
                    },
                  );
                },
          ),
        ],
      ),
    );
  }
}

/// Recommendations inherit missing card appearance from the saved-products
/// grid; their own title, navigation and explicit overrides remain independent.
CmsPageComponent wishlistRecommendationAppearance(
  CmsPageComponent component,
  CmsPageLayout layout,
) {
  final inherited = <String, dynamic>{};
  var inheritedQuickAdd = true;
  for (final grid in layout.elements.where((e) => e.type == 'wishlist_grid')) {
    inheritedQuickAdd = grid.boolean('quick_add_enabled', true);
    for (final entry in grid.settings.entries) {
      if (RegExp(
            r'^(card_|image_|content_|price_|quick_add_|product_wishlist_)',
          ).hasMatch(entry.key) ||
          const {
            'show_name',
            'show_price',
            'show_regular_price',
            'show_rating',
            'show_badge',
            'show_wishlist',
            'enable_image_swipe',
          }.contains(entry.key)) {
        inherited[entry.key] = entry.value;
      }
    }
    break;
  }
  return CmsPageComponent(
    id: component.id,
    type: component.type,
    enabled: component.enabled,
    settings: {
      'show_name': false,
      'show_rating': false,
      'show_badge': false,
      ...inherited,
      ...component.settings,
      'quick_add_enabled':
          component.boolean('show_quick_add', true) &&
          component.boolean('quick_add_enabled', inheritedQuickAdd),
    },
  );
}

class _WishlistRecommendationCard extends StatelessWidget {
  const _WishlistRecommendationCard({
    required this.product,
    required this.settings,
    this.onTap,
  });

  final CatalogProduct product;
  final CmsPageComponent settings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String actionType = settings.string('action_type', 'product');
    final String? route = wishlistRecommendationRoute(settings, product.id);
    final Uri? url = wishlistRecommendationUrl(settings);
    final VoidCallback? configuredTap = actionType == 'product'
        ? onTap
        : route != null
        ? () => context.go(route)
        : url != null
        ? () {
            launchUrl(url, mode: LaunchMode.externalApplication);
          }
        : null;
    return CatalogProductCard(
      product: product,
      settings: settings,
      onTap: configuredTap,
    );
  }
}

class _WishlistBagPainter extends CustomPainter {
  const _WishlistBagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint shadow = Paint()..color = const Color(0xFFEDEDED);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .88),
        width: size.width * .82,
        height: size.height * .14,
      ),
      shadow,
    );
    final Path bag = Path()
      ..moveTo(size.width * .18, size.height * .26)
      ..lineTo(size.width * .82, size.height * .26)
      ..lineTo(size.width * .88, size.height * .82)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .9,
        size.width * .12,
        size.height * .82,
      )
      ..close();
    canvas.drawPath(bag, Paint()..color = const Color(0xFFF1F1F1));
    final Paint handle = Paint()
      ..color = const Color(0xFFE7E7E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .045
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * .36,
        size.height * .14,
        size.width * .28,
        size.height * .28,
      ),
      3.14,
      3.14,
      false,
      handle,
    );
    final Paint heart = Paint()..color = const Color(0xFFDDDDDD);
    final Path heartPath = Path()
      ..moveTo(size.width * .5, size.height * .66)
      ..cubicTo(
        size.width * .31,
        size.height * .53,
        size.width * .35,
        size.height * .4,
        size.width * .5,
        size.height * .48,
      )
      ..cubicTo(
        size.width * .65,
        size.height * .4,
        size.width * .69,
        size.height * .53,
        size.width * .5,
        size.height * .66,
      )
      ..close();
    canvas.drawPath(heartPath, heart);
  }

  @override
  bool shouldRepaint(covariant _WishlistBagPainter oldDelegate) => false;
}

FontWeight _wishlistFontWeight(String value) {
  switch (int.tryParse(value) ?? 700) {
    case 400:
      return FontWeight.w400;
    case 500:
      return FontWeight.w500;
    case 600:
      return FontWeight.w600;
    case 800:
      return FontWeight.w800;
    default:
      return FontWeight.w700;
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
    required this.instanceId,
    required this.products,
    required this.copy,
    required this.settings,
    required this.horizontalPadding,
    required this.isMutating,
    required this.onRemove,
    this.onProductTap,
  });

  final String instanceId;
  final List<CatalogProduct> products;
  final _WishlistCopy copy;
  final CmsPageComponent settings;
  final double horizontalPadding;
  final bool isMutating;
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
        final double topSpacing = settings
            .number(
              'top_spacing',
              (constraints.maxWidth * 0.05).clamp(18, 24).toDouble(),
            )
            .clamp(0, 48)
            .toDouble();
        final double itemWidth =
            (constraints.maxWidth -
                horizontalPadding * 2 -
                spacing * (columnCount - 1)) /
            columnCount;
        final double inset = settings
            .number('image_inset', 5)
            .clamp(0, 24)
            .toDouble();
        final double imageHeight =
            (itemWidth - inset * 2).clamp(1, double.infinity) /
                settings.number('image_ratio', 1).clamp(0.6, 1.8) +
            inset * 2;
        final double contentHeight = products.fold<double>(0, (
          height,
          product,
        ) {
          final measured = _wishlistContentHeight(
            context,
            settings,
            product,
            itemWidth,
          );
          return measured > height ? measured : height;
        });
        return GridView.builder(
          key: instanceId == 'wishlist_grid'
              ? const Key('wishlist-grid')
              : ValueKey<String>('$instanceId-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.fromSTEB(
            horizontalPadding,
            topSpacing,
            horizontalPadding,
            28,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: imageHeight + contentHeight,
          ),
          itemCount: products.length,
          itemBuilder: (BuildContext context, int index) {
            final CatalogProduct product = products[index];
            return _WishlistProductCard(
              instanceId: instanceId,
              product: product,
              copy: copy,
              settings: settings,
              imageHeight: imageHeight,
              removeEnabled: !isMutating,
              onTap: onProductTap == null ? null : () => onProductTap!(product),
              onRemove: () => onRemove(product),
            );
          },
        );
      },
    );
  }
}

class _WishlistProductCard extends StatelessWidget {
  const _WishlistProductCard({
    required this.instanceId,
    required this.product,
    required this.copy,
    required this.settings,
    required this.removeEnabled,
    required this.onRemove,
    this.imageHeight,
    this.onTap,
  });

  final String instanceId;
  final CatalogProduct product;
  final _WishlistCopy copy;
  final CmsPageComponent settings;
  final bool removeEnabled;
  final VoidCallback onRemove;
  final VoidCallback? onTap;
  final double? imageHeight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String imageUrl = product.primaryImage?.source.toString() ?? '';
    final List<String> imageUrls = _wishlistProductImageUrls(product);
    final String cardStyle = settings.string('card_style', 'outlined');
    final double imageInset = settings
        .number('image_inset', 5)
        .clamp(0, 24)
        .toDouble();
    final double imageRadius = settings
        .number('image_radius', 10)
        .clamp(0, 40)
        .toDouble();
    Widget imageFrame({required Widget child}) => imageHeight == null
        ? Expanded(child: child)
        : SizedBox(height: imageHeight, child: child);
    return Card(
      key: instanceId == 'wishlist_grid'
          ? Key('wishlist-product-${product.id}')
          : ValueKey<String>('wishlist-product-$instanceId-${product.id}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: cardStyle == 'elevated' ? null : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(settings.number('card_radius', 16)),
        side:
            cardStyle == 'outlined' &&
                settings.number('card_outline_width', 1) > 0
            ? BorderSide(
                color:
                    _wishlistHexColor(
                      settings.string('card_outline_color', ''),
                    ) ??
                    colors.primary,
                width: settings
                    .number('card_outline_width', 1)
                    .clamp(0, 6)
                    .toDouble(),
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            imageFrame(
              child: Padding(
                key: ValueKey<String>(
                  'wishlist-image-inset-$instanceId-${product.id}',
                ),
                padding: EdgeInsets.all(imageInset),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (imageUrl.isEmpty)
                        AppNetworkImageError(
                          backgroundColor: colors.surfaceContainerLow,
                        )
                      else
                        ProductImageSwiper(
                          imageUrls: imageUrls,
                          enabled: settings.boolean(
                            'enable_image_swipe',
                            false,
                          ),
                          fit: BoxFit.cover,
                          semanticLabel: product.name,
                        ),
                      _positionedWishlistAction(
                        settings.string('product_wishlist_position', 'top_end'),
                        WishlistRemoveButton(
                          buttonKey: instanceId == 'wishlist_grid'
                              ? Key('wishlist-remove-${product.id}')
                              : ValueKey<String>(
                                  'wishlist-remove-$instanceId-${product.id}',
                                ),
                          settings: settings,
                          tooltip: copy.remove,
                          onPressed: removeEnabled ? onRemove : null,
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
                              iconVariant: settings.string(
                                'quick_add_icon_variant',
                                'bag',
                              ),
                              iconStyle: settings.string(
                                'quick_add_icon_style',
                                'outline',
                              ),
                              iconSize: settings
                                  .number('quick_add_icon_size', 22)
                                  .clamp(10, 36)
                                  .toDouble(),
                              iconColor: _wishlistHexColor(
                                settings.string(
                                  'quick_add_icon_color',
                                  '#1F2933',
                                ),
                              ),
                              showBackground: settings.boolean(
                                'quick_add_show_background',
                                true,
                              ),
                              backgroundColor: _wishlistHexColor(
                                settings.string(
                                  'quick_add_background_color',
                                  '#FFFFFF',
                                ),
                              ),
                              backgroundRadius: settings
                                  .number('quick_add_radius', 24)
                                  .clamp(0, 40)
                                  .toDouble(),
                              backgroundSize: settings
                                  .number('quick_add_background_size', 40)
                                  .clamp(10, 64)
                                  .toDouble(),
                            ),
                          ),
                        ),
                      if (settings.boolean('show_badge', true) &&
                          product.isOnSale)
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
              ),
            ),
            if (settings.boolean('show_name', false) ||
                settings.boolean('show_price', true) ||
                settings.boolean('show_rating', false))
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  settings
                      .number('content_horizontal_padding', 9)
                      .clamp(0, 24)
                      .toDouble(),
                  settings
                      .number('content_top_padding', 5)
                      .clamp(0, 24)
                      .toDouble(),
                  settings
                      .number('content_horizontal_padding', 9)
                      .clamp(0, 24)
                      .toDouble(),
                  settings
                      .number('content_bottom_padding', 9)
                      .clamp(0, 24)
                      .toDouble(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (settings.boolean('show_name', false))
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    if (settings.boolean('show_price', true)) ...<Widget>[
                      if (settings.boolean('show_name', false))
                        const SizedBox(height: 7),
                      _WishlistPrice(
                        money: product.prices,
                        showRegularPrice: settings.boolean(
                          'show_regular_price',
                          true,
                        ),
                        settings: settings,
                      ),
                    ],
                    if (settings.boolean('show_rating', false) &&
                        product.averageRating > 0) ...<Widget>[
                      const SizedBox(height: 5),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(product.averageRating.toStringAsFixed(1)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

double _wishlistContentHeight(
  BuildContext context,
  CmsPageComponent settings,
  CatalogProduct product,
  double cardWidth,
) {
  final theme = Theme.of(context).textTheme;
  final showName = settings.boolean('show_name', false);
  final showPrice = settings.boolean('show_price', true);
  final showRating = settings.boolean('show_rating', false);
  if (!showName && !showPrice && !showRating) return 0;
  final width =
      (cardWidth -
              2 * settings.number('content_horizontal_padding', 9).clamp(0, 24))
          .clamp(1, double.infinity)
          .toDouble();
  Size measure(String text, TextStyle? style, {int? maxLines}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: width);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  double height =
      settings.number('content_top_padding', 5).clamp(0, 24) +
      settings.number('content_bottom_padding', 9).clamp(0, 24);
  if (showName) {
    height += measure(
      product.name,
      theme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
      maxLines: 2,
    ).height;
  }
  if (showPrice) {
    if (showName) height += 7;
    final money = product.prices;
    final current = measure(
      '${settings.string('price_prefix', '')}${money.displayAmount(money.priceMinor)}',
      theme.titleSmall?.copyWith(
        fontSize: settings.number('price_size', 14).clamp(10, 28).toDouble(),
        fontWeight: FontWeight.w900,
      ),
    );
    double priceHeight = current.height;
    final regular = money.displayAmount(money.regularPriceMinor);
    if (settings.boolean('show_regular_price', true) &&
        money.isDiscounted &&
        regular.isNotEmpty) {
      final previous = measure(regular, theme.labelSmall);
      priceHeight = current.width + 7 + previous.width > width
          ? current.height + 3 + previous.height
          : (current.height > previous.height
                ? current.height
                : previous.height);
    }
    height += priceHeight;
  }
  if (showRating && product.averageRating > 0) {
    final ratingHeight = measure(
      product.averageRating.toStringAsFixed(1),
      DefaultTextStyle.of(context).style,
    ).height;
    height += 5 + (ratingHeight > 16 ? ratingHeight : 16);
  }
  return height.ceilToDouble();
}

List<String> _wishlistProductImageUrls(CatalogProduct product) => product.images
    .expand(
      (image) => <String>[
        image.source.toString(),
        if (image.thumbnail != null) image.thumbnail.toString(),
      ],
    )
    .where((String url) => url.isNotEmpty)
    .toSet()
    .toList(growable: false);

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
  const _WishlistPrice({
    required this.money,
    required this.showRegularPrice,
    required this.settings,
  });

  final CatalogMoney money;
  final bool showRegularPrice;
  final CmsPageComponent settings;

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
          '${settings.string('price_prefix', '')}$current',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color:
                _wishlistHexColor(settings.string('price_color', '#1F2933')) ??
                colors.primary,
            fontSize: settings
                .number('price_size', 14)
                .clamp(10, 28)
                .toDouble(),
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
  String get signInTitle =>
      arabic ? 'سجّل الدخول لعرض المفضلة' : 'Sign in to view your wishlist';
  String get signIn => arabic ? 'تسجيل الدخول' : 'Sign In';
  String get recommendations => arabic ? 'قد يعجبك أيضًا' : 'You may also like';
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
