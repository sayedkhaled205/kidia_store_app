import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:kidia_store_app/features/account/data/repositories/customer_account_repository_impl.dart';
import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';
import 'package:kidia_store_app/features/account/domain/repositories/customer_account_repository.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';

final customerAccountApiTransportProvider =
    Provider<CustomerAccountApiTransport>((Ref ref) {
      final AuthSession? session = ref.watch(authControllerProvider).asData?.value;
      return DioCustomerAccountApiTransport.forConfiguredStore(
        dio: ref.watch(authDioProvider),
        authTokenReader: () => session?.token,
      );
    });

final customerAccountRepositoryProvider = Provider<CustomerAccountRepository>(
  (Ref ref) => CustomerAccountRepositoryImpl(
    ref.watch(customerAccountApiTransportProvider),
  ),
);

final customerAccountProvider = FutureProvider.autoDispose<CustomerAccount>(
  (Ref ref) => ref.watch(customerAccountRepositoryProvider).getAccount(),
);
