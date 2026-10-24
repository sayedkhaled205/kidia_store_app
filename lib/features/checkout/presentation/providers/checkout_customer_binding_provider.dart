import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_safety_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/repositories/store_api_checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/data/storage/checkout_pending_attempt_store.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';

/// Checkout ownership follows the authenticated identity, not mutable profile
/// details. Rebuilding a route after a display-name/email update must not reset
/// its form or discard an in-flight or uncertain order attempt.
class CheckoutCustomerBinding {
  const CheckoutCustomerBinding({
    required this.repository,
    required this.initialEmail,
  });

  final CheckoutRepository repository;
  final String initialEmail;
}

// Tests override only this adapter; configured Native checkout always uses the
// operating system's secure storage and a stable store/customer namespace.
final checkoutAttemptStorageProvider = Provider<CheckoutAttemptStorage>(
  (_) => SecureCheckoutAttemptStorage(),
);

final checkoutCustomerBindingProvider =
    Provider.autoDispose<CheckoutCustomerBinding?>((Ref ref) {
      AppConfig.requireWooCommerceCustomerTransport('checkout');
      final identity = ref.watch(
        authControllerProvider.select(
          (AsyncValue<AuthSession?> state) =>
              (state.value?.user.id, state.value?.token, state.hasError),
        ),
      );
      final auth = ref.read(authControllerProvider);
      final session = auth.value;
      if (auth.hasError || session == null || session.isExpired) {
        // Auth can disappear before the route's previous provider subscription
        // is removed. Represent that normal transition without throwing or
        // constructing any customer-bound commerce dependency.
        return null;
      }
      final storeUri = ref.watch(cartStoreUriProvider);
      bool sessionIsCurrent() {
        if (!ref.mounted) return false;
        final auth = ref.read(authControllerProvider);
        final current = auth.value;
        return !auth.hasError &&
            current != null &&
            !current.isExpired &&
            current.user.id == identity.$1 &&
            current.token == identity.$2;
      }

      return CheckoutCustomerBinding(
        initialEmail: session.user.email,
        repository: StoreApiCheckoutRepository(
          customerId: session.user.id,
          cartRepository: ref.watch(cartRepositoryProvider),
          cartTokenStore: ref.watch(cartTokenStoreProvider),
          pendingAttemptStore: SecureCheckoutPendingAttemptStore(
            storeUri: storeUri,
            customerId: session.user.id,
            storage: ref.watch(checkoutAttemptStorageProvider),
          ),
          currentSessionIsValid: sessionIsCurrent,
          requireServerSafety: true,
          requireMerchantConfiguration: true,
          safetyTransport: StoreApiCheckoutSafetyTransport(
            storeUri: storeUri,
            dio: ref.watch(cartDioProvider),
            authTokenReader: () => sessionIsCurrent() ? identity.$2 : null,
          ),
          transport: StoreApiCheckoutTransport(
            storeUri: storeUri,
            dio: ref.watch(cartDioProvider),
            authTokenReader: () {
              return sessionIsCurrent() ? identity.$2 : null;
            },
          ),
        ),
      );
    });
