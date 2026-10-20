import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/app/hosted_commerce_screen297.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_payment_controller298.dart';
import 'package:mobishop_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:mobishop_store_app/features/orders/presentation/providers/customer_orders_providers.dart';

final checkoutPaymentController298Provider = Provider.autoDispose
    .family<CheckoutPaymentController298, int>((ref, orderId) {
      final session = ref.watch(authControllerProvider).value;
      final identity = (session?.user.id, session?.token);
      bool current() {
        if (!ref.mounted || session == null) return false;
        final auth = ref.read(authControllerProvider);
        final value = auth.value;
        return !auth.hasError &&
            value != null &&
            !value.isExpired &&
            value.user.id == identity.$1 &&
            value.token == identity.$2;
      }

      final repository = ref.watch(customerOrdersRepositoryProvider);
      final controller = CheckoutPaymentController298(
        orderId: orderId,
        storeUri: ref.watch(customerOrdersStoreUriProvider),
        sessionIsCurrent: current,
        readOrder: (id) {
          if (!current() || repository is! CustomerOrderLookupRepository) {
            throw StateError('The current customer order is unavailable.');
          }
          return (repository as CustomerOrderLookupRepository).getOrder(id);
        },
        launch: ref.watch(hostedCommerceLauncher297Provider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
