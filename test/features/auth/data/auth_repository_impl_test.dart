import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:kidia_store_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kidia_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:kidia_store_app/features/auth/data/storage/social_auth_pending_store.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:kidia_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('AuthRepositoryImpl', () {
    test('uses the server decision for the progressive email step', () async {
      final _FakeAuthTransport transport = _FakeAuthTransport()
        ..identity = const AuthIdentity(
          email: 'customer@example.com',
          isRegistered: true,
        );
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        transport: transport,
        sessionStore: MemoryAuthSessionStore(),
        socialPendingStore: MemorySocialAuthPendingStore(),
      );

      final AuthIdentity identity = await repository.identify(
        ' CUSTOMER@example.com ',
      );

      expect(identity.isRegistered, isTrue);
      expect(identity.email, 'customer@example.com');
      expect(transport.identifiedEmails, <String>[' CUSTOMER@example.com ']);
    });

    test('persists a successful website customer login', () async {
      final AuthSession session = _session();
      final _FakeAuthTransport transport = _FakeAuthTransport()
        ..loginSession = session;
      final MemoryAuthSessionStore store = MemoryAuthSessionStore();
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        transport: transport,
        sessionStore: store,
        socialPendingStore: MemorySocialAuthPendingStore(),
      );

      final AuthSession result = await repository.signIn(
        email: 'customer@example.com',
        password: 'safe-password',
      );

      expect(result.token, session.token);
      expect(store.value?.token, session.token);
      expect(transport.loginPasswords, <String>['safe-password']);
    });

    test('refreshes a stored session profile without replacing its token', () async {
      final MemoryAuthSessionStore store = MemoryAuthSessionStore()
        ..value = _session();
      final _FakeAuthTransport transport = _FakeAuthTransport()
        ..current = const AuthUser(
          id: 7,
          email: 'customer@example.com',
          displayName: 'Updated Customer',
        );
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        transport: transport,
        sessionStore: store,
        socialPendingStore: MemorySocialAuthPendingStore(),
      );

      final AuthSession? restored = await repository.restoreSession();

      expect(restored?.token, _token('a'));
      expect(restored?.user.name, 'Updated Customer');
      expect(store.value?.user.name, 'Updated Customer');
    });

    test('clears a server-rejected stored session', () async {
      final MemoryAuthSessionStore store = MemoryAuthSessionStore()
        ..value = _session();
      final _FakeAuthTransport transport = _FakeAuthTransport()
        ..currentError = const AuthApiException(
          kind: AuthFailureKind.unauthorized,
          message: 'Expired',
          statusCode: 401,
        );
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        transport: transport,
        sessionStore: store,
        socialPendingStore: MemorySocialAuthPendingStore(),
      );

      expect(await repository.restoreSession(), isNull);
      expect(store.value, isNull);
    });

    test('starts and completes a store-backed social sign-in', () async {
      final AuthSession session = _session();
      final _FakeAuthTransport transport = _FakeAuthTransport()
        ..socialSession = session;
      final MemoryAuthSessionStore sessionStore = MemoryAuthSessionStore();
      final MemorySocialAuthPendingStore pendingStore =
          MemorySocialAuthPendingStore();
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        transport: transport,
        sessionStore: sessionStore,
        socialPendingStore: pendingStore,
      );

      final Uri authorizeUri = await repository.beginSocialSignIn(
        provider: SocialAuthProvider.google,
        returnPath: '/checkout',
      );
      final SocialAuthPending pending = pendingStore.value!;
      final SocialAuthCompletion completion = await repository
          .completeSocialSignIn(code: _secret('c'), state: pending.state);

      expect(authorizeUri, Uri.parse('https://shop.example.com/social/google'));
      expect(transport.socialProviders, <SocialAuthProvider>[
        SocialAuthProvider.google,
      ]);
      expect(transport.exchangedVerifier, pending.verifier);
      expect(completion.returnPath, '/checkout');
      expect(completion.session.token, session.token);
      expect(sessionStore.value?.token, session.token);
      expect(pendingStore.value, isNull);
    });

    test('rejects a social callback whose state does not match', () async {
      final _FakeAuthTransport transport = _FakeAuthTransport();
      final MemorySocialAuthPendingStore pendingStore =
          MemorySocialAuthPendingStore();
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        transport: transport,
        sessionStore: MemoryAuthSessionStore(),
        socialPendingStore: pendingStore,
      );
      await repository.beginSocialSignIn(
        provider: SocialAuthProvider.facebook,
        returnPath: '/account',
      );

      await expectLater(
        repository.completeSocialSignIn(
          code: _secret('c'),
          state: _secret('x'),
        ),
        throwsA(
          isA<AuthRepositoryException>().having(
            (AuthRepositoryException error) => error.kind,
            'kind',
            AuthFailureKind.invalidInput,
          ),
        ),
      );

      expect(transport.exchangeCount, 0);
      expect(pendingStore.value, isNotNull);
    });
  });
}

AuthSession _session() {
  return AuthSession(
    token: _token('a'),
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 10)),
    user: const AuthUser(
      id: 7,
      email: 'customer@example.com',
      displayName: 'Customer',
    ),
  );
}

String _token(String character) =>
    'kma1.7.${List<String>.filled(64, character).join()}';

String _secret(String character) =>
    List<String>.filled(64, character).join();

class _FakeAuthTransport implements AuthApiTransport {
  AuthIdentity identity = const AuthIdentity(
    email: 'new@example.com',
    isRegistered: false,
  );
  AuthSession? loginSession;
  AuthSession? registrationSession;
  AuthSession? socialSession;
  AuthUser? current;
  AuthApiException? currentError;
  final List<String> identifiedEmails = <String>[];
  final List<String> loginPasswords = <String>[];
  final List<SocialAuthProvider> socialProviders = <SocialAuthProvider>[];
  String? exchangedVerifier;
  int exchangeCount = 0;

  @override
  Future<AuthIdentity> identify(String email) async {
    identifiedEmails.add(email);
    return identity;
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    loginPasswords.add(password);
    return loginSession ?? _session();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    return registrationSession ?? _session();
  }

  @override
  Future<Uri> beginSocialSignIn({
    required SocialAuthProvider provider,
    required String state,
    required String verifier,
  }) async {
    socialProviders.add(provider);
    expect(state.length, greaterThanOrEqualTo(43));
    expect(verifier.length, greaterThanOrEqualTo(43));
    return Uri.parse('https://shop.example.com/social/${provider.apiName}');
  }

  @override
  Future<AuthSession> exchangeSocialSignIn({
    required String code,
    required String state,
    required String verifier,
  }) async {
    exchangeCount += 1;
    exchangedVerifier = verifier;
    return socialSession ?? _session();
  }

  @override
  Future<AuthUser> currentUser(String token) async {
    final AuthApiException? error = currentError;
    if (error != null) {
      throw error;
    }
    return current ?? _session().user;
  }

  @override
  Future<void> signOut(String token) async {}
}
