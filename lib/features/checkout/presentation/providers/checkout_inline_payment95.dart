import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/checkout/data/network/native_payment_client92.dart';
import 'package:mobishop_store_app/features/orders/presentation/providers/customer_orders_providers.dart';

typedef CheckoutInlinePayment95 =
    Future<bool> Function({
      required int orderId,
      required KashierInlineCardController card,
      required String amount,
      required String currency,
      required bool arabic,
    });

final checkoutInlinePayment95Provider = Provider<CheckoutInlinePayment95>((
  ref,
) {
  return ({
    required orderId,
    required card,
    required amount,
    required currency,
    required arabic,
  }) async {
    final session = ref.read(authControllerProvider).value;
    final store = ref.read(customerOrdersStoreUriProvider);
    String? currentToken() {
      if (!ref.mounted || session == null) return null;
      final auth = ref.read(authControllerProvider);
      final current = auth.value;
      return !auth.hasError &&
              current != null &&
              !current.isExpired &&
              current.user.id == session.user.id &&
              current.token == session.token &&
              ref.read(customerOrdersStoreUriProvider) == store
          ? current.token
          : null;
    }

    return NativePaymentClient92(store: store, token: currentToken).payInline(
      orderId,
      card: card,
      amount: amount,
      currency: currency,
      arabic: arabic,
    );
  };
});
