import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/live_updates/store_change_bus.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/analytics/mobile_analytics.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/odoo_customer_providers51.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:mobishop_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';

class CartViewState {
  CartViewState({
    required this.cart,
    Set<String> pendingItemKeys = const <String>{},
    this.isCouponPending = false,
    this.isAddingItem = false,
    this.isRefreshing = false,
    this.lastErrorMessage,
  }) : pendingItemKeys = Set<String>.unmodifiable(pendingItemKeys);

  final Cart cart;
  final Set<String> pendingItemKeys;
  final bool isCouponPending;
  final bool isAddingItem;
  final bool isRefreshing;
  final String? lastErrorMessage;

  bool get hasPendingMutation =>
      pendingItemKeys.isNotEmpty || isCouponPending || isAddingItem;

  CartViewState copyWith({
    Cart? cart,
    Set<String>? pendingItemKeys,
    bool? isCouponPending,
    bool? isAddingItem,
    bool? isRefreshing,
    Object? lastErrorMessage = _notProvided,
  }) {
    return CartViewState(
      cart: cart ?? this.cart,
      pendingItemKeys: pendingItemKeys ?? this.pendingItemKeys,
      isCouponPending: isCouponPending ?? this.isCouponPending,
      isAddingItem: isAddingItem ?? this.isAddingItem,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastErrorMessage: identical(lastErrorMessage, _notProvided)
          ? this.lastErrorMessage
          : lastErrorMessage as String?,
    );
  }
}

const Object _notProvided = Object();

class CartController extends AsyncNotifier<CartViewState> {
  int _mutationRevision = 0;
  CartRepository get _repository => ref.read(cartRepositoryProvider);

  @override
  Future<CartViewState> build() async {
    if (AppConfig.commercePlatform == CommercePlatform.odoo) {
      await ref.watch(odooCustomerSession51Provider.future);
      if (!ref.mounted) throw StateError('Shopping session ended.');
    }
    final String ownerToken = _authToken;
    final Cart cart = await ref.watch(cartRepositoryProvider).getCart();
    if (!ref.mounted || ownerToken != _authToken) {
      throw const CartRepositoryException(
        kind: CartFailureKind.unauthorized,
        message: 'The customer session changed.',
      );
    }
    _captureCart(cart);
    return CartViewState(cart: cart);
  }

  Future<void> retry() async {
    final String ownerToken = _authToken;
    state = const AsyncLoading<CartViewState>();
    final result = await AsyncValue.guard<CartViewState>(build);
    if (ref.mounted && ownerToken == _authToken) state = result;
  }

  Future<void> refreshCart() async {
    final revision = _mutationRevision;
    final CartViewState? current = state.asData?.value;
    if (current == null) {
      await retry();
      return;
    }
    if (current.hasPendingMutation || current.isRefreshing) {
      return;
    }
    final String ownerToken = _authToken;

    state = AsyncData<CartViewState>(
      current.copyWith(isRefreshing: true, lastErrorMessage: null),
    );
    try {
      final Cart cart = await _repository.getCart();
      if (!ref.mounted || ownerToken != _authToken || revision != _mutationRevision) {
        return;
      }
      _captureCart(cart);
      state = AsyncData<CartViewState>(
        CartViewState(cart: cart, isRefreshing: false),
      );
    } catch (error) {
      if (!ref.mounted || ownerToken != _authToken || revision != _mutationRevision) return;
      final CartRepositoryException failure = _failure(error);
      state = AsyncData<CartViewState>(
        current.copyWith(
          cart: failure.serverCart ?? current.cart,
          isRefreshing: false,
          lastErrorMessage: failure.message,
        ),
      );
    }
  }

  Future<CartActionResult> updateQuantity(CartItem item, int quantity) async {
    if (!item.quantityLimits.accepts(quantity)) {
      return const CartActionResult.failure(
        'This quantity is not available for the selected product.',
      );
    }
    return _mutateItem(
      item.key,
      () => _repository.updateItem(key: item.key, quantity: quantity),
      eventName: quantity < item.quantity ? 'remove_from_cart' : 'add_to_cart',
      objectId: item.productId,
      label: item.name,
    );
  }

  Future<CartActionResult> removeItem(String key) {
    final CartItem? item = _itemForKey(key);
    return _mutateItem(
      key,
      () => _repository.removeItem(key),
      eventName: 'remove_from_cart',
      objectId: item?.productId ?? 0,
      label: item?.name ?? '',
    );
  }

  Future<CartActionResult> applyCoupon(String code) {
    return _mutateCoupon(() => _repository.applyCoupon(code));
  }

  Future<CartActionResult> removeCoupon(String code) {
    return _mutateCoupon(() => _repository.removeCoupon(code));
  }

  Future<CartActionResult> addSelection(ProductPurchaseSelection selection) {
    return _mutate(
      operation: () => _repository.addItem(
        productId: selection.productId,
        quantity: selection.quantity,
        variation: selection.variation,
      ),
      addingItem: true,
      eventName: 'add_to_cart',
      objectId: selection.productId,
    );
  }

