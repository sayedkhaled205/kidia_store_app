import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/orders/data/network/customer_orders_api_transport.dart';
import 'package:mobishop_store_app/features/orders/data/repositories/customer_orders_repository_impl.dart';
import 'package:mobishop_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:mobishop_store_app/features/orders/presentation/controllers/customer_orders_controller.dart';

final customerOrdersStoreUriProvider = Provider<Uri>((Ref ref) {
  AppConfig.requireWooCommerceCustomerTransport('orders');
  AppConfig.validateStoreConnection();
  return Uri.parse(AppConfig.apiBaseUrl.trim());
});

final customerOrdersApiTransportProvider =
    Provider.autoDispose<CustomerOrdersApiTransport>((Ref ref) {
      final identity = ref.watch(
        authControllerProvider.select(
          (AsyncValue<AuthSession?> state) =>
              (state.value?.user.id, state.value?.token),
        ),
      );
      return DioCustomerOrdersApiTransport(
        storeUri: ref.watch(customerOrdersStoreUriProvider),
        dio: ref.watch(authDioProvider),
        authTokenReader: () {
          if (!ref.mounted) return null;
          final AuthSession? current = ref.read(authControllerProvider).value;
          if (current == null ||
              current.isExpired ||
              current.user.id != identity.$1 ||
              current.token != identity.$2) {
            return null;
          }
          return current.token;
        },
      );
    });

// No retained stale repository may flush during the next customer's widget
// build. Dispose the complete orders chain when its screen/controller leaves.
final customerOrdersRepositoryProvider =
    Provider.autoDispose<CustomerOrdersRepository>(
      (Ref ref) => CustomerOrdersRepositoryImpl(
        ref.watch(customerOrdersApiTransportProvider),
      ),
    );

final customerOrdersControllerProvider =
    Provider.autoDispose<CustomerOrdersController>((Ref ref) {
      final CustomerOrdersController controller = CustomerOrdersController(
        ref.watch(customerOrdersRepositoryProvider),
      );
      ref.onDispose(controller.dispose);
      unawaited(controller.loadInitial());
      return controller;
    });
