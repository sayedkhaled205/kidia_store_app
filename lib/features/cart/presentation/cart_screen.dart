import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_coupon.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_totals.dart';
import 'package:kidia_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:kidia_store_app/features/cart/presentation/cart_copy.dart';
import 'package:kidia_store_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_money.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

typedef CartCheckoutCallback =
    FutureOr<void> Function(BuildContext context, Cart cart);

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

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CartCopy copy = CartCopy.of(context);
    final AsyncValue<CartViewState> cartState = ref.watch(
      cartControllerProvider,
    );
    final CartViewState? current = cartState.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        actions: <Widget>[
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
              cart: current.cart,
              copy: copy,
              enabled: !current.hasPendingMutation,
              onCheckout: () => _checkout(current.cart),
            ),
    );
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
      if (widget.onCheckout != null) {
        await widget.onCheckout!(context, cart);
        return;
      }

      final String route = widget.checkoutRoute?.trim() ?? '';
      if (route.isNotEmpty) {
        await context.push<void>(route);
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
    if (cart.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _CartEmpty(copy: copy),
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
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      12,
                    ),
                    child: _CartItemCard(
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
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
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
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
                  child: _OrderSummary(cart: cart, copy: copy),
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
    required this.item,
    required this.copy,
    required this.pending,
    required this.mutationsEnabled,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  final CartItem item;
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
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(
                dimension: 96,
                child: image == null
                    ? const AppNetworkImageError()
                    : AppNetworkImage(
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
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
                  if (item.lowStockRemaining != null || item.showBackorderBadge)
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
              label: copy.subtotal,
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
            if (cartMinorIsPositive(totals.feesMinor))
              _SummaryRow(
                label: copy.fees,
                value: formatCartMoney(totals.feesMinor, totals.currency),
              ),
            if (cartMinorIsPositive(totals.taxMinor))
              _SummaryRow(
                label: copy.tax,
                value: formatCartMoney(totals.taxMinor, totals.currency),
              ),
            const Divider(height: 24),
            _SummaryRow(
              label: copy.total,
              value: formatCartMoney(totals.priceMinor, totals.currency),
              isTotal: true,
            ),
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
    required this.cart,
    required this.copy,
    required this.enabled,
    required this.onCheckout,
  });

  final Cart cart;
  final CartCopy copy;
  final bool enabled;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Material(
      elevation: 12,
      color: colors.surface,
      surfaceTintColor: colors.surfaceTint,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Row(
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
                FilledButton.icon(
                  key: const Key('checkout-button'),
                  onPressed: enabled ? onCheckout : null,
                  icon: const Icon(Icons.lock_outline_rounded, size: 19),
                  label: Text(copy.checkout),
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
  const _CartEmpty({required this.copy});

  final CartCopy copy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 52,
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