  void clearActionError() {
    final CartViewState? current = state.asData?.value;
    if (current == null || current.lastErrorMessage == null) {
      return;
    }
    state = AsyncData<CartViewState>(current.copyWith(lastErrorMessage: null));
  }

  Future<CartActionResult> _mutateItem(
    String key,
    Future<Cart> Function() operation, {
    String eventName = 'cart_updated',
    int objectId = 0,
    String label = '',
  }) {
    return _mutate(
      operation: operation,
      itemKey: key,
      eventName: eventName,
      objectId: objectId,
      label: label,
    );
  }

  Future<CartActionResult> _mutateCoupon(Future<Cart> Function() operation) {
    return _mutate(operation: operation, couponPending: true);
  }

  Future<CartActionResult> _mutate({
    required Future<Cart> Function() operation,
    String? itemKey,
    bool couponPending = false,
    bool addingItem = false,
    String eventName = 'cart_updated',
    int objectId = 0,
    String label = '',
  }) async {
    final String requestedOwner = _authToken;
    if (state.asData == null) {
      try {
        // Share the in-flight bootstrap. Never replay a cart mutation or create
        // a second cart request just because the first product was tapped early.
        await future;
      } catch (error) {
        return CartActionResult.failure(_failure(error).message);
      }
    }
    if (!ref.mounted || requestedOwner != _authToken) {
      return const CartActionResult.failure('The customer session changed.');
    }
    final CartViewState? current = state.asData?.value;
    if (current == null) {
      return const CartActionResult.failure(
        'Unable to load the cart. Please retry from your bag.',
      );
    }
    if (current.hasPendingMutation) {
      return const CartActionResult.failure(
        'Please wait for the current cart update to finish.',
      );
    }
    final String ownerToken = _authToken;

    _mutationRevision++;
    state = AsyncData<CartViewState>(
      current.copyWith(
        pendingItemKeys: itemKey == null ? const <String>{} : <String>{itemKey},
        isCouponPending: couponPending,
        isAddingItem: addingItem,
        lastErrorMessage: null,
      ),
    );

    try {
      final Cart cart = await operation();
      if (!ref.mounted || ownerToken != _authToken) {
        return const CartActionResult.failure('The customer session changed.');
      }
      state = AsyncData<CartViewState>(CartViewState(cart: cart));
      final String token = _authToken;
      if (AppConfig.commercePlatform == CommercePlatform.wooCommerce) {
        ref
            .read(mobileAnalyticsProvider)
            .trackInBackground(
              eventName,
              objectId: objectId,
              label: label,
              authToken: token,
            );
      }
      _captureCart(cart);
      return const CartActionResult.success();
    } catch (error) {
      if (!ref.mounted || ownerToken != _authToken) {
        return const CartActionResult.failure('The customer session changed.');
      }
      final CartRepositoryException failure = _failure(error);
      Cart reconciledCart = failure.serverCart ?? current.cart;
      if ((failure.apiError?.code ?? '').contains('stock')) {
        // A rejected add is never replayed. Re-read the customer's actual basket
        // and invalidate public stock snapshots after the purchase callback ends.
        try {
          reconciledCart = await _repository.getCart();
        } catch (_) {
          // Keep the last authoritative snapshot and original stock rejection.
        }
        if (!ref.mounted || ownerToken != _authToken) {
          return const CartActionResult.failure('The customer session changed.');
        }
        Future<void>(() {
          if (ref.mounted && ownerToken == _authToken) {
            ref.read(storeCatalogChangeBusProvider).notifyCatalogChanged();
          }
        });
      }
      state = AsyncData<CartViewState>(
        CartViewState(
          cart: reconciledCart,
          lastErrorMessage: failure.message,
        ),
      );
      return CartActionResult.failure(failure.message);
    }
  }

  CartRepositoryException _failure(Object error) {
    if (error is CartRepositoryException) {
      return error;
    }
    return CartRepositoryException(
      kind: CartFailureKind.unknown,
      message: 'The cart request failed unexpectedly.',
      cause: error,
    );
  }

  CartItem? _itemForKey(String key) {
    final CartViewState? current = state.asData?.value;
    if (current == null) return null;
    for (final CartItem item in current.cart.items) {
      if (item.key == key) return item;
    }
    return null;
  }

  String get _authToken {
    if (AppConfig.commercePlatform == CommercePlatform.odoo) {
      final client = ref.read(odooCustomerClient51Provider);
      return 'odoo:${client.sessionEpoch85}:${client.customer?.id ?? 0}';
    }
    if (AppConfig.commercePlatform == CommercePlatform.shopify) {
      // An opaque local owner generation, never the buyer secret or a Woo
      // session. Customer Account auth remains unsupported, not impersonated.
      final session = ref.read(shopifyBuyerCartSessionProvider);
      return 'shopify-guest:${session.generation}';
    }
    AppConfig.requireWooCommerceCustomerTransport('cart');
    final session = ref.read(authControllerProvider).value;
    return session == null || session.isExpired ? '' : session.token;
  }

  void _captureCart(Cart cart) {
    if (AppConfig.commercePlatform != CommercePlatform.wooCommerce) return;
    ref
        .read(mobileAnalyticsProvider)
        .captureCartInBackground(cart, authToken: _authToken);
  }
}
