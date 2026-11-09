import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/account/application/account_deletion_recovery.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:mobishop_store_app/features/account/data/storage/account_deletion_receipt_store.dart';
import 'package:mobishop_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';

class _RestoreFailed extends AuthController {
  @override
  Future<AuthSession?> build() async =>
      throw StateError('temporary storage failure');
}

class _Status
    implements CustomerAccountApiTransport, CustomerAccountDeletionTransport {
  int reads = 0;
  @override
  Future<Map<String, dynamic>> deletionStatus(String receipt) async {
    reads++;
    return {'status': 'completed'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No mutation is allowed during receipt recovery');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final token in ['deleted-session', 'replacement-session']) {
    test(
      'real recovery provider survives restore failure and preserves $token boundary',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final receipts = AccountDeletionReceiptStore(AppConfig.apiBaseUrl);
        await receipts.prepare(7, 'deleted-session');
        final saved = MemoryAuthSessionStore()
          ..value = AuthSession(
            token: token,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            user: const AuthUser(id: 7, email: 'fixture@example.invalid'),
          );
        final transport = _Status();
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(_RestoreFailed.new),
            authSessionStoreProvider.overrideWithValue(saved),
            accountDeletionReceiptStoreProvider.overrideWithValue(receipts),
            customerAccountApiTransportProvider.overrideWithValue(transport),
          ],
        );
        addTearDown(container.dispose);
        final result = await container.read(
          accountDeletionRecoveryProvider.future,
        );
        expect(result, {7: 'completed'});
        expect(transport.reads, 1);
        expect(
          (await saved.read())?.token,
          token == 'deleted-session' ? isNull : token,
        );
        expect(await receipts.readAll(), isEmpty);
      },
      skip: AppConfig.hasConfiguredStore
          ? false
          : 'Run with STORE_URL=https://fixture.example.invalid (CI dedicated pass)',
    );
  }
}
