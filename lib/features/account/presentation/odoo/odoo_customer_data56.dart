import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/commerce/odoo_customer_client51.dart';
import '../../../auth/presentation/providers/odoo_customer_providers51.dart';

/// Customer-private Odoo reads use the verified Odoo cookie client only. They
/// never enter Woo's bearer repositories, or a merchant/admin API transport.
Future<OdooCustomerClient51> _verifiedClient(Ref ref) async {
  final session = await ref.watch(odooCustomerSession51Provider.future);
  final client = ref.watch(odooCustomerClient51Provider);
  if (!session.authenticated || !client.isAuthenticated) {
    throw const OdooCustomerException51('customer_session_required');
  }
  return client;
}

Future<T> _read<T>(
  Ref ref,
  Future<T> Function(OdooCustomerClient51) read,
) async {
  final client = await _verifiedClient(ref);
  try {
    return await read(client);
  } catch (_) {
    if (ref.mounted && !client.isAuthenticated) {
      ref.invalidate(odooCustomerSession51Provider);
    }
    rethrow;
  }
}

final odooCustomerProfile56Provider =
    FutureProvider.autoDispose<OdooCustomerProfile51>((ref) async {
      return _read(ref, (client) => client.profile());
    }, retry: (retryCount, error) => null);

final odooCustomerAddresses56Provider =
    FutureProvider.autoDispose<OdooCustomerAddresses51>((ref) async {
      return _read(ref, (client) => client.addresses());
    }, retry: (retryCount, error) => null);

final odooCustomerOrders56Provider = FutureProvider.autoDispose
    .family<OdooCustomerOrderPage51, int>((ref, page) async {
      return _read(ref, (client) => client.orders(page: page));
    }, retry: (retryCount, error) => null);

final odooCustomerOrder56Provider = FutureProvider.autoDispose
    .family<OdooCustomerOrder51, int>((ref, id) async {
      return _read(ref, (client) => client.order(id));
    }, retry: (retryCount, error) => null);

/// Formats integer minor units without double conversion/precision loss.
String odooCustomerMoney56(String minor, int digits, String currency) {
  final negative = minor.startsWith('-');
  final magnitude = negative ? minor.substring(1) : minor;
  if (digits == 0) return '$currency $minor';
  final padded = magnitude.padLeft(digits + 1, '0');
  final split = padded.length - digits;
  return '$currency ${negative ? '-' : ''}${padded.substring(0, split)}.${padded.substring(split)}';
}
