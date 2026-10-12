import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:mobishop_store_app/features/account/data/repositories/customer_account_repository_impl.dart';
import 'package:mobishop_store_app/features/account/domain/entities/customer_account.dart';
import 'package:mobishop_store_app/features/account/domain/repositories/customer_account_repository.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';

final customerAccountStoreUriProvider = Provider<Uri>((Ref ref) {
  AppConfig.requireWooCommerceCustomerTransport('account');
  AppConfig.validateStoreConnection();
  return Uri.parse(AppConfig.apiBaseUrl.trim());
});

final customerAccountApiTransportProvider =
    Provider<CustomerAccountApiTransport>((Ref ref) {
      // Names/email can change without replacing a valid customer session.
      // Refreshing that session may also retain its last verified value.
      ref.watch(
        authControllerProvider.select(
          (AsyncValue<AuthSession?> state) =>
              (state.value?.user.id, state.value?.token),
        ),
      );
      return DioCustomerAccountApiTransport(
        storeUri: ref.watch(customerAccountStoreUriProvider),
        dio: ref.watch(authDioProvider),
        authTokenReader: () {
          // A form can retain its repository while logout replaces providers.
          // Never reuse that repository's old credentials after disposal.
          if (!ref.mounted) return null;
          final AuthSession? session = ref.read(authControllerProvider).value;
          return session == null || session.isExpired ? null : session.token;
        },
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
