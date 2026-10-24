import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:mobishop_store_app/features/cart/presentation/controllers/cart_controller.dart';
import '../../../auth/presentation/providers/odoo_customer_providers51.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';

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
  return ref.watch(cartControllerProvider).asData?.value.cart.itemsCount ?? 0;
});

/// Stable adapter that product-details screens can consume without knowing
/// about cart repositories, Store API tokens, or presentation state.
final addProductPurchaseSelectionProvider =
    Provider<AddProductPurchaseSelection>((Ref ref) {
      // Resolve at tap time: checkout and authentication can invalidate the
      // controller while a product page still holds this callback.
      return (selection) async {
        if (!ref.mounted) {
          return Future.value(
            const CartActionResult.failure(
              'This shopping session has ended. Please reopen the app.',
            ),
          );
        }
        if (AppConfig.commercePlatform == CommercePlatform.odoo) {
          try {
            await ref.read(odooCustomerSession51Provider.future);
            if (!ref.mounted) {
              return const CartActionResult.failure('Shopping session ended.');
            }
            final client = ref.read(odooCustomerClient51Provider);
            final epoch = client.sessionEpoch85;
            final uid = client.customer?.id;
            final templateId = selection.catalogProductId;
            if (templateId == null) {
              return const CartActionResult.failure(
                'Please reopen this product.',
              );
            }
            final variants = await ref
                .read(catalogRepositoryProvider)
                .getVariations(templateId);
            if (!ref.mounted ||
                epoch != client.sessionEpoch85 ||
                uid != client.customer?.id) {
              return const CartActionResult.failure(
                'The customer session changed.',
              );
            }
            final candidates = variants
                .where(
                  (v) =>
                      v.isPurchasable &&
                      v.isInStock &&
                      (selection.variantId == null ||
                          v.id == selection.variantId),
                )
                .toList();
            if (candidates.length != 1) {
              return const CartActionResult.failure(
                'Choose the product options first.',
              );
            }
            selection = ProductPurchaseSelection(
              productId: candidates.single.id,
              quantity: selection.quantity,
              variation: selection.variation,
            );
          } catch (_) {
            return const CartActionResult.failure(
              'Unable to verify this product. Please retry.',
            );
          }
        }
        return ref
            .read(cartControllerProvider.notifier)
            .addSelection(selection);
      };
    });
