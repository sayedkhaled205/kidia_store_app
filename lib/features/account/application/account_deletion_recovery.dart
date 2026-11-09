import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import '../../auth/domain/entities/auth_session.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/network/customer_account_api_transport.dart';
import '../data/storage/account_deletion_receipt_store.dart';
import '../presentation/providers/customer_account_providers.dart';

final accountDeletionReceiptStoreProvider =
    Provider<AccountDeletionReceiptStore>(
      (ref) => AccountDeletionReceiptStore(AppConfig.apiBaseUrl),
    );
final accountDeletionReceiptProvider =
    FutureProvider.autoDispose<AccountDeletionReceipt?>(
      (ref) => ref.watch(accountDeletionReceiptStoreProvider).read(),
    );

/// Read-only recovery. Neither an unknown outcome nor a restart authorizes deletion.
Future<Map<int, String>> recoverAccountDeletionReceipts({
  required AccountDeletionReceiptStore store,
  required Future<Map<String, dynamic>> Function(String receipt) readStatus,
  required AuthSession? Function() currentSession,
  required Future<void> Function(String token) clearSession,
  Future<AuthSession?> Function()? readStoredSession,
  bool Function()? isActive,
}) async {
  final results = <int, String>{};
  for (final receipt in await store.readAll()) {
    if (isActive?.call() == false) break;
    try {
      final status = (await readStatus(receipt.receipt))['status'];
      if (isActive?.call() == false) break;
      if (!const [
        'unknown',
        'prepared',
        'pending',
        'completed',
      ].contains(status)) {
        throw const FormatException('Invalid deletion outcome');
      }
      results[receipt.userId] = status as String;
      if (status != 'pending' && status != 'completed') continue;
      final session = currentSession();
      if (session != null &&
          session.user.id == receipt.userId &&
          receipt.matchesSession(session.token)) {
        await clearSession(session.token);
      }
      // A prior failed storage cleanup can leave a token after UI state became null.
      // Reconcile durable storage too, preserving any replacement account.
      final stored = await readStoredSession?.call();
      if (stored != null &&
          stored.user.id == receipt.userId &&
          receipt.matchesSession(stored.token)) {
        await clearSession(stored.token);
      }
      if (status == 'completed') await store.clear(receipt.receipt);
    } catch (_) {
      results[receipt.userId] = 'unavailable';
    }
  }
  return results;
}

final accountDeletionRecoveryProvider = FutureProvider<Map<int, String>>((
  ref,
) async {
  if (AppConfig.isCmsPreview ||
      !AppConfig.hasConfiguredStore ||
      AppConfig.commercePlatform != CommercePlatform.wooCommerce) {
    return {};
  }
  final store = ref.watch(accountDeletionReceiptStoreProvider);
  if ((await store.readAll()).isEmpty || !ref.mounted) return {};
  try {
    await ref.read(authControllerProvider.future);
  } catch (_) {
    // Receipt status is public proof-bound recovery and needs no active session.
  }
  if (!ref.mounted) return {};
  final transport = ref.read(customerAccountApiTransportProvider);
  if (transport is! CustomerAccountDeletionTransport) return {};
  return recoverAccountDeletionReceipts(
    store: store,
    readStatus: (transport as CustomerAccountDeletionTransport).deletionStatus,
    currentSession: () =>
        ref.mounted ? ref.read(authControllerProvider).value : null,
    clearSession: (token) => ref
        .read(authControllerProvider.notifier)
        .completeAccountDeletion(token),
    readStoredSession: () => ref.read(authSessionStoreProvider).read(),
    isActive: () => ref.mounted,
  );
}, retry: (_, _) => null);
