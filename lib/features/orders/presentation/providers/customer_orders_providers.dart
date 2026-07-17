import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kidia_store_app/features/orders/data/network/customer_orders_api_transport.dart';
import 'package:kidia_store_app/features/orders/data/repositories/customer_orders_repository_impl.dart';
import 'package:kidia_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:kidia_store_app/features/orders/presentation/controllers/customer_orders_controller.dart';

final customerOrdersApiTransportProvider = Provider<CustomerOrdersApiTransport>(
  (Ref ref) {
    final AuthSession? session = ref.watch(authControllerProvider).asData?.value;
    return DioCustomerOrdersApiTransport.forConfiguredStore(
      dio: ref.watch(authDioProvider),
      authTokenReader: () => session?.token,
    );
  },
);

final customerOrdersRepositoryProvider = Provider<CustomerOrdersRepository>(
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
