import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/checkout/data/network/native_payment_client92.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_payment_controller298.dart';
import 'package:mobishop_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:mobishop_store_app/features/orders/presentation/providers/customer_orders_providers.dart';

final checkoutPaymentController298Provider = Provider.autoDispose
    .family<CheckoutPaymentController298, int>((ref, orderId) {
      final identity = ref.watch(authControllerProvider.select((state) =>
        (state.value?.user.id, state.value?.token)));
      bool current() {
        if (!ref.mounted || identity.$1 == null) return false;
        final auth = ref.read(authControllerProvider);
        final value = auth.value;
        return !auth.hasError &&
            value != null &&
            !value.isExpired &&
            value.user.id == identity.$1 &&
            value.token == identity.$2;
      }

      final repository = ref.watch(customerOrdersRepositoryProvider);
      final native = NativePaymentClient92(
        store: ref.watch(customerOrdersStoreUriProvider),
        token: () => current() ? identity.$2 : null,
      );
      late CheckoutPaymentController298 controller;
      controller = CheckoutPaymentController298(
        orderId: orderId,
        storeUri: ref.watch(customerOrdersStoreUriProvider),
        sessionIsCurrent: current,
        readOrder: (id) async {
          if (!current() || repository is! CustomerOrderLookupRepository) {
            throw StateError('The current customer order is unavailable.');
          }
          // Offline orders need no adapter. Provider unavailability must not
          // hide the authoritative order history or cause a new payment.
          try {
            await native.reconcile(id);
          } catch (_) {}
          if (!current()) throw StateError('The customer changed.');
          return (repository as CustomerOrderLookupRepository).getOrder(id);
        },
        launch: (_) async {
          final opened = await native.present(
            orderId,
            arabic: AppConfig.isRightToLeft,
          );
          await controller.returnedToApp();
          return opened;
        },
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
