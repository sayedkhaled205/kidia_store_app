import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:kidia_store_app/features/cart/presentation/controllers/cart_controller.dart';

final cartControllerProvider =
    AsyncNotifierProvider<CartController, CartViewState>(
      CartController.new,
      // The screen exposes explicit retry/refresh actions. Automatically
      // replaying cart requests can hide actionable errors and is especially
      // undesirable around commerce state.
      retry: (int retryCount, Object error) => null,
    );

/// Total line-item quantity for a shell/navigation badge.
///
/// The previous count remains available while a pull-to-refresh is running
/// because refreshes are represented inside [CartViewState].
final cartBadgeCountProvider = Provider<int>((Ref ref) {
  return ref.watch(cartControllerProvider).asData?.value.cart.itemsCount ?? 0;
});

/// Stable adapter that product-details screens can consume without knowing
/// about cart repositories, Store API tokens, or presentation state.
final addProductPurchaseSelectionProvider =
    Provider<AddProductPurchaseSelection>((Ref ref) {
      return ref.read(cartControllerProvider.notifier).addSelection;
    });
