import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:mobishop_store_app/features/cart/presentation/controllers/cart_controller.dart';

// A basket belongs to the app/customer session, not whichever page happens to
// watch it. Product callbacks may run with no mounted cart screen or badge.
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
final cartBadgeCountProvider = Provider.autoDispose<int>((Ref ref) {
  if (!AppConfig.isCmsPreview && AppConfig.commercePlatform == CommercePlatform.odoo) return 0;
  return ref.watch(cartControllerProvider).asData?.value.cart.itemsCount ?? 0;
});

/// Stable adapter that product-details screens can consume without knowing
/// about cart repositories, Store API tokens, or presentation state.
final addProductPurchaseSelectionProvider =
    Provider<AddProductPurchaseSelection>((Ref ref) {
      // Resolve at tap time: checkout and authentication can invalidate the
      // controller while a product page still holds this callback.
      return (selection) {
        if (!ref.mounted) {
          return Future.value(
            const CartActionResult.failure(
              'This shopping session has ended. Please reopen the app.',
            ),
          );
        }
        return ref
            .read(cartControllerProvider.notifier)
            .addSelection(selection);
      };
    });
