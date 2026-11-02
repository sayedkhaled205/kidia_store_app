// Synthetic regression fixtures; no server or account access.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/account/presentation/account_screen.dart';
import 'package:mobishop_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:mobishop_store_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/data/storage/social_auth_pending_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

AuthSession session(int id) => AuthSession(
  token: 'synthetic-session-$id',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  user: AuthUser(id: id, email: 'audit-$id@example.invalid'),
);
AuthRepositoryImpl _repo(AuthSessionStore store, _Transport transport) =>
    AuthRepositoryImpl(
      sessionStore: store,
      transport: transport,
      socialPendingStore: MemorySocialAuthPendingStore(),
    );
const offline = AuthApiException(
  kind: AuthFailureKind.connection,
  message: 'Synthetic offline failure',
);

void main() {
  for (final remoteFailure in [false, true]) {
    test(
      'replacement during first pending remote logout survives failure=$remoteFailure',
      () async {
        final store = MemoryAuthSessionStore()..value = session(1);
        final transport = _Transport();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_repo(store, transport)),
          ],
        );
        addTearDown(container.dispose);
        await container.read(authControllerProvider.future);
        final controller = container.read(authControllerProvider.notifier);
        final pending = controller.signOut();
        final observed = pending.then<Object?>(
          (_) => null,
          onError: (Object e) => e,
        );
        await Future<void>.delayed(Duration.zero);
        expect(store.value, isNull);
        expect(transport.requests, hasLength(1));
        final replacement = session(2);
        await store.write(replacement);
        controller.acceptNativeSession(replacement);
        if (remoteFailure) {
          transport.requests.single.completeError(offline);
        } else {
          transport.requests.single.complete();
        }
        expect(await observed, remoteFailure ? same(offline) : isNull);
        expect(store.value, same(replacement));
        expect(container.read(authControllerProvider).value, same(replacement));
      },
    );

    test(
      'disposed provider safely finishes remote logout failure=$remoteFailure',
      () async {
        final store = MemoryAuthSessionStore()..value = session(1);
        final transport = _Transport();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_repo(store, transport)),
          ],
        );
        await container.read(authControllerProvider.future);
        final pending = container
            .read(authControllerProvider.notifier)
            .signOut();
        final observed = pending.then<Object?>(
          (_) => null,
          onError: (Object e) => e,
        );
        await Future<void>.delayed(Duration.zero);
        expect(store.value, isNull);
        container.dispose();
        if (remoteFailure) {
          transport.requests.single.completeError(offline);
        } else {
          transport.requests.single.complete();
        }
        expect(await observed, remoteFailure ? same(offline) : isNull);
        expect(store.value, isNull);
      },
    );
  }

  test(
    'a replacement account can sign out while the previous revocation is pending',
    () async {
      final store = MemoryAuthSessionStore()..value = session(1);
      final transport = _Transport();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_repo(store, transport)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      final first = controller.signOut();
      await Future<void>.delayed(Duration.zero);
      final replacement = session(2);
      await store.write(replacement);
      controller.acceptNativeSession(replacement);
      final second = controller.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(transport.requests, hasLength(2));
      transport.requests.first.complete();
      await first;
      expect(container.read(authControllerProvider).value, same(replacement));
      transport.requests.last.complete();
      await second;
      expect(container.read(authControllerProvider).value, isNull);
      expect(store.value, isNull);
    },
  );

  test(
    'local deletion failure preserves cause and state then permits retry',
    () async {
      final store = _FlakyStore()..value = session(1);
      final transport = _Transport()..completeImmediately = true;
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_repo(store, transport)),
        ],
      );
      addTearDown(container.dispose);
      final original = await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      await expectLater(
        controller.signOut(),
        throwsA(
          isA<AuthRepositoryException>()
              .having((e) => e.code, 'code', 'local_sign_out_failed')
              .having(
                (e) => e.cause,
                'preserved original failure',
                same(store.failure),
              ),
        ),
      );
      expect(store.value, same(original));
      expect(container.read(authControllerProvider).value, same(original));
      expect(transport.requests, isEmpty);
      await controller.signOut();
      expect(store.value, isNull);
      expect(container.read(authControllerProvider).value, isNull);
      expect(transport.requests, hasLength(1));
    },
  );

  testWidgets(
    'local deletion failure stays signed in with handled message and UI retry',
    (tester) async {
      final store = _FlakyStore()..value = session(1);
      final transport = _Transport()..completeImmediately = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_repo(store, transport)),
            cmsPageLayoutProvider('account').overrideWith(
              (_) async => CmsPageLayout.fromJson({
                'page': 'account',
                'header': {'enabled': false},
                'footer': {'enabled': false},
                'elements': [
                  {'id': 'account_summary', 'enabled': true},
                  {'id': 'account_menu', 'enabled': false},
                  {'id': 'logout_button', 'enabled': true},
                ],
              }),
            ),
          ],
          child: const MaterialApp(home: AccountScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccountScreen)),
      );
      final original = container.read(authControllerProvider).value;
      final button = find.byKey(const Key('account-sign-out'));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(store.value, same(original));
      expect(container.read(authControllerProvider).value, same(original));
      expect(
        find.text('Could not finish signing out. Please try again.'),
        findsOneWidget,
      );
      expect(button, findsOneWidget);
      expect(transport.requests, isEmpty);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(store.value, isNull);
      expect(container.read(authControllerProvider).value, isNull);
      expect(find.byKey(const Key('account-sign-in')), findsOneWidget);
      expect(find.text('You have been signed out.'), findsOneWidget);
    },
  );
}

class _FlakyStore extends MemoryAuthSessionStore {
  final failure = StateError('Synthetic locked storage');
  bool fail = true;
  @override
  Future<void> clear() async {
    if (fail) {
      fail = false;
      throw failure;
    }
    await super.clear();
  }
}

class _Transport implements AuthApiTransport {
  final requests = <Completer<void>>[];
  bool completeImmediately = false;
  @override
  Future<AuthUser> currentUser(String token) async => session(1).user;
  @override
  Future<void> signOut(String token) {
    final request = Completer<void>();
    requests.add(request);
    if (completeImmediately) request.complete();
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
