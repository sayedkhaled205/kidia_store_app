import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobishop_store_app/features/account/presentation/account_deletion_screen.dart';
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

  for (final result in ['pending', 'stale', 'failure', 'wrong-user']) {
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
      if (result == 'pending') {
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
}

class _Auth extends AuthController {
  _Auth(this.session);
  final AuthSession session;
  @override
  Future<AuthSession?> build() async => session;
}

class _Deletion implements CustomerAccountDeletionTransport {
  _Deletion(this.result);
  final String result;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> deletionAvailability() async => {
    'available': true,
  };
  @override
  Future<Map<String, dynamic>> requestDeletion() async {
    calls++;
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
