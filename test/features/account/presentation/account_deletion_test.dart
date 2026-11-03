import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobishop_store_app/features/account/presentation/account_deletion_screen.dart';
import 'package:mobishop_store_app/features/account/data/storage/account_deletion_receipt_store.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';

AuthSession session(String token, {int id = 7}) => AuthSession(
  token: token,
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  user: AuthUser(id: id, email: 'synthetic@example.invalid'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('account switch while receipt persists cannot send deletion', (
    tester,
  ) async {
    final ready = Completer<void>();
    final receipts = _DelayedReceiptStore(ready.future);
    final auth = _Auth(session('original'));
    final fake = _Deletion('pending');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          accountDeletionReceiptStoreProvider.overrideWithValue(receipts),
          accountDeletionTransportProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: AccountDeletionScreen(userId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-account-deletion')));
    await tester.pump();
    final button = find.byKey(const Key('request-account-deletion'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    auth.replace(session('replacement', id: 8));
    ready.complete();
    await tester.pumpAndSettle();
    expect(fake.calls, 0);
    expect(find.text('Account deletion requested'), findsNothing);
    expect(tester.takeException(), null);
  });

  test(
    'deletion cleanup preserves a replacement session and other merchant',
    () async {
      final a = SecureAuthSessionStore(storeUrl: 'https://a.example.invalid');
      final a2 = SecureAuthSessionStore(storeUrl: 'https://a.example.invalid/');
      final b = SecureAuthSessionStore(storeUrl: 'https://b.example.invalid');
      await a.write(session('old'));
      await b.write(session('other-store'));
      final replacement = a2.write(session('new', id: 8));
      final staleDeletion = a.clearIfToken('old');
      await replacement;
      expect(await staleDeletion, false);
      expect((await a.read())?.token, 'new');
      expect((await b.read())?.token, 'other-store');
      expect(await a.clearIfToken('new'), true);
      expect(await a.read(), null);
    },
  );

  test('cleanup cannot remove a login queued after deletion', () async {
    final a = SecureAuthSessionStore(storeUrl: 'https://a.example.invalid');
    await a.write(session('old'));
    final deletion = a.clearIfToken('old');
    final replacement = a.write(session('new'));
    expect(await deletion, true);
    await replacement;
    expect((await a.read())?.token, 'new');
  });

  for (final result in [
    'pending',
    'lost-response',
    'stale',
    'failure',
    'wrong-user',
  ]) {
    testWidgets('explicit self-deletion confirmation: $result', (tester) async {
      final store = MemoryAuthSessionStore()..value = session('test-session');
      final fake = _Deletion(result);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionStoreProvider.overrideWithValue(store),
            authControllerProvider.overrideWith(() => _Auth(store.value!)),
            accountDeletionTransportProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(home: AccountDeletionScreen(userId: 7)),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('request-account-deletion'));
      expect(tester.widget<FilledButton>(button).onPressed, null);
      expect(fake.calls, 0);
      await tester.tap(find.byKey(const Key('confirm-account-deletion')));
      await tester.pump();
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(fake.calls, 1);
      if (result == 'pending' || result == 'lost-response') {
        expect(find.text('Account deletion requested'), findsOneWidget);
        expect(store.value, null);
      } else {
        expect(store.value?.token, 'test-session');
        expect(find.text('Account deletion requested'), findsNothing);
        if (result == 'stale') {
          expect(find.text('Sign in to confirm'), findsOneWidget);
        }
      }
      expect(tester.takeException(), null);
    });
  }

  testWidgets('a different signed-in account cannot confirm the open request', (
    tester,
  ) async {
    final fake = _Deletion('pending');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _Auth(session('replacement', id: 8)),
          ),
          accountDeletionTransportProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: AccountDeletionScreen(userId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('request-account-deletion')), findsNothing);
    expect(fake.calls, 0);
  });

  for (final outcome in ['pending', 'completed']) {
    testWidgets(
      'saved receipt recovers $outcome after restart without logging out replacement',
      (tester) async {
        final receiptStore = AccountDeletionReceiptStore(
          'https://store.example.invalid',
        );
        await receiptStore.prepare(7, 'old-token');
        final store = MemoryAuthSessionStore()
          ..value = session('replacement', id: 8);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authSessionStoreProvider.overrideWithValue(store),
              authControllerProvider.overrideWith(() => _Auth(store.value!)),
              accountDeletionReceiptStoreProvider.overrideWithValue(
                receiptStore,
              ),
              accountDeletionTransportProvider.overrideWithValue(
                _Deletion(outcome)..status = outcome,
              ),
            ],
            child: const MaterialApp(home: AccountDeletionScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            outcome == 'completed'
                ? 'Account deleted'
                : 'Account deletion requested',
          ),
          findsOneWidget,
        );
        expect(store.value?.token, 'replacement');
        expect(find.byKey(const Key('request-account-deletion')), findsNothing);
        expect(tester.takeException(), null);
      },
    );
  }

  test(
    'receipts persist, are store scoped and cannot be replaced by another account',
    () async {
      final a = AccountDeletionReceiptStore('https://a.example.invalid');
      final same = AccountDeletionReceiptStore('https://A.example.invalid/');
      final b = AccountDeletionReceiptStore('https://b.example.invalid');
      final receipts = await Future.wait([
        a.prepare(7, 'token'),
        same.prepare(7, 'token'),
      ]);
      expect(receipts[0].receipt, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(receipts[0].receipt, receipts[1].receipt);
      expect((await same.read())?.matchesSession('token'), true);
      expect((await b.read()), null);
      await expectLater(a.prepare(8, 'another-account'), throwsStateError);
      await a.clear('wrong-capability');
      expect(await a.read(), isNotNull);
      await a.clear(receipts[0].receipt);
      expect(await a.read(), null);
    },
  );
}

class _Auth extends AuthController {
  _Auth(this.session);
  final AuthSession session;
  void replace(AuthSession value) => state = AsyncData(value);
  @override
  Future<AuthSession?> build() async => session;
}

class _DelayedReceiptStore extends AccountDeletionReceiptStore {
  _DelayedReceiptStore(this.ready) : super('https://delayed.example.invalid');
  final Future<void> ready;
  @override
  Future<AccountDeletionReceipt> prepare(int userId, String token) async {
    await ready;
    return super.prepare(userId, token);
  }
}

class _Deletion implements CustomerAccountDeletionTransport {
  _Deletion(this.result);
  final String result;
  int calls = 0;
  String status = 'unknown';
  @override
  Future<Map<String, dynamic>> deletionStatus(String receipt) async => {
    'status': status,
  };
  @override
  Future<Map<String, dynamic>> deletionAvailability() async => {
    'available': true,
  };
  @override
  Future<Map<String, dynamic>> requestDeletion({
    required String receipt,
    required String expectedSession,
  }) async {
    calls++;
    expect(receipt, matches(RegExp(r'^[a-f0-9]{64}$')));
    if (result == 'lost-response') {
      status = 'pending';
      throw const CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.connection,
        message: 'Synthetic lost response after acceptance',
      );
    }
    if (result == 'stale') {
      throw const CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.unauthorized,
        message: 'Synthetic reauthentication requirement',
        code: 'mobishop_account_deletion_reauth',
        statusCode: 403,
      );
    }
    if (result == 'failure') {
      throw StateError('Synthetic interrupted connection');
    }
    return {'status': 'pending', 'user_id': result == 'wrong-user' ? 8 : 7};
  }
}
