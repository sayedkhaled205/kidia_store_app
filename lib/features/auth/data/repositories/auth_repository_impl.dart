import 'package:kidia_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:kidia_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this.transport, required this.sessionStore});

  final AuthApiTransport transport;
  final AuthSessionStore sessionStore;

  @override
  Future<AuthIdentity> identify(String email) {
    return _guard(() => transport.identify(email));
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final AuthSession session = await _guard(
      () => transport.signIn(email: email, password: password),
    );
    await sessionStore.write(session);
    return session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final AuthSession session = await _guard(
      () => transport.register(email: email, password: password),
    );
    await sessionStore.write(session);
    return session;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final AuthSession? stored = await sessionStore.read();
    if (stored == null) {
      return null;
    }
    if (stored.isExpired) {
      await sessionStore.clear();
      return null;
    }

    try {
      final AuthUser user = await transport.currentUser(stored.token);
      final AuthSession refreshed = stored.copyWith(user: user);
      await sessionStore.write(refreshed);
      return refreshed;
    } on AuthApiException catch (error) {
      if (error.kind == AuthFailureKind.unauthorized ||
          error.kind == AuthFailureKind.invalidInput) {
        await sessionStore.clear();
        return null;
      }
      // An unexpired, locally secured session remains useful while offline.
      // Every protected server request still validates the bearer token.
      return stored;
    } on FormatException {
      await sessionStore.clear();
      return null;
    }
  }

  @override
  Future<void> signOut(AuthSession session) async {
    try {
      await transport.signOut(session.token);
    } finally {
      await sessionStore.clear();
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthRepositoryException {
      rethrow;
    } on AuthApiException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthRepositoryException(
          kind: error.kind,
          message: error.message,
          statusCode: error.statusCode,
          code: error.code,
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthRepositoryException(
          kind: AuthFailureKind.invalidResponse,
          message: 'The store returned invalid authentication data.',
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthRepositoryException(
          kind: AuthFailureKind.unknown,
          message: 'Customer authentication failed unexpectedly.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
