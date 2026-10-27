import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_coupon.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_totals.dart';
import 'package:mobishop_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:mobishop_store_app/features/cart/presentation/cart_appearance.dart';
import 'package:mobishop_store_app/features/cart/presentation/cart_copy.dart';
import 'package:mobishop_store_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/widgets/cart_money.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

import 'package:mobishop_store_app/features/page_builder/presentation/providers/compact_family_provider.dart';

typedef CartCheckoutCallback =
    FutureOr<void> Function(BuildContext context, Cart cart);

final shopifyCheckoutLauncher297Provider = Provider<Future<bool> Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key, this.onCheckout, this.checkoutRoute});

  /// Checkout integration supplied by the application shell.
  ///
  /// This cart does not claim that checkout is complete. A shell can either
  /// inject this callback or provide [checkoutRoute] when that flow exists.
  final CartCheckoutCallback? onCheckout;
  final String? checkoutRoute;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  bool _compactFamily = false;

  @override
  void initState() {
    super.initState();
    // The retained account CMS graph can be stale when this route first opens.
    // Subscribe outside build so flushing it cannot schedule the ancestor
    // ProviderScope during CartScreen.build. Riverpod closes this on disposal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(compactFamilyProvider, (previous, next) {
        if (!mounted || _compactFamily == next) return;
        setState(() => _compactFamily = next);
      }, fireImmediately: true);
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CartCopy copy = CartCopy.of(context);
    final CartAppearance appearance = CartAppearance.of(context);
    final bool flat = switch (appearance.layout) {
      CartLayout.classic => false,
      CartLayout.compact => true,
      CartLayout.theme => _compactFamily,
    };
    final AsyncValue<CartViewState> cartState = ref.watch(
      cartControllerProvider,
    );
    final CartViewState? current = cartState.asData?.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: flat ? Colors.white : null,
        appBar: AppBar(
          centerTitle: flat ? true : null,
          elevation: flat ? 0 : null,
          backgroundColor: flat ? Colors.white : null,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            flat
                ? '${copy.compactTitle}${current == null || current.cart.isEmpty ? '' : ' (${current.cart.itemsCount})'}'
                : copy.title,
          ),
          actions: <Widget>[
            if (flat)
              IconButton(
                tooltip: copy.isArabic ? 'المفضلة' : 'Wishlist',
                onPressed: () => context.push('/wishlist'),
                icon: const Icon(Icons.favorite_border_rounded),
              ),
            if (!flat)
              IconButton(
                key: const Key('cart-refresh-button'),
                tooltip: copy.refresh,
                onPressed:
                    current == null ||
                        current.isRefreshing ||
                        current.hasPendingMutation
                    ? null
                    : ref.read(cartControllerProvider.notifier).refreshCart,
                icon: current?.isRefreshing == true
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: cartState.when(
          loading: () => _CartLoading(copy: copy),
          error: (Object error, StackTrace stackTrace) => _CartLoadError(
            copy: copy,
            onRetry: ref.read(cartControllerProvider.notifier).retry,
          ),
          data: (CartViewState state) => _CartLoadedBody(
            flat: flat,
            appearance: appearance,
            state: state,
            copy: copy,
            couponController: _couponController,
            onRefresh: ref.read(cartControllerProvider.notifier).refreshCart,
            onUpdateQuantity: _updateQuantity,
            onRemove: _confirmRemove,
            onApplyCoupon: _applyCoupon,
            onRemoveCoupon: _removeCoupon,
            onDismissError: ref
                .read(cartControllerProvider.notifier)
                .clearActionError,
          ),
        ),
        bottomNavigationBar: current == null || current.cart.isEmpty
            ? null
            : _CartCheckoutBar(
                flat: flat,
                appearance: appearance,
                cart: current.cart,
                copy: copy,
                enabled: !current.hasPendingMutation,
                onCheckout: () => _checkout(current.cart),
              ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _updateQuantity(CartItem item, int quantity) async {
    final CartActionResult result = await ref
        .read(cartControllerProvider.notifier)
        .updateQuantity(item, quantity);
    if (!mounted) {
      return;
    }
    _showFailure(result);
  }

  Future<void> _confirmRemove(CartItem item) async {
    final CartCopy copy = CartCopy.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(copy.removeTitle),
          content: Text(copy.removeMessage(item.name)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(copy.cancel),
            ),
            FilledButton.tonal(
              key: const Key('confirm-remove-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(copy.remove),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final CartActionResult result = await ref
        .read(cartControllerProvider.notifier)
        .removeItem(item.key);
    if (!mounted) {
      return;
    }
    if (result.succeeded) {
      _showMessage(copy.removed);
    } else {
      _showFailure(result);
    }
  }

  Future<void> _applyCoupon() async {
    final CartCopy copy = CartCopy.of(context);
    final String code = _couponController.text.trim();
    if (code.isEmpty) {
      _showMessage(copy.couponRequired);
      return;
    }

    final CartActionResult result = await ref
        .read(cartControllerProvider.notifier)
        .applyCoupon(code);
    if (!mounted) {
      return;
    }
    if (result.succeeded) {
      _couponController.clear();
      FocusScope.of(context).unfocus();
    } else {
      _showFailure(result);
    }
  }

  Future<void> _removeCoupon(String code) async {
    final CartActionResult result = await ref
        .read(cartControllerProvider.notifier)
        .removeCoupon(code);
    if (!mounted) {
      return;
    }
    _showFailure(result);
  }

  Future<void> _checkout(Cart cart) async {
    final CartCopy copy = CartCopy.of(context);
    try {
      if (AppConfig.commercePlatform == CommercePlatform.shopify) {
        final Uri? checkout = cart.checkoutUrl;
        if (checkout == null) {
          _showMessage(copy.checkoutUnavailable);
          return;
        }
        await ref.read(shopifyCheckoutPolicy297Provider).verify(checkout);
        if (!mounted) return;
        // Only this explicit buyer tap hands off to Shopify's hosted checkout.
        // No background redirect, checkout completion, order or payment call.
        if (!await ref.read(shopifyCheckoutLauncher297Provider)(checkout) &&
            mounted) {
          _showMessage(copy.checkoutUnavailable);
        }
        return;
      }
      if (AppConfig.commercePlatform != CommercePlatform.odoo) {
        AppConfig.requireWooCommerceCustomerTransport('checkout');
      }
      if (widget.onCheckout != null) {
        await widget.onCheckout!(context, cart);
        if (mounted) {
          await ref.read(cartControllerProvider.notifier).refreshCart();
        }
        return;
      }

      final String route = widget.checkoutRoute?.trim() ?? '';
      if (route.isNotEmpty) {
        await context.push<void>(route);
        if (mounted) {
          await ref.read(cartControllerProvider.notifier).refreshCart();
        }
        return;
      }
      _showMessage(copy.checkoutUnavailable);
    } catch (_) {
      if (mounted) {
        _showMessage(copy.checkoutUnavailable);
      }
    }
  }

  void _showFailure(CartActionResult result) {
    if (result.succeeded) {
      return;
    }
    _showMessage(result.message ?? CartCopy.of(context).loadFailed);
    ref.read(cartControllerProvider.notifier).clearActionError();
  }

  void _showMessage(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CartLoadedBody extends StatelessWidget {
  const _CartLoadedBody({
    this.flat = false,
    required this.appearance,
    required this.state,
    required this.copy,
    required this.couponController,
    required this.onRefresh,
    required this.onUpdateQuantity,
    required this.onRemove,
    required this.onApplyCoupon,
    required this.onRemoveCoupon,
    required this.onDismissError,
  });

  final CartViewState state;
  final bool flat;
  final CartAppearance appearance;
  final CartCopy copy;
  final TextEditingController couponController;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CartItem item, int quantity) onUpdateQuantity;
  final Future<void> Function(CartItem item) onRemove;
  final Future<void> Function() onApplyCoupon;
  final Future<void> Function(String code) onRemoveCoupon;
  final VoidCallback onDismissError;

  @override
  Widget build(BuildContext context) {
    final Cart cart = state.cart;
    final double sidePadding = appearance.sidePadding(fallback: 16);
    if (cart.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _CartEmpty(copy: copy, flat: flat, appearance: appearance),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const Key('cart-items-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    sidePadding,
                    12,
                    sidePadding,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (!flat || state.isRefreshing)
                        Row(
                          children: <Widget>[
                            Text(
                              copy.itemCount(cart.itemsCount),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (state.isRefreshing) ...<Widget>[
                              const SizedBox(width: 10),
                              const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (state.lastErrorMessage != null) ...<Widget>[
                        const SizedBox(height: 12),
                        _CartInlineError(
                          message: state.lastErrorMessage!,
                          onDismiss: onDismissError,
                        ),
                      ],
                      if (cart.errors.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        for (final error in cart.errors)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CartInlineError(message: error.message),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: cart.items.length,
            itemBuilder: (BuildContext context, int index) {
              final CartItem item = cart.items[index];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      sidePadding,
                      0,
                      sidePadding,
                      appearance.itemGap(fallback: 12),
                    ),
                    child: _CartItemCard(
                      flat: flat,
                      appearance: appearance,
                      item: item,
                      copy: copy,
                      pending: state.pendingItemKeys.contains(item.key),
                      mutationsEnabled: !state.hasPendingMutation,
                      onUpdateQuantity: (int quantity) =>
                          onUpdateQuantity(item, quantity),
                      onRemove: () => onRemove(item),
                    ),
                  ),
                ),
              );
            },
          ),
          if (AppConfig.commercePlatform != CommercePlatform.odoo)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      sidePadding,
                      4,
                      sidePadding,
                      12,
                    ),
                    child: _OptionalCartDetails(
                      compact: flat,
                      display: appearance.couponDisplay,
                      sectionKey: 'cart-coupon',
                      title: copy.isArabic ? 'كود الخصم' : 'Promo code',
                      child: _CouponCard(
                        coupons: cart.coupons,
                        controller: couponController,
                        copy: copy,
                        pending: state.isCouponPending,
                        enabled: !state.hasPendingMutation,
                        onApply: onApplyCoupon,
                        onRemove: onRemoveCoupon,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    sidePadding,
                    0,
                    sidePadding,
                    28,
                  ),
                  child: _OptionalCartDetails(
                    compact: flat,
                    display: appearance.summaryDisplay,
                    sectionKey: 'cart-summary',
                    title: copy.isArabic ? 'تفاصيل الإجمالي' : 'Order details',
                    child: _OrderSummary(cart: cart, copy: copy),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    this.flat = false,
    required this.appearance,
    required this.item,
    required this.copy,
    required this.pending,
    required this.mutationsEnabled,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  final CartItem item;
  final bool flat;
  final CartAppearance appearance;
  final CartCopy copy;
  final bool pending;
  final bool mutationsEnabled;
  final ValueChanged<int> onUpdateQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final CartItemImage? image = item.images.isEmpty ? null : item.images.first;
    final int step = item.quantityLimits.multipleOf > 0
        ? item.quantityLimits.multipleOf
        : 1;
    final int lowerQuantity = item.quantity - step;
    final int upperQuantity = item.quantity + step;
    final bool canDecrease =
        mutationsEnabled && item.quantityLimits.accepts(lowerQuantity);
    final bool canIncrease =
        mutationsEnabled && item.quantityLimits.accepts(upperQuantity);
    final String variations = item.variation
        .map((CartItemVariation value) => '${value.attribute}: ${value.value}')
        .join(' • ');

    return Card(
      key: ValueKey<String>('cart-item-${item.key}'),
      elevation: flat ? 0 : null,
      shape: flat ? const RoundedRectangleBorder() : null,
      margin: flat ? EdgeInsets.zero : null,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: flat
            ? const EdgeInsets.symmetric(vertical: 12)
            : const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Leave room for quantity controls when a merchant enlarges images.
            final available = (constraints.maxWidth - 162).clamp(0.0, 112.0);
            final imageWidth = appearance
                .itemImageWidth(fallback: flat ? 92 : 96)
                .clamp(0.0, available);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    appearance.itemImageRadius(fallback: flat ? 8 : 14),
                  ),
                  child: SizedBox(
                    width: imageWidth,
                    height: appearance.itemImageHeight(
                      fallback: flat ? 124 : 96,
                    ),
                    child: image == null
                        ? const AppNetworkImageError()
                        : AppNetworkImage(
                            fit: BoxFit.cover,
                            imageUrl: image.thumbnailUrl.isNotEmpty
                                ? image.thumbnailUrl
                                : image.sourceUrl,
                            semanticLabel: image.alt.isNotEmpty
                                ? image.alt
                                : item.name,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: appearance.itemNameLines(
                                fallback: flat ? 1 : 2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: appearance.itemNameSize,
                                fontWeight: flat
                                    ? FontWeight.w400
                                    : FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          IconButton(
                            key: ValueKey<String>('remove-${item.key}'),
                            tooltip: copy.remove,
                            visualDensity: VisualDensity.compact,
                            onPressed: mutationsEnabled ? onRemove : null,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      if (variations.isNotEmpty)
                        Text(
                          variations,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      if (item.lowStockRemaining != null ||
                          item.showBackorderBadge)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            copy.lowStock,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        '${formatCartMoney(item.prices.priceMinor, item.prices.currency)} ${copy.each}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: <Widget>[
                          _QuantityStepper(
                            itemKey: item.key,
                            quantity: item.quantity,
                            copy: copy,
                            pending: pending,
                            canDecrease: canDecrease,
                            canIncrease: canIncrease,
                            onDecrease: () => onUpdateQuantity(lowerQuantity),
                            onIncrease: () => onUpdateQuantity(upperQuantity),
                          ),
                          Text(
                            formatCartMoney(
                              item.totals.totalMinor,
                              item.totals.currency,
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.itemKey,
    required this.quantity,
    required this.copy,
    required this.pending,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String itemKey;
  final int quantity;
  final CartCopy copy;
  final bool pending;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      label: copy.quantity(quantity),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: ValueKey<String>('decrease-$itemKey'),
              tooltip: copy.decreaseQuantity,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 38, height: 40),
              onPressed: pending || !canDecrease ? null : onDecrease,
              icon: const Icon(Icons.remove_rounded, size: 20),
            ),
            SizedBox(
              width: 36,
              child: Center(
                child: pending
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '$quantity',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            IconButton(
              key: ValueKey<String>('increase-$itemKey'),
              tooltip: copy.increaseQuantity,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 38, height: 40),
              onPressed: pending || !canIncrease ? null : onIncrease,
              icon: const Icon(Icons.add_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupons,
    required this.controller,
    required this.copy,
    required this.pending,
    required this.enabled,
    required this.onApply,
    required this.onRemove,
  });

  final List<CartCoupon> coupons;
  final TextEditingController controller;
  final CartCopy copy;
  final bool pending;
  final bool enabled;
  final VoidCallback onApply;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.local_offer_outlined, size: 21),
                const SizedBox(width: 8),
                Text(
                  copy.couponTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('coupon-field'),
                    controller: controller,
                    enabled: enabled,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(hintText: copy.couponHint),
                    onSubmitted: enabled ? (_) => onApply() : null,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonal(
                  key: const Key('apply-coupon-button'),
                  onPressed: enabled ? onApply : null,
                  child: pending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(copy.apply),
                ),
              ],
            ),
            if (coupons.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final CartCoupon coupon in coupons)
                    InputChip(
                      key: ValueKey<String>('coupon-${coupon.code}'),
                      avatar: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(coupon.code),
                      onDeleted: enabled ? () => onRemove(coupon.code) : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart, required this.copy});

  final Cart cart;
  final CartCopy copy;

  @override
  Widget build(BuildContext context) {
    final CartTotals totals = cart.totals;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              copy.orderSummary,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              label: totals.subtotalEstimated
                  ? copy.estimatedSubtotal
                  : copy.subtotal,
              value: formatCartMoney(totals.itemsMinor, totals.currency),
            ),
            if (cartMinorIsPositive(totals.discountMinor))
              _SummaryRow(
                label: copy.discount,
                value:
                    '-${formatCartMoney(totals.discountMinor, totals.currency)}',
                emphasized: true,
              ),
            if (cart.needsShipping)
              _SummaryRow(
                label: copy.shipping,
                value: cart.hasCalculatedShipping
                    ? formatCartMoney(totals.shippingMinor, totals.currency)
                    : copy.shippingAtCheckout,
              ),
            if ((BigInt.tryParse(totals.feesMinor) ?? BigInt.zero) !=
                BigInt.zero)
              _SummaryRow(
                label: totals.feesMinor.startsWith('-')
                    ? copy.discount
                    : copy.fees,
                value: formatCartMoney(totals.feesMinor, totals.currency),
                emphasized: totals.feesMinor.startsWith('-'),
              ),
            if (cartMinorIsPositive(totals.taxMinor))
              _SummaryRow(
                label: copy.tax,
                value: formatCartMoney(totals.taxMinor, totals.currency),
              ),
            const Divider(height: 24),
            _SummaryRow(
              label: totals.totalEstimated ? copy.estimatedTotal : copy.total,
              value: formatCartMoney(totals.priceMinor, totals.currency),
              isTotal: true,
            ),
            if (cart.checkoutUrl != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                copy.shopifyFinalPrice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: isTotal
                  ? theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            textAlign: TextAlign.end,
            style: isTotal
                ? theme.textTheme.titleLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    color: emphasized ? colors.primary : null,
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CartCheckoutBar extends StatelessWidget {
  const _CartCheckoutBar({
    this.flat = false,
    required this.appearance,
    required this.cart,
    required this.copy,
    required this.enabled,
    required this.onCheckout,
  });

  final Cart cart;
  final bool flat;
  final CartAppearance appearance;
  final CartCopy copy;
  final bool enabled;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final height = appearance.checkoutButtonHeight;
    final radius = appearance.checkoutButtonRadius;
    final fontSize = appearance.checkoutButtonFontSize;
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: height != null
          ? Size(0, height)
          : flat
          ? const Size.fromHeight(50)
          : null,
      shape: radius != null
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius))
          : flat
          ? const StadiumBorder()
          : null,
      textStyle: fontSize == null
          ? null
          : theme.textTheme.labelLarge?.copyWith(fontSize: fontSize),
    );
    final sidePadding = appearance.sidePadding(fallback: 16);
    return Material(
      elevation: flat ? 0 : 12,
      color: colors.surface,
      surfaceTintColor: colors.surfaceTint,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(sidePadding, 10, sidePadding, 10),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: flat
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryRow(
                        label: cart.totals.totalEstimated
                            ? copy.estimatedTotal
                            : copy.total,
                        value: formatCartMoney(
                          cart.totals.priceMinor,
                          cart.totals.currency,
                        ),
                        isTotal: true,
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const Key('checkout-button'),
                        style: buttonStyle,
                        onPressed: enabled ? onCheckout : null,
                        child: Text(copy.checkout),
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              copy.total,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              formatCartMoney(
                                cart.totals.priceMinor,
                                cart.totals.currency,
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 2,
                        child: FilledButton.icon(
                          key: const Key('checkout-button'),
                          style: buttonStyle,
                          onPressed: enabled ? onCheckout : null,
                          icon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 19,
                          ),
                          label: Text(copy.checkout),
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

class _CartLoading extends StatelessWidget {
  const _CartLoading({required this.copy});

  final CartCopy copy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      label: copy.loading,
      child: ListView.separated(
        key: const Key('cart-loading'),
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          return Container(
            height: 132,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }
}

class _CartLoadError extends StatelessWidget {
  const _CartLoadError({required this.copy, required this.onRetry});

  final CartCopy copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              copy.loadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('cart-retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(copy.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartEmpty extends StatelessWidget {
  const _CartEmpty({
    required this.copy,
    required this.appearance,
    this.flat = false,
  });

  final CartCopy copy;
  final bool flat;
  final CartAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    if (flat) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            appearance.emptyTopSpacing(fallback: 72),
            24,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: appearance.emptyIconSize(fallback: 100),
                color: const Color(0xFFE8E8E8),
              ),
              const SizedBox(height: 30),
              Text(
                copy.emptyTitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                key: const Key('cart-go-shopping'),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size(132, 48),
                ),
                onPressed: () => context.go('/'),
                child: Text(copy.isArabic ? 'ابدأ التسوق' : 'Go Shopping'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          appearance.emptyTopSpacing(fallback: 28),
          28,
          28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: appearance.emptyIconSize(fallback: 52) + 60,
              height: appearance.emptyIconSize(fallback: 52) + 60,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: appearance.emptyIconSize(fallback: 52),
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              copy.emptyTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              copy.emptyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartInlineError extends StatelessWidget {
  const _CartInlineError({required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
                color: colors.onErrorContainer,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionalCartDetails extends StatelessWidget {
  const _OptionalCartDetails({
    required this.compact,
    required this.display,
    required this.sectionKey,
    required this.title,
    required this.child,
  });
  final bool compact;
  final CartSectionDisplay display;
  final String sectionKey;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      (compact || display != CartSectionDisplay.theme)
      ? ExpansionTile(
          key: ValueKey('$sectionKey-${display.name}'),
          initiallyExpanded: display == CartSectionDisplay.expanded,
          maintainState: true,
          title: Text(title, style: const TextStyle(fontSize: 14)),
          tilePadding: EdgeInsets.zero,
          children: [child],
        )
      : child;
}
