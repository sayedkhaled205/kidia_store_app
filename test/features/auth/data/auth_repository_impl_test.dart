import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:kidia_store_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kidia_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_user.dart';
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
      );

      expect(await repository.restoreSession(), isNull);
      expect(store.value, isNull);
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

class _FakeAuthTransport implements AuthApiTransport {
  AuthIdentity identity = const AuthIdentity(
    email: 'new@example.com',
    isRegistered: false,
  );
  AuthSession? loginSession;
  AuthSession? registrationSession;
  AuthUser? current;
  AuthApiException? currentError;
  final List<String> identifiedEmails = <String>[];
  final List<String> loginPasswords = <String>[];

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
