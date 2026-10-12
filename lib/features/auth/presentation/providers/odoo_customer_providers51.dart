import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_session_store51.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';

/// Separate protocol graph; no Woo AuthSession/token, analytics or merchant API.
/// Routes/UI do not consume this graph yet. Website/company binding remains
/// server-enforced for this exact validated HTTPS origin on every request.
final odooCustomerConnection51Provider = Provider<CommerceConnection>((ref) {
  final connection = AppConfig.commerceConnection;
  if (connection.platform != CommercePlatform.odoo) {
    throw const AppConfigurationException(
      'The Odoo customer graph requires STORE_PLATFORM=odoo.',
    );
  }
  return connection;
});

final odooCustomerSessionStore51Provider = Provider<OdooCustomerSessionStore51>(
  (ref) {
    return SecureOdooCustomerSessionStore51(
      connection: ref.watch(odooCustomerConnection51Provider),
    );
  },
);

final odooCustomerClient51Provider = Provider<OdooCustomerClient51>((ref) {
  final connection = ref.watch(odooCustomerConnection51Provider);
  if (connection.platform != CommercePlatform.odoo) {
    throw const AppConfigurationException(
      'An Odoo customer connection is required.',
    );
  }
  final client = OdooCustomerClient51(
    connection: connection,
    sessionStore: ref.watch(odooCustomerSessionStore51Provider),
  );
  ref.onDispose(client.close);
  return client;
});

final odooCustomerSession51Provider =
    AsyncNotifierProvider<
      OdooCustomerSessionController51,
      OdooCustomerSession51
    >(OdooCustomerSessionController51.new, retry: (retryCount, error) => null);

class OdooCustomerSessionController51
    extends AsyncNotifier<OdooCustomerSession51> {
  int _intentGeneration = 0;

  @override
  Future<OdooCustomerSession51> build() async {
    final ticket = _intentGeneration;
    final client = ref.watch(odooCustomerClient51Provider);
    try {
      final session = await client.restoreSession();
      if (!ref.mounted) return const OdooCustomerSession51();
      return ticket == _intentGeneration
          ? session
          : state.asData?.value ?? const OdooCustomerSession51();
    } catch (_) {
      // An explicit sign-out wins over a cancelled restore's late error too.
      if (!ref.mounted) return const OdooCustomerSession51();
      if (ticket != _intentGeneration) {
        return state.asData?.value ?? const OdooCustomerSession51();
      }
      rethrow;
    }
  }

  Future<void> signIn({required String login, required String password}) async {
    final ticket = _intentGeneration;
    final client = ref.read(odooCustomerClient51Provider);
    try {
      final customer = await client.login(login: login, password: password);
      if (ref.mounted && ticket == _intentGeneration) {
        state = AsyncData(
          OdooCustomerSession51(
            customer: customer,
            expiresAt: client.sessionExpiresAt,
          ),
        );
      }
    } catch (_) {
      if (ref.mounted &&
          ticket == _intentGeneration &&
          !client.isAuthenticated) {
        state = const AsyncData(OdooCustomerSession51());
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    final client = ref.read(odooCustomerClient51Provider);
    _intentGeneration += 1;
    state = const AsyncData(OdooCustomerSession51());
    try {
      await client.logout();
    } on OdooCustomerException51 catch (error) {
      if (error.code != 'customer_session_required' ||
          error.statusCode != null) {
        rethrow;
      }
    }
  }
}
