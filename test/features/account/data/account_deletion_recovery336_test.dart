import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/account/application/account_deletion_recovery.dart';
import 'package:mobishop_store_app/features/account/data/storage/account_deletion_receipt_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final status in [
    'unknown',
    'prepared',
    'pending',
    'completed',
    'malformed',
    'offline',
  ]) {
    test('restart recovers $status without executing deletion', () async {
      final store = AccountDeletionReceiptStore('https://fixture.invalid');
      final receipt = await store.prepare(7, 'old-token');
      AuthSession? session = AuthSession(
        token: 'old-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: const AuthUser(id: 7, email: 'fixture@example.invalid'),
      );
      final cleared = <String>[];
      final results = await recoverAccountDeletionReceipts(
        store: store,
        readStatus: (value) async {
          expect(value, receipt.receipt);
          if (status == 'offline') throw StateError('offline');
          return {'status': status};
        },
        currentSession: () => session,
        clearSession: (token) async {
          cleared.add(token);
          session = null;
        },
      );
      final accepted = status == 'pending' || status == 'completed';
      expect(cleared, accepted ? ['old-token'] : isEmpty);
      expect((await store.readAll()).length, status == 'completed' ? 0 : 1);
      expect(
        results[7],
        ['offline', 'malformed'].contains(status) ? 'unavailable' : status,
      );
    });
  }
  test(
    'multiple receipts cannot sign out a replacement account or erase another pending receipt',
    () async {
      final store = AccountDeletionReceiptStore('https://fixture.invalid');
      final first = await store.prepare(7, 'old-token');
      await store.prepare(8, 'other-old-token');
      final current = AuthSession(
        token: 'replacement-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: const AuthUser(id: 7, email: 'fixture@example.invalid'),
      );
      final results = await recoverAccountDeletionReceipts(
        store: store,
        readStatus: (value) async => {
          'status': value == first.receipt ? 'completed' : 'pending',
        },
        currentSession: () => current,
        clearSession: (_) async => fail('A replacement session must survive'),
      );
      expect(results, {7: 'completed', 8: 'pending'});
      expect((await store.readAll()).single.userId, 8);
    },
  );
  test(
    'failed session cleanup keeps completed receipt for another recovery',
    () async {
      final store = AccountDeletionReceiptStore('https://fixture.invalid');
      await store.prepare(7, 'old-token');
      final session = AuthSession(
        token: 'old-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: const AuthUser(id: 7, email: 'fixture@example.invalid'),
      );
      final results = await recoverAccountDeletionReceipts(
        store: store,
        readStatus: (_) async => {'status': 'completed'},
        currentSession: () => session,
        clearSession: (_) async => throw StateError('storage failure'),
      );
      expect(results, {7: 'unavailable'});
      expect(await store.readAll(), hasLength(1));
    },
  );
  for (final durable in ['old-token', 'replacement-token', 'unreadable']) {
    test(
      'completed receipt reconciles $durable when memory is empty',
      () async {
        final store = AccountDeletionReceiptStore('https://fixture.invalid');
        await store.prepare(7, 'old-token');
        AuthSession? saved = AuthSession(
          token: durable,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          user: const AuthUser(id: 7, email: 'fixture@example.invalid'),
        );
        final result = await recoverAccountDeletionReceipts(
          store: store,
          readStatus: (_) async => {'status': 'completed'},
          currentSession: () => null,
          readStoredSession: () async {
            if (durable == 'unreadable') {
              throw StateError('storage unavailable');
            }
            return saved;
          },
          clearSession: (token) async {
            expect(token, 'old-token');
            saved = null;
          },
        );
        expect(saved?.token, durable == 'old-token' ? isNull : durable);
        expect(
          result[7],
          durable == 'unreadable' ? 'unavailable' : 'completed',
        );
        expect((await store.readAll()).length, durable == 'unreadable' ? 1 : 0);
      },
    );
  }
}
